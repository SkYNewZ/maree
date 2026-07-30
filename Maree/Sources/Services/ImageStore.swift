import Foundation
import SwiftUI
import UIKit

enum ImageKind: Hashable {
    case thumbnail(speciesId: Int)
    case photo(speciesId: Int, position: Int)

    private static let base = URL(string: "https://s3.us-east-005.backblazeb2.com/doris-production/images")!

    /// Paths are derived from the bundled database — the bucket's JSON index is
    /// never fetched, so browsing works with no network at all.
    var remoteURL: URL {
        switch self {
        case .thumbnail(let speciesId):
            Self.base.appending(path: "\(speciesId)/0_maree.heic")
        case .photo(let speciesId, let position):
            Self.base.appending(path: "\(speciesId)/\(position).jpg")
        }
    }

    var cacheFileName: String {
        switch self {
        case .thumbnail(let speciesId): "t-\(speciesId).heic"
        case .photo(let speciesId, let position): "p-\(speciesId)-\(position).jpg"
        }
    }
}

/// Persistent image cache. Files live in Application Support, never in Caches:
/// iOS may evict Caches under storage pressure, which is exactly the failure
/// mode this app exists to avoid.
@MainActor
final class ImageStore {
    /// The instance the environment hands out. `@Entry` defaults are computed, so
    /// without this stored `static let` every `@Environment(\.imageStore)` read
    /// would build a store with an empty memory cache and its own in-flight table.
    static let shared = ImageStore()

    let directory: URL

    /// A cache, not a dictionary: a 400 px thumbnail decodes to ~640 KB, so scrolling
    /// a thousand-species group with an unbounded map would hold hundreds of MB.
    /// NSCache also drops its contents on memory pressure — the files stay on disk.
    private let memory = NSCache<NSString, UIImage>()
    private var inFlight: [ImageKind: Task<UIImage?, Never>] = [:]

    /// Injectable so a test can answer a request without a network: what a captive
    /// portal sends back is exactly what the cache must refuse to keep.
    private let session: URLSession

    init(directory: URL? = nil, session: URLSession = .shared) {
        self.directory = directory ?? URL.applicationSupportDirectory.appending(path: "Images")
        self.session = session
        memory.countLimit = 200
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)

        // Up to a gigabyte of images that can always be fetched again has no place
        // in an iCloud backup. Set on every launch: the flag is per-file and a
        // directory created by an older build would never have carried it.
        var url = self.directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    func cachedFileExists(for kind: ImageKind) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: kind).path)
    }

    /// What the cache holds, in one listing. Bulk callers ask about thousands of
    /// files at once — 20 048 for the largest trip scope — and that many `stat`
    /// calls on the main actor is a visible freeze; one `readdir` is not.
    @concurrent
    nonisolated func cachedFileNames() async -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
    }

    /// Returns the image, loading from memory, then disk, then the network.
    /// Never throws: a missing image renders a placeholder instead of an error.
    ///
    /// Concurrent callers for the same kind share one task: reaching `inFlight[kind] = task`
    /// takes no `await`, so on the main actor no second caller can interleave before the
    /// entry is published.
    func image(for kind: ImageKind) async -> UIImage? {
        let key = kind.cacheFileName as NSString
        if let cached = memory.object(forKey: key) { return cached }
        if let existing = inFlight[kind] { return await existing.value }

        // Only the file I/O leaves the main actor; decoding stays on it, so `UIImage`
        // never crosses an isolation boundary.
        let task = Task<UIImage?, Never> { [directory, session] in
            let url = directory.appending(path: kind.cacheFileName)
            if let data = await Self.readFile(url), let image = UIImage(data: data) {
                return image
            }
            guard let data = try? await Self.fetch(kind, session: session) else { return nil }
            try? await Self.writeFile(data, to: url)
            return UIImage(data: data)
        }
        inFlight[kind] = task
        let image = await task.value
        inFlight[kind] = nil
        if let image { memory.setObject(image, forKey: key) }

        // The thumbnail pack guarantees one 400 px image per species offline; the
        // full-size 0.jpg is never prefetched. Without this the fiche header and the
        // gallery's first frame are placeholders on a fresh install with no network.
        if image == nil, case .photo(let speciesId, 0) = kind {
            return await self.image(for: .thumbnail(speciesId: speciesId))
        }
        return image
    }

    /// Downloads to disk without decoding — used by bulk prefetching, where
    /// holding thousands of decoded images in memory would be pointless.
    func download(_ kind: ImageKind) async throws {
        guard !cachedFileExists(for: kind) else { return }
        let data = try await Self.fetch(kind, session: session)
        try await Self.writeFile(data, to: fileURL(for: kind))
    }

    /// Enumerating a few thousand files takes long enough to drop frames, hence
    /// `@concurrent`: `nonisolated async` alone would run on the caller's actor.
    @concurrent
    nonisolated func cacheSizeInBytes() async -> Int64 {
        let keys: Set<URLResourceKey> = [.fileSizeKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: Array(keys)
        ) else { return 0 }
        return files.reduce(into: Int64(0)) { total, url in
            total += Int64((try? url.resourceValues(forKeys: keys).fileSize) ?? 0)
        }
    }

    private func fileURL(for kind: ImageKind) -> URL {
        directory.appending(path: kind.cacheFileName)
    }

    /// Disk access, off the main actor. Files are up to a few MB and `download(_:)`
    /// is called thousands of times in a row by the prefetch, so a main-thread write
    /// here would stall the UI for the whole run.
    @concurrent
    private nonisolated static func readFile(_ url: URL) async -> Data? {
        try? Data(contentsOf: url)
    }

    @concurrent
    private nonisolated static func writeFile(_ data: Data, to url: URL) async throws {
        try data.write(to: url, options: .atomic)
    }

    /// Only a decodable 200 body is ever returned, so nothing but an image can reach
    /// the cache. A captive portal answering 200 with its login page — hotel or
    /// campsite Wi-Fi, the night before a dive — would otherwise write 2 837 poison
    /// files that `cachedFileExists` reports as a complete cache forever.
    /// The check lives here rather than in the callers: both write paths go through
    /// it, and drifting apart is exactly how the hole appeared.
    ///
    /// A 404 is told apart from every other failure because it is permanent: bulk
    /// prefetching records it and stops asking, while a 5xx or a dead network must
    /// stay retryable.
    private static func fetch(_ kind: ImageKind, session: URLSession) async throws -> Data {
        let (data, response) = try await session.data(from: kind.remoteURL)
        guard let http = response as? HTTPURLResponse else { throw ImageError.notAvailable }
        guard http.statusCode == 200 else {
            throw http.statusCode == 404 ? ImageError.notFound : ImageError.notAvailable
        }
        guard UIImage(data: data) != nil else { throw ImageError.notAvailable }
        return data
    }
}

enum ImageError: LocalizedError {
    case notAvailable
    /// HTTP 404: the bucket holds no such object and never will. 16 species carry
    /// a photoCount with no image behind it.
    case notFound

    var errorDescription: String? { "Cette photo n'est pas disponible." }
}

extension EnvironmentValues {
    @Entry var imageStore = ImageStore.shared
}
