import Foundation
import Observation
import SwiftUI

enum DownloadState: Equatable {
    case idle
    case running(done: Int, total: Int)
    case finished(failed: Int)
    case cancelled

    var fraction: Double? {
        switch self {
        case .idle, .cancelled: nil
        case .running(let done, let total): total == 0 ? 1 : Double(done) / Double(total)
        case .finished: 1
        }
    }

    var isRunning: Bool { if case .running = self { true } else { false } }
}

/// One bulk download job: a bounded worker pool, a progress state, and the set of
/// objects the bucket has answered 404 for.
///
/// The thumbnail pack and trip preparation are the same machine with different
/// input, so the pool, cancellation and progress rules live here once.
@Observable
@MainActor
final class BulkDownload {
    private enum Outcome: Sendable { case ok, unavailable, failed }

    private let store: ImageStore

    /// Objects the bucket does not have: 15 species carry a `photoCount` with no
    /// image behind it, so their downloads 404 forever. Without this list every
    /// launch would re-request them and the pack could never read as complete.
    /// It lives next to the images because it describes them.
    /// ponytail: delete the file to retry, e.g. once the bucket is fixed.
    private let registry: URL
    private var unavailable: Set<String>

    private var task: Task<Void, Never>?

    /// Tells runs apart, so a cancelled predecessor winding down cannot overwrite
    /// the state of the run that replaced it.
    private var generation = 0

    private(set) var state: DownloadState = .idle

    init(store: ImageStore, registryName: String) {
        self.store = store
        registry = store.directory.appending(path: registryName)
        unavailable = Set((try? JSONDecoder().decode([String].self, from: Data(contentsOf: registry))) ?? [])
    }

    func isKnownUnavailable(_ kind: ImageKind) -> Bool {
        unavailable.contains(kind.cacheFileName)
    }

    /// Downloads `kinds`, at most `poolSize` at a time — an unbounded fan-out of a
    /// few thousand requests would starve the images the user is actually looking
    /// at. Progress is published every `progressEvery` files: publishing each one
    /// would invalidate the settings screen thousands of times.
    ///
    /// The guard and the first state change happen with no `await` in between, so
    /// on the main actor a second caller can never start a concurrent run.
    func run(_ kinds: [ImageKind], poolSize: Int, progressEvery: Int) async {
        guard !state.isRunning else { return }
        guard !kinds.isEmpty else { state = .finished(failed: 0); return }

        generation += 1
        let generation = self.generation
        state = .running(done: 0, total: kinds.count)

        // Unstructured on purpose: the pack is started from a view's `.task`, and
        // must survive that task being cancelled when the view goes away.
        let task = Task { [store] in
            var done = 0
            var failed = 0
            var missing: [String] = []
            await withTaskGroup(of: (ImageKind, Outcome).self) { group in
                var iterator = kinds.makeIterator()
                for _ in 0..<poolSize {
                    guard let kind = iterator.next() else { break }
                    group.addTask { await Self.attempt(kind, store: store) }
                }
                // Exactly one result per added task, and one added task per item:
                // nothing is downloaded twice and nothing is dropped.
                while let (kind, outcome) = await group.next() {
                    done += 1
                    switch outcome {
                    case .ok: break
                    case .unavailable: missing.append(kind.cacheFileName)
                    case .failed: failed += 1
                    }
                    if done % progressEvery == 0, self.generation == generation {
                        self.state = .running(done: done, total: kinds.count)
                    }
                    // Leaving the loop drains the children still in flight; they
                    // are cancelled with this task, so URLSession unwinds them.
                    if Task.isCancelled { break }
                    if let next = iterator.next() {
                        group.addTask { await Self.attempt(next, store: store) }
                    }
                }
            }
            // A 404 stays a fact even when the run was cancelled.
            self.record(missing)
            guard self.generation == generation else { return }
            self.state = Task.isCancelled ? .cancelled : .finished(failed: failed)
        }
        self.task = task
        await task.value
    }

    func cancel() {
        task?.cancel()
        if state.isRunning { state = .cancelled }
    }

    private func record(_ names: [String]) {
        guard !names.isEmpty else { return }
        unavailable.formUnion(names)
        try? JSONEncoder().encode(unavailable.sorted()).write(to: registry, options: .atomic)
    }

    private static func attempt(_ kind: ImageKind, store: ImageStore) async -> (ImageKind, Outcome) {
        do {
            try await store.download(kind)
            return (kind, .ok)
        } catch ImageError.notFound {
            return (kind, .unavailable)
        } catch {
            return (kind, .failed)
        }
    }
}

/// Downloads one thumbnail per species so every list works offline. Runs on first
/// launch and resumes on later ones: the cache directory *is* the progress state,
/// so an interrupted run simply picks up the files still missing.
@Observable
@MainActor
final class ThumbnailPack {
    /// The instance the environment hands out. `@Entry` defaults are computed, so
    /// without this stored `static let` every `@Environment(\.thumbnailPack)` read
    /// would build a pack with its own progress state and start the run again.
    static let shared = ThumbnailPack(repository: SpeciesRepository(reader: AppDatabase.shared.reader))

    private let store: ImageStore
    private let repository: SpeciesRepository
    private let downloads: BulkDownload

    var state: DownloadState { downloads.state }

    init(store: ImageStore = .shared, repository: SpeciesRepository) {
        self.store = store
        self.repository = repository
        downloads = BulkDownload(store: store, registryName: "unavailable-thumbnails.json")
    }

    func missingCount() -> Int { missing().count }

    func startIfNeeded() async {
        await downloads.run(missing(), poolSize: 6, progressEvery: 25)
    }

    func cancel() { downloads.cancel() }

    private func missing() -> [ImageKind] {
        let ids = (try? repository.allSpeciesIds()) ?? []
        return ids
            .map { ImageKind.thumbnail(speciesId: $0) }
            .filter { !downloads.isKnownUnavailable($0) && !store.cachedFileExists(for: $0) }
    }
}

extension EnvironmentValues {
    @Entry var thumbnailPack = ThumbnailPack.shared
}
