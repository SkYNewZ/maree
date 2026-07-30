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
        // A zero total must not divide by zero.
        #expect(DownloadState.running(done: 0, total: 0).fraction == 1)
        #expect(DownloadState.finished(failed: 0).fraction == 1)
    }

    @Test("le pack ne recompte pas les vignettes déjà en cache")
    func packSkipsCachedFiles() throws {
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
        #expect(pack.missingCount() == 2837 - seeded.count)
        try? FileManager.default.removeItem(at: directory)
    }

    /// 15 species carry a photoCount the bucket has no object for: their thumbnails
    /// 404 forever. Once recorded, they must stop being counted as missing —
    /// otherwise every launch re-requests them and the pack never reads as complete.
    @Test("une vignette absente du bucket n'est plus recomptée aux lancements suivants")
    func packSkipsKnownUnavailable() throws {
        let directory = makeDirectory()
        let store = ImageStore(directory: directory)
        // Same file, same format the pack writes after a 404.
        try JSONEncoder().encode(["t-1911.heic", "t-3022.heic"])
            .write(to: directory.appending(path: "unavailable-thumbnails.json"))

        let pack = ThumbnailPack(store: store, repository: try makeRepository())
        #expect(pack.missingCount() == 2837 - 2)
        try? FileManager.default.removeItem(at: directory)
    }

    @Test("l'estimation d'une sortie compte les photos et un poids plausible")
    func tripEstimate() throws {
        let repository = try makeRepository()
        let favorites = Favorites(defaults: makeDefaults())
        for id in try repository.search("oursin", limit: 3).map(\.id) { favorites.toggle(id) }

        let trip = TripPreparation(store: ImageStore(directory: makeDirectory()),
                                   repository: repository,
                                   favorites: favorites)
        let estimate = try trip.estimate(for: .favorites)
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
    /// inside the case, adding a favourite while the screen is open would silently
    /// clear the selection.
    @Test("le périmètre « favoris » ne dépend pas du contenu des favoris")
    func favoritesScopeIsStable() {
        #expect(TripScope.favorites == TripScope.favorites)
    }

    /// `@Entry` environment defaults are computed, so a fresh `ThumbnailPack()`
    /// there would give every reader its own progress state and restart the pack.
    @Test("l'environnement expose l'unique instance partagée")
    func environmentExposesSharedPack() {
        #expect(EnvironmentValues().thumbnailPack === ThumbnailPack.shared)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
