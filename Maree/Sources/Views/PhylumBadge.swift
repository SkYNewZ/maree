import SwiftUI

/// The one place an icon is drawn. Decorative on purpose: it doubles information
/// already written out in words, so VoiceOver must not read it twice.
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
