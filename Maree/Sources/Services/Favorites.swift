import Foundation
import Observation
import SwiftUI

/// Favourite species ids, most recently added first. A plain array in
/// UserDefaults: a few hundred integers never need a database.
@Observable
@MainActor
final class Favorites {
    /// The instance the environment hands out. `@Entry` defaults are computed, so
    /// without this stored `static let` every `@Environment(\.favorites)` read
    /// would build a store that re-reads UserDefaults and forgets every toggle
    /// made through a different instance.
    static let shared = Favorites()

    private static let key = "maree.favorites"
    private let defaults: UserDefaults

    private(set) var ids: [Int]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        ids = defaults.array(forKey: Self.key) as? [Int] ?? []
    }

    func contains(_ id: Int) -> Bool { ids.contains(id) }

    func toggle(_ id: Int) {
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
        } else {
            ids.insert(id, at: 0)
        }
        defaults.set(ids, forKey: Self.key)
    }
}

struct FavoriteButton: View {
    let speciesId: Int

    @Environment(\.favorites) private var favorites

    var body: some View {
        Button {
            favorites.toggle(speciesId)
        } label: {
            Image(systemName: favorites.contains(speciesId) ? "heart.fill" : "heart")
        }
        .tint(.pink)
        .accessibilityLabel(favorites.contains(speciesId) ? "Retirer des favoris" : "Ajouter aux favoris")
    }
}

extension EnvironmentValues {
    @Entry var favorites = Favorites.shared
}
