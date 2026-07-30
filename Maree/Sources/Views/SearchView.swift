import SwiftUI

struct SearchView: View {
    @Environment(\.repository) private var repository
    @State private var query = ""
    @State private var results: [Species] = []

    var body: some View {
        NavigationStack {
            Group {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    startScreen
                } else {
                    SpeciesListView(
                        title: "Rechercher",
                        species: results,
                        emptyMessage: "Aucune espèce ne correspond à « \(query) »."
                    )
                }
            }
            .navigationTitle("Rechercher")
            .searchable(text: $query, prompt: "Nom commun ou scientifique")
            .mareeDestinations()
        }
        .background(Theme.paper)
        .task(id: query) {
            results = (try? repository.search(query)) ?? []
        }
    }

    private var startScreen: some View {
        ContentUnavailableView {
            Label("Chercher une espèce", systemImage: "magnifyingglass")
        } description: {
            Text("Tapez un nom commun ou scientifique. La recherche fonctionne hors ligne, accents facultatifs.")
        }
        .foregroundStyle(Theme.inkSoft)
        .background(Theme.paper)
    }
}
