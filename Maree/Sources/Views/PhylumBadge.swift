import SwiftUI

/// The one place an icon is drawn. Decorative on purpose: on the fiche header it
/// doubles the group name already spelled out in the `Badge` beside it, so
/// VoiceOver must not read it twice. In `SpeciesRow` there is no such duplicate —
/// `Theme` stores no phylum name — but there is nothing to announce either: the
/// badge carries colour-coding only, no information a label could put into words.
struct PhylumBadge: View {
    let phylumId: Int
    var size: CGFloat = 28

    var body: some View {
        let phylum = Theme.phylum(phylumId)
        Circle()
            .fill(phylum.tint)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: phylum.symbol)
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(phylum.base)
            }
            .accessibilityHidden(true)
    }
}
