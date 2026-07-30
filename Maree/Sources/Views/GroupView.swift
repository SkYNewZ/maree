import SwiftUI

/// A group either drills down into sub-groups or lists its species.
struct GroupView: View {
    let group: TaxonGroup

    @Environment(\.repository) private var repository
    @State private var children: [TaxonGroup] = []
    @State private var species: [Species] = []
    @State private var loaded = false

    var body: some View {
        Group {
            if !loaded {
                ProgressView()
            } else if children.isEmpty {
                SpeciesListView(
                    title: group.name,
                    species: species,
                    emptyMessage: "Ce groupe ne contient aucune espèce européenne."
                )
            } else {
                List {
                    ForEach(children) { child in
                        NavigationLink(value: Route.group(child)) {
                            GroupLabel(group: child)
                        }
                    }
                    // `Section` is shadowed by our database record type of the
                    // same name, so SwiftUI's own Section must be qualified here.
                    SwiftUI.Section {
                        NavigationLink(value: Route.groupSpecies(group)) {
                            Label("Voir les \(group.speciesCount) espèces", systemImage: "list.bullet")
                        }
                    }
                }
            }
        }
        // Set once at the top level (rather than per-branch) so the
        // navigation title is already correct during the loading state,
        // instead of flashing in once children/species resolve.
        .navigationTitle(group.name)
        .task {
            children = (try? repository.childGroups(of: group.id)) ?? []
            if children.isEmpty {
                species = (try? repository.species(inGroup: group.id)) ?? []
            }
            loaded = true
        }
    }
}

struct GroupSpeciesView: View {
    let group: TaxonGroup

    @Environment(\.repository) private var repository
    @State private var species: [Species] = []

    var body: some View {
        SpeciesListView(
            title: group.name,
            species: species,
            emptyMessage: "Ce groupe ne contient aucune espèce européenne."
        )
        .task { species = (try? repository.species(inGroup: group.id)) ?? [] }
    }
}
