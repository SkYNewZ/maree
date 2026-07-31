import SwiftUI

/// One small chip, one rule for all of them: `Theme.ink` text over a caller-chosen
/// background — see Task 5 owner ruling #1, the phylum/signal colours themselves
/// fail AA as text in light mode, so only the background carries them. Shared by
/// `FicheView` (group/status badges, gallery heading) and `FicheSections` (zone
/// chips, every other section heading). Backgrounds always come from
/// `Phylum.chipBackground` or `Theme.signalChip` — never a literal opacity at
/// the call site.
///
/// `ThemeTests.badgeTextIsLegible` asserts the contrast ratio of those two
/// formulas against `Theme.ink` — the same formulas this view draws with, not a
/// parallel copy of them. It cannot see what `Badge` actually renders on screen
/// (that would need `ImageRenderer` pixel-sampling, deliberately out of scope);
/// it guards the formula the background is built from, not the rendered pixels.
struct Badge: View {
    let text: String
    let background: Color
    var icon: String?

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
            }
            Text(text)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(background, in: .capsule)
        .foregroundStyle(Theme.ink)
    }
}

/// The small caption heading used above every fiche section, including the
/// gallery — which used to draw its own `.headline` instead of matching the
/// rest of the screen (Task 7 fix round).
func sectionTitle(_ title: String) -> some View {
    Text(title)
        .font(.caption.weight(.semibold))
        .textCase(.uppercase)
        .tracking(0.8)
        .foregroundStyle(Theme.inkSoft)
}
