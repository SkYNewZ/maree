import SwiftUI

/// A group either drills down into sub-groups or lists its species.
struct GroupView: View {
    let group: TaxonGroup

    @Environment(\.repository) private var repository
    @Environment(\.tripPreparation) private var trip
    @State private var children: [TaxonGroup] = []
    @State private var loaded = false
    @State private var estimate: (photos: Int, bytes: Int64)?
    @State private var confirming = false

    var body: some View {
        Group {
            if !loaded {
                ProgressView()
            } else if children.isEmpty {
                // A leaf *is* the species list, and that screen already exists.
                GroupSpeciesView(group: group)
            } else {
                List {
                    ForEach(children) { child in
                        NavigationLink(value: Route.group(child)) {
                            GroupLabel(group: child)
                        }
                        .listRowBackground(Theme.surface)
                    }
                    // `Section` is shadowed by our database record type of the
                    // same name, so SwiftUI's own Section must be qualified here.
                    SwiftUI.Section {
                        NavigationLink(value: Route.groupSpecies(group)) {
                            Label("Voir les \(group.speciesCount) espèces", systemImage: "list.bullet")
                        }
                        .listRowBackground(Theme.surface)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Theme.paper)
            }
        }
        // Set once at the top level (rather than per-branch) so the
        // navigation title is already correct during the loading state,
        // instead of flashing in once children/species resolve.
        .navigationTitle(group.name)
        // Where the scope of a dive is actually decided: nobody prepares a sortie
        // for « ANIMAUX », they prepare it for the group they are looking at. The
        // run itself is followed and cancelled in Réglages, which shares the instance.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if trip.state.isRunning {
                    ProgressView()
                } else {
                    Button("Préparer", systemImage: "arrow.down.circle") {
                        Task {
                            estimate = try? await trip.estimate(for: .group(group))
                            confirming = estimate != nil
                        }
                    }
                }
            }
        }
        .alert("Préparer « \(group.name) » hors ligne", isPresented: $confirming, presenting: estimate) { estimate in
            // No action at all when there is nothing to fetch: SwiftUI then shows
            // its own dismiss button, which is the whole of what is left to do.
            if estimate.photos > 0 {
                Button("Télécharger") { Task { await trip.start(.group(group)) } }
                Button("Annuler", role: .cancel) {}
            }
        } message: { estimate in
            Text(estimate.photos == 0
                 ? "Toutes les photos de ce groupe sont déjà en cache."
                 : TripPreparation.summary(of: estimate))
        }
        .task {
            children = (try? repository.childGroups(of: group.id)) ?? []
            loaded = true
        }
    }
}

/// Every species of a group, its sub-groups included. Reached both as a leaf of
/// the tree and from « Voir les N espèces » on a branch.
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
