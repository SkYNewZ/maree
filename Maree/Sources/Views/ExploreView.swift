import SwiftUI

struct ExploreView: View {
    @Environment(\.repository) private var repository
    @State private var groups: [TaxonGroup] = []
    @State private var zones: [Zone] = []

    var body: some View {
        NavigationStack {
            List {
                // `Section` is shadowed by our database record type of the same
                // name, so SwiftUI's own Section must be qualified here.
                SwiftUI.Section("Par groupe") {
                    ForEach(groups) { group in
                        NavigationLink(value: Route.group(group)) {
                            GroupLabel(group: group)
                        }
                        .listRowBackground(Theme.surface)
                    }
                }
                SwiftUI.Section("Par zone") {
                    ForEach(zones) { zone in
                        NavigationLink(value: Route.zone(zone)) {
                            Text(zone.name)
                        }
                        .listRowBackground(Theme.surface)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("Explorer")
            .mareeDestinations()
        }
        .task {
            groups = (try? repository.rootGroups()) ?? []
            zones = (try? repository.zones()) ?? []
        }
    }
}

struct GroupLabel: View {
    let group: TaxonGroup

    var body: some View {
        HStack(spacing: 12) {
            // A root (Explore's own list) is a kingdom, not a phylum — it has
            // none, so it draws no badge, rather than the neutral grey pastille
            // every root but AUTRES used to share. The two contexts never share
            // a screen (Explore lists roots only, GroupView lists non-root
            // children only), so there is no in-list jump to guard against: text
            // simply starts flush left on the root screen.
            if group.parentId != nil {
                PhylumBadge(phylumId: group.phylumId)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name).foregroundStyle(Theme.ink)
                HStack(spacing: 6) {
                    if let hint = group.scientificHint {
                        Text(hint).italic()
                    }
                    Text("\(group.speciesCount) espèces")
                }
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
            }
        }
    }
}
