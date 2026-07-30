import SwiftUI

/// The one species list, reused by search, browsing and favourites.
struct SpeciesListView: View {
    let title: String
    let species: [Species]
    let emptyMessage: String

    var body: some View {
        Group {
            if species.isEmpty {
                ContentUnavailableView("Aucune espèce", systemImage: "magnifyingglass", description: Text(emptyMessage))
                    .background(Theme.paper)
            } else {
                List(species) { item in
                    NavigationLink(value: Route.species(item.id)) {
                        SpeciesRow(species: item)
                    }
                    .listRowBackground(Theme.surface)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Theme.paper)
            }
        }
        .navigationTitle(title)
    }
}
