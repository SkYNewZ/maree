import SwiftUI

struct SpeciesRow: View {
    let species: Species

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(.thumbnail(speciesId: species.id))
                .frame(width: 72, height: 72)
                .clipShape(.rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(species.displayName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Text(species.scientificName)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .italic()
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if species.dangerous {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.signal)
                    .accessibilityLabel("Espèce dangereuse")
            }
            PhylumBadge(phylumId: species.phylumId)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
