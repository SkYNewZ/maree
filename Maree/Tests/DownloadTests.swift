import Testing
import Foundation
import SwiftUI
@testable import Maree

@Suite("Téléchargements groupés")
@MainActor
struct DownloadTests {
    private func makeDirectory() -> URL {
        URL.temporaryDirectory.appending(path: UUID().uuidString)
    }

    private func makeRepository() throws -> SpeciesRepository {
        SpeciesRepository(reader: try AppDatabase().reader)
    }

    @Test("la fraction de progression est correcte et bornée")
    func progressFraction() {
        #expect(DownloadState.idle.fraction == nil)
        #expect(DownloadState.running(done: 0, total: 100).fraction == 0)
        #expect(DownloadState.running(done: 50, total: 100).fraction == 0.5)
        #expect(DownloadState.running(done: 100, total: 100).fraction == 1)
        // Read only while `isRunning`, so every other state has no fraction at all.
        #expect(DownloadState.finished(failed: 0).fraction == nil)
        #expect(DownloadState.cancelled.fraction == nil)
    }

    @Test("le pack ne recompte pas les vignettes déjà en cache")
    func packSkipsCachedFiles() async throws {
        let directory = makeDirectory()
        let store = ImageStore(directory: directory)
        let repository = try makeRepository()

        // Pre-seed two thumbnails as if a previous run had downloaded them.
        let seeded = try repository.search("oursin", limit: 2).map(\.id)
        try #require(seeded.count == 2)
        for id in seeded {
            try Data("x".utf8).write(to: directory.appending(path: ImageKind.thumbnail(speciesId: id).cacheFileName))
        }

        let pack = ThumbnailPack(store: store, repository: repository)
        #expect(await pack.missingCount() == 2837 - seeded.count)
        try? FileManager.default.removeItem(at: directory)
    }

    /// 16 species carry a photoCount the bucket has no object for: their thumbnails
    /// 404 forever. Once recorded, they must stop being counted as missing —
    /// otherwise every launch re-requests them and the pack never reads as complete.
    ///
    /// Written through `record`, not hand-serialised: what the run writes and what
    /// the next launch reads have to be the same shape, and asserting the JSON here
    /// would only restate this test's own assumption about it.
    @Test("une vignette absente du bucket n'est plus recomptée aux lancements suivants")
    func packSkipsKnownUnavailable() async throws {
        let directory = makeDirectory()
        let store = ImageStore(directory: directory)
        let names = [1911, 3022].map { ImageKind.thumbnail(speciesId: $0).cacheFileName }
        BulkDownload(store: store, registryName: "unavailable-thumbnails.json")
            .record(names, of: 2837)

        // A separate instance, reading only what the previous one left on disk.
        let pack = ThumbnailPack(store: store, repository: try makeRepository())
        #expect(await pack.missingCount() == 2837 - 2)
        try? FileManager.default.removeItem(at: directory)
    }

    /// A run where *every* object 404s means the bucket moved or the path is wrong,
    /// not that 2 837 images vanished. Recording it would make the next launch skip
    /// the whole pack without a request and report the cache as complete when it is
    /// empty — the app's core promise, silently broken, with no way back.
    @Test("un run intégralement en échec n'est pas enregistré : c'est l'origine qui est cassée")
    func brokenOriginIsNotRecorded() {
        let directory = makeDirectory()
        let downloads = BulkDownload(store: ImageStore(directory: directory),
                                     registryName: "unavailable-thumbnails.json")
        let all = [1, 2, 3].map { ImageKind.thumbnail(speciesId: $0) }

        downloads.record(all.map(\.cacheFileName), of: all.count)
        #expect(all.allSatisfy { !downloads.isKnownUnavailable($0) })
        #expect(!FileManager.default.fileExists(
            atPath: directory.appending(path: "unavailable-thumbnails.json").path))

        // One success in the same run is enough to trust the rest as genuine 404s.
        downloads.record(all.map(\.cacheFileName), of: all.count + 1)
        #expect(all.allSatisfy { downloads.isKnownUnavailable($0) })
        try? FileManager.default.removeItem(at: directory)
    }

    @Test("l'estimation d'une sortie compte les photos et un poids plausible")
    func tripEstimate() async throws {
        let repository = try makeRepository()
        let favorites = Favorites(defaults: makeDefaults())
        for id in try repository.search("oursin", limit: 3).map(\.id) { favorites.toggle(id) }

        let trip = TripPreparation(store: ImageStore(directory: makeDirectory()),
                                   repository: repository,
                                   favorites: favorites)
        let estimate = try await trip.estimate(for: .favorites)
        #expect(estimate.photos > 0)
        #expect(estimate.bytes > Int64(estimate.photos) * 10_000)
    }

    /// Stays offline: with no favourite there is nothing to fetch, so this proves
    /// the empty run still reaches a terminal state instead of hanging on `idle`.
    @Test("une sortie sans photo à télécharger se termine immédiatement")
    func emptyTripFinishes() async throws {
        let trip = TripPreparation(store: ImageStore(directory: makeDirectory()),
                                   repository: try makeRepository(),
                                   favorites: Favorites(defaults: makeDefaults()))
        await trip.start(.favorites)
        #expect(trip.state == .finished(failed: 0))
    }

    /// A picker selection must keep matching its own tag: with the favourite ids
    /// inside the case, adding a favourite while the screen is open would change the
    /// tag and silently clear the selection. So the scope value must stay equal to
    /// itself across a change the estimate does follow.
    @Test("le périmètre « favoris » ne dépend pas du contenu des favoris")
    func favoritesScopeIsStable() async throws {
        let repository = try makeRepository()
        let favorites = Favorites(defaults: makeDefaults())
        let trip = TripPreparation(store: ImageStore(directory: makeDirectory()),
                                   repository: repository,
                                   favorites: favorites)
        let scope = TripScope.favorites
        #expect(try await trip.estimate(for: scope).photos == 0)

        for id in try repository.search("oursin", limit: 2).map(\.id) { favorites.toggle(id) }

        #expect(try await trip.estimate(for: scope).photos > 0)
        #expect(scope == .favorites)
    }

    /// The five roots are 1 Go and a whole kingdom; nobody prepares a dive for
    /// « ANIMAUX ». Preparing the group being browsed is the point, so a sub-group
    /// must be a strictly smaller scope than the root it hangs from.
    @Test("un sous-groupe est un périmètre plus petit que sa racine")
    func subGroupIsASmallerScope() async throws {
        let repository = try makeRepository()
        let trip = TripPreparation(store: ImageStore(directory: makeDirectory()),
                                   repository: repository,
                                   favorites: Favorites(defaults: makeDefaults()))
        let root = try #require(try repository.rootGroups().max { $0.speciesCount < $1.speciesCount })
        let child = try #require(try repository.childGroups(of: root.id).first)

        let whole = try await trip.estimate(for: .group(root)).photos
        let part = try await trip.estimate(for: .group(child)).photos
        #expect(part > 0)
        #expect(part < whole)
    }

    /// `@Entry` environment defaults are computed, so a fresh `ThumbnailPack()`
    /// there would give every reader its own progress state and restart the pack.
    @Test("l'environnement expose l'unique instance partagée")
    func environmentExposesSharedPack() {
        #expect(EnvironmentValues().thumbnailPack === ThumbnailPack.shared)
        // A trip started while browsing and the progress shown in Réglages must be
        // the same run — and one writer on the unavailable-photos registry.
        #expect(EnvironmentValues().tripPreparation === TripPreparation.shared)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
