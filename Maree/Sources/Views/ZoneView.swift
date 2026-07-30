import SwiftUI

struct ZoneView: View {
    let zone: Zone

    @Environment(\.repository) private var repository
    @State private var species: [Species] = []

    var body: some View {
        SpeciesListView(
            title: zone.name,
            species: species,
            emptyMessage: "Aucune espèce enregistrée pour cette zone."
        )
        .task { species = (try? repository.species(inZone: zone.id)) ?? [] }
    }
}
