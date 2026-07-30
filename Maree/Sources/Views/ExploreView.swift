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
                    }
                }
                SwiftUI.Section("Par zone") {
                    ForEach(zones) { zone in
                        NavigationLink(value: Route.zone(zone)) {
                            Text(zone.name)
                        }
                    }
                }
            }
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
        VStack(alignment: .leading, spacing: 2) {
            Text(group.name)
            HStack(spacing: 6) {
                if let hint = group.scientificHint {
                    Text(hint).italic()
                }
                Text("\(group.speciesCount) espèces")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
