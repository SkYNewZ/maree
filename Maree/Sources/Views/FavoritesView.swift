import SwiftUI

struct FavoritesView: View {
    @Environment(\.repository) private var repository
    @Environment(\.favorites) private var favorites
    @State private var species: [Species] = []

    var body: some View {
        NavigationStack {
            SpeciesListView(
                title: "Favoris",
                species: species,
                emptyMessage: "Touchez le cœur sur une fiche pour la retrouver ici, et préparez vos photos avant de partir."
            )
            .mareeDestinations()
        }
        .background(Theme.paper)
        .task(id: favorites.ids) {
            species = (try? repository.species(ids: favorites.ids)) ?? []
        }
    }
}
