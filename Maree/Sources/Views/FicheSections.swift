import SwiftUI

/// Renders the species sections in SectionKind.allCases order, plus the derived
/// blocks that are not plain text: depth/temperature, zones, classification.
struct FicheSections: View {
    let detail: SpeciesDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(detail.sections, id: \.kind) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.kind.title).font(.headline)
                    Text(section.text).font(.body)
                    // Both derived blocks are guarded: depth and temperature are
                    // regex-extracted and absent for over half the species, and an
                    // empty HStack would still take the stack's spacing.
                    if section.kind == .biotope, hasMeasurements { measurements }
                    if section.kind == .distribution, !detail.zones.isEmpty { zoneChips }
                }
            }

            if !detail.frenchNames.isEmpty || !detail.otherNames.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Autres noms").font(.headline)
                    if !detail.frenchNames.isEmpty {
                        Text(detail.frenchNames.joined(separator: " · "))
                    }
                    if !detail.otherNames.isEmpty {
                        Text(detail.otherNames.joined(separator: " · ")).foregroundStyle(.secondary)
                    }
                }
            }

            if !detail.ranks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Classification").font(.headline)
                    ForEach(detail.ranks, id: \.position) { rank in
                        HStack(alignment: .firstTextBaseline) {
                            Text(rank.rank).font(.caption).foregroundStyle(.secondary)
                                .frame(width: 110, alignment: .leading)
                            Text(rank.name)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var hasMeasurements: Bool {
        detail.species.depthRange != nil || detail.species.temperatureRange != nil
    }

    private var measurements: some View {
        HStack(spacing: 12) {
            if let depth = detail.species.depthRange {
                Measurement(icon: "arrow.down.to.line", label: "Profondeur", value: "\(depth.lowerBound)–\(depth.upperBound) m")
            }
            if let temp = detail.species.temperatureRange {
                Measurement(icon: "thermometer.medium", label: "Température", value: "\(temp.lowerBound)–\(temp.upperBound) °C")
            }
        }
    }

    private var zoneChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(detail.zones) { zone in
                    Badge(text: zone.name, tint: .blue)
                }
            }
        }
    }
}

private struct Measurement: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(label, systemImage: icon).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.body.weight(.medium))
        }
        .padding(10)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 10))
    }
}
