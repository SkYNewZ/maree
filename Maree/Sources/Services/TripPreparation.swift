import Foundation
import Observation
import SwiftUI

enum TripScope: Hashable {
    /// Carries no ids: they are read when the estimate or the download runs. With
    /// the ids inside the case, favouriting a species while the settings screen is
    /// open would change the picker's tag and silently clear its own selection.
    case favorites
    case group(TaxonGroup)
    case zone(Zone)
}

/// Prefetches every full-size photo of a chosen scope, so a dive site with no
/// signal still shows the photos that matter.
@Observable
@MainActor
final class TripPreparation {
    /// The instance the environment hands out. `@Entry` defaults are computed, so
    /// without this stored `static let` a trip started while browsing and the
    /// progress shown in Réglages would be two different runs — both writing the
    /// same unavailable-photos registry.
    static let shared = TripPreparation()

    /// Measured average of a full-size photo in the bucket (51 KB over 39 samples).
    /// Only ever shown as an estimate — photo weights range over an order of magnitude.
    private static let averagePhotoBytes: Int64 = 52_000

    private let store: ImageStore
    private let repository: SpeciesRepository
    private let favorites: Favorites
    private let downloads: BulkDownload

    var state: DownloadState { downloads.state }

    init(store: ImageStore = .shared,
         repository: SpeciesRepository = SpeciesRepository(reader: AppDatabase.shared.reader),
         favorites: Favorites = .shared) {
        self.store = store
        self.repository = repository
        self.favorites = favorites
        downloads = BulkDownload(store: store, registryName: "unavailable-photos.json")
    }

    func estimate(for scope: TripScope) async throws -> (photos: Int, bytes: Int64) {
        let missing = try await missingPhotos(in: scope)
        return (missing.count, Int64(missing.count) * Self.averagePhotoBytes)
    }

    func start(_ scope: TripScope) async {
        await downloads.run((try? await missingPhotos(in: scope)) ?? [], poolSize: 4, progressEvery: 10)
    }

    func cancel() { downloads.cancel() }

    /// Runs every time the picker moves, and the widest scope is a recursive query
    /// over 20 048 photos — so both the query and the cache listing stay off the main
    /// actor, and one listing replaces one `fileExists` per photo.
    private func missingPhotos(in scope: TripScope) async throws -> [ImageKind] {
        let species = try await species(in: scope, favoriteIds: favorites.ids)
        let cached = await store.cachedFileNames()
        return species
            .flatMap { species in
                (0..<species.photoCount).map { ImageKind.photo(speciesId: species.id, position: $0) }
            }
            .filter { !downloads.isKnownUnavailable($0) && !cached.contains($0.cacheFileName) }
    }

    /// Favourite ids are read on the main actor and passed in: `Favorites` lives there.
    @concurrent
    private nonisolated func species(in scope: TripScope, favoriteIds: [Int]) async throws -> [Species] {
        switch scope {
        case .favorites: try repository.species(ids: favoriteIds)
        case .group(let group): try repository.species(inGroup: group.id)
        case .zone(let zone): try repository.species(inZone: zone.id)
        }
    }
}

extension EnvironmentValues {
    @Entry var tripPreparation = TripPreparation.shared
}
