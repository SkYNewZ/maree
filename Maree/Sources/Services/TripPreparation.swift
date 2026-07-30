import Foundation
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
///
/// Not `@Observable`: every stored property is a `let`, and views follow the run
/// through `BulkDownload.state`, which is.
@MainActor
final class TripPreparation {
    /// The instance the environment hands out. `@Entry` defaults are computed, so
    /// without this stored `static let` a trip started while browsing and the
    /// progress shown in Réglages would be two different runs.
    static let shared = TripPreparation()

    /// Measured average of a full-size photo in the bucket (51 KB over 39 samples).
    /// Only ever shown as an estimate — photo weights range over an order of magnitude.
    private static let averagePhotoBytes: Int64 = 52_000

    private let repository: SpeciesRepository
    private let favorites: Favorites
    private let downloads: BulkDownload

    var state: DownloadState { downloads.state }

    init(store: ImageStore = .shared,
         repository: SpeciesRepository = SpeciesRepository(reader: AppDatabase.shared.reader),
         favorites: Favorites = .shared) {
        self.repository = repository
        self.favorites = favorites
        downloads = BulkDownload(store: store)
    }

    func estimate(for scope: TripScope) async throws -> (photos: Int, bytes: Int64) {
        let missing = try await missingPhotos(in: scope)
        return (missing.count, Int64(missing.count) * Self.averagePhotoBytes)
    }

    /// « 128 photos · environ 6,5 Mo », the same sentence in Réglages and in a group's
    /// confirmation alert.
    static func summary(of estimate: (photos: Int, bytes: Int64)) -> String {
        "\(estimate.photos) photos · environ \(estimate.bytes.formattedBytes)"
    }

    func start(_ scope: TripScope) async {
        await downloads.run((try? await missingPhotos(in: scope)) ?? [], poolSize: 4, progressEvery: 10)
    }

    func cancel() { downloads.cancel() }

    /// Runs every time the picker moves, and the widest scope is a recursive query
    /// over 20 048 photos — so the query stays off the main actor. Favourite ids are
    /// read here, on the main actor, because `Favorites` lives there.
    private func missingPhotos(in scope: TripScope) async throws -> [ImageKind] {
        let favoriteIds = favorites.ids
        return try await downloads.missing {
            try await self.species(in: scope, favoriteIds: favoriteIds).flatMap { species in
                (0..<species.photoCount).map { ImageKind.photo(speciesId: species.id, position: $0) }
            }
        }
    }

    @concurrent
    private nonisolated func species(in scope: TripScope, favoriteIds: [Int]) async throws -> [Species] {
        switch scope {
        case .favorites: try repository.species(ids: favoriteIds)
        case .group(let group): try repository.species(inGroup: group.id)
        case .zone(let zone): try repository.species(inZone: zone.id)
        }
    }
}

/// The two byte counts the app shows — the cache size and a trip estimate.
extension Int64 {
    var formattedBytes: String { ByteCountFormatStyle(style: .file).format(self) }
}

extension EnvironmentValues {
    @Entry var tripPreparation = TripPreparation.shared
}
