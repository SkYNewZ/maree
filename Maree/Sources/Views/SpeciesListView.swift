import SwiftUI

/// The one species list, reused by search, browsing and favourites.
struct SpeciesListView: View {
    let title: String
    let species: [Species]
    let emptyMessage: String

    var body: some View {
        Group {
            if species.isEmpty {
                // Same GeometryReader + minHeight fix as SearchView.startScreen:
                // centers at ordinary sizes, scrolls instead of hiding text
                // behind the tab bar at AX3 (Task 7).
                GeometryReader { proxy in
                    ScrollView {
                        ContentUnavailableView("Aucune espèce", systemImage: "magnifyingglass", description: Text(emptyMessage))
                            .frame(minHeight: proxy.size.height)
                    }
                }
                .foregroundStyle(Theme.inkSoft)
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
