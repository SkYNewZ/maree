import SwiftUI

struct SpeciesRow: View {
    let species: Species

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(.thumbnail(speciesId: species.id))
                .frame(width: 64, height: 64)
                .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(species.commonName)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Text(species.scientificName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if species.dangerous {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Espèce dangereuse")
            }
        }
        .accessibilityElement(children: .combine)
    }
}
