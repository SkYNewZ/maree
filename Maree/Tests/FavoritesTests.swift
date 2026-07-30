import Testing
import Foundation
import SwiftUI
@testable import Maree

@Suite("Favoris")
@MainActor
struct FavoritesTests {
    @Test("un favori ajouté est retenu, un second appel le retire")
    func toggling() {
        let favorites = Favorites(defaults: makeDefaults())
        #expect(favorites.contains(1437) == false)
        favorites.toggle(1437)
        #expect(favorites.contains(1437))
        favorites.toggle(1437)
        #expect(favorites.contains(1437) == false)
    }

    @Test("les favoris sont ordonnés du plus récent au plus ancien")
    func orderIsMostRecentFirst() {
        let favorites = Favorites(defaults: makeDefaults())
        favorites.toggle(1)
        favorites.toggle(2)
        favorites.toggle(3)
        #expect(favorites.ids == [3, 2, 1])
    }

    @Test("les favoris survivent à une nouvelle instance")
    func persistence() {
        let defaults = makeDefaults()
        let first = Favorites(defaults: defaults)
        first.toggle(881)
        let second = Favorites(defaults: defaults)
        #expect(second.contains(881))
    }

    @Test("ajouter deux fois le même identifiant ne le duplique pas")
    func noDuplicates() {
        let favorites = Favorites(defaults: makeDefaults())
        favorites.toggle(5)
        favorites.toggle(5)
        favorites.toggle(5)
        #expect(favorites.ids == [5])
    }

    /// `@Entry` environment defaults are computed, so a fresh `Favorites()` there
    /// would read UserDefaults into its own instance, orphaned from every toggle
    /// made through `Favorites.shared` (e.g. from `FavoriteButton`).
    @Test("l'environnement expose l'unique instance partagée")
    func environmentExposesSharedInstance() {
        #expect(EnvironmentValues().favorites === Favorites.shared)
    }
}
