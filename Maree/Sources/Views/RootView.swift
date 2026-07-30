import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Rechercher", systemImage: "magnifyingglass") { SearchView() }
            Tab("Explorer", systemImage: "square.grid.2x2") { ExploreView() }
            Tab("Favoris", systemImage: "heart") { FavoritesView() }
            Tab("Réglages", systemImage: "gearshape") { SettingsView() }
        }
    }
}

/// Shared destination wiring, applied inside each tab's NavigationStack.
extension View {
    func mareeDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .species(let id):
                FicheView(speciesId: id)
            case .group(let group):
                GroupView(group: group)
            case .groupSpecies(let group):
                GroupSpeciesView(group: group)
            case .zone(let zone):
                ZoneView(zone: zone)
            case .gallery(let speciesId, let position):
                GalleryView(speciesId: speciesId, initialPosition: position)
            }
        }
    }
}
