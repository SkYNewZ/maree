import Testing
import SwiftUI
@testable import Maree

@Suite("Thème")
@MainActor
struct ThemeTests {
    /// WCAG relative luminance, then the AA contrast ratio, resolved against a given
    /// appearance.
    ///
    /// `Color("Paper")` etc. are dynamic (light + dark variants), so resolving them
    /// through `UIColor(color).cgColor.components` would depend on whatever trait
    /// collection happens to be current — undefined in a unit test. Resolve
    /// explicitly against the requested appearance instead, and read channels with
    /// `getRed(_:green:_:blue:_:alpha:)`, which always yields RGB regardless of the
    /// underlying colour space (unlike `.cgColor.components`, which can return fewer
    /// than three entries for a non-RGB space).
    ///
    /// Task 7 fix round: this used to hardcode `.light`, so nothing in this file could
    /// ever fail on a dark-mode-only contrast bug — which is exactly how the group
    /// badge (`FicheView.swift`) shipped unreadable in dark mode. Every call site below
    /// now states its appearance explicitly.
    private func contrast(_ a: Color, _ b: Color, appearance: UIUserInterfaceStyle) -> Double {
        func luminance(_ color: Color) -> Double {
            let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: appearance))
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
            // getRed(...) returns false for a non-RGB colour space, leaving r/g/b at
            // 0 — silently measuring black. Every colour in this file is declared
            // srgb, so this never fires today, but a guard that could pass wrongly
            // is not a guard: fail loudly instead of computing a bogus ratio.
            guard resolved.getRed(&r, green: &g, blue: &b, alpha: &alpha) else {
                Issue.record("could not read RGB components of \(color)")
                return 0
            }
            func channel(_ v: CGFloat) -> Double {
                let v = Double(v)
                return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
        }
        let (l1, l2) = (luminance(a), luminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    private static let appearances: [UIUserInterfaceStyle] = [.light, .dark]

    /// `base` is never drawn as text. Its only two uses are the `PhylumBadge` symbol —
    /// painted on `tint`, not on `paper` — and the 3px decorative rule under the fiche
    /// header, which carries no text and no WCAG contrast requirement at all. The old
    /// assertion (`base` vs `paper` at the 4.5:1 text threshold) guarded a pairing that
    /// does not exist on screen; in dark mode `base` has no dark variant and sits
    /// dark-on-dark, so it would fail that check for a reason unrelated to any real
    /// defect. The honest guard is the pairing that is actually on screen: a symbol is
    /// a graphical object under WCAG 1.4.11, threshold 3:1, not 4.5:1. `base` and
    /// `tint` are both fixed hex literals with no dark variant, so today this ratio is
    /// identical in both appearances — asserted in both anyway so a future dark variant
    /// on either side is caught here instead of on a device.
    @Test("chaque couleur de base reste un objet graphique distinct sur sa teinte")
    func basesAreDistinctOnTint() {
        for style in Self.appearances {
            for phylum in Theme.allPhyla {
                let ratio = contrast(phylum.base, phylum.tint, appearance: style)
                #expect(ratio >= 3.0, "phylum \(phylum.id) [\(style)]: \(ratio)")
            }
        }
    }

    @Test("le texte principal tient AA sur le papier et sur la surface")
    func inkIsLegible() {
        for style in Self.appearances {
            #expect(contrast(Theme.ink, Theme.paper, appearance: style) >= 4.5, "\(style)")
            #expect(contrast(Theme.ink, Theme.surface, appearance: style) >= 4.5, "\(style)")
        }
    }

    /// `Theme.inkSoft` is the caption and secondary-text colour on both `Theme.paper`
    /// (list backgrounds, empty states) and `Theme.surface` (cards, chips) — nothing
    /// guarded its contrast until now (measured 4.907:1 on paper, 5.158:1 on surface,
    /// light mode; 6.739:1 / 6.149:1 in dark).
    @Test("le texte secondaire tient AA sur le papier et sur la surface")
    func inkSoftIsLegible() {
        for style in Self.appearances {
            #expect(contrast(Theme.inkSoft, Theme.paper, appearance: style) >= 4.5, "\(style)")
            #expect(contrast(Theme.inkSoft, Theme.surface, appearance: style) >= 4.5, "\(style)")
        }
    }

    @Test("un identifiant inconnu retourne l'entrée neutre, dont le symbole ne collisionne avec aucune entrée de la table")
    func unknownIdFallsBack() {
        let neutral = Theme.phylum(999_999)
        #expect(neutral.id == 0)
        #expect(!Theme.allPhyla.contains { $0.symbol == neutral.symbol })
    }

    /// Every id `Theme.phylum(_:)` is actually asked to resolve on screen: every
    /// species (`SpeciesRow`, the fiche header) and every non-root group
    /// (`GroupLabel`, badged). Root groups are deliberately excluded — a root is
    /// a kingdom, not a phylum, and draws no badge at all (`GroupLabel`), so the
    /// four roots without a species of their own legitimately have no entry.
    /// Widening this to all of `taxonGroup` would fail on those four roots for a
    /// state that is correct by design.
    @Test("la table couvre tous les phylumId affichés à l'écran")
    func tableCoversTheDatabase() throws {
        let reader = try AppDatabase().reader
        let ids = try reader.read { db in
            try Int.fetchSet(db, sql: """
                SELECT phylumId FROM species
                UNION
                SELECT phylumId FROM taxonGroup WHERE parentId IS NOT NULL
                """)
        }
        let known = Set(Theme.allPhyla.map(\.id))
        #expect(ids.subtracting(known).isEmpty, "phylumId sans entrée : \(ids.subtracting(known))")
    }

    @Test("deux embranchements affichés ensemble n'ont pas le même symbole")
    func symbolsAreDistinct() {
        let symbols = Theme.allPhyla.map(\.symbol)
        #expect(Set(symbols).count == symbols.count)
    }

    /// Flattens a translucent colour over an opaque backdrop, the way UIKit
    /// composites it on screen — `contrast(_:_:appearance:)` reads raw RGB and
    /// ignores alpha, so a chip's true on-screen colour has to be pre-blended
    /// before it is measured. `foreground`'s own alpha channel drives the mix,
    /// so passing `Phylum.chipBackground` or `Theme.signalChip` here blends with
    /// whatever opacity that formula actually uses — not a copy of it.
    private func blend(_ foreground: Color, over background: Color, appearance: UIUserInterfaceStyle) -> Color {
        func components(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
            let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: appearance))
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            guard resolved.getRed(&r, green: &g, blue: &b, alpha: &a) else {
                Issue.record("could not read RGBA components of \(color)")
                return (0, 0, 0, 1)
            }
            return (r, g, b, a)
        }
        let f = components(foreground)
        let b = components(background)
        return Color(
            red: Double(f.r * f.a + b.r * (1 - f.a)),
            green: Double(f.g * f.a + b.g * (1 - f.a)),
            blue: Double(f.b * f.a + b.b * (1 - f.a))
        )
    }

    /// Guards owner ruling #1 (Task 5): every chip on the species screen draws
    /// `Theme.ink` as text, never the phylum or signal colour itself — the plan's
    /// original pairing (colour-as-text) measured as low as 2.78:1 in light mode.
    ///
    /// Measures `Phylum.chipBackground` and `Theme.signalChip` directly — the same
    /// properties `FicheView` and `FicheSections` draw chip backgrounds with, not a
    /// re-derived copy of their formula. Moving either property's opacity in
    /// Theme.swift moves both the rendered chip and the ratio measured here.
    @Test("le texte des badges tient AA sur chaque teinte d'embranchement et sur le fond du chip signal")
    func badgeTextIsLegible() {
        for style in Self.appearances {
            for phylum in Theme.allPhyla {
                let background = blend(phylum.chipBackground, over: Theme.paper, appearance: style)
                let ratio = contrast(Theme.ink, background, appearance: style)
                #expect(ratio >= 4.5, "phylum \(phylum.id) group badge [\(style)]: \(ratio)")
            }
            let signalChipBackground = blend(Theme.signalChip, over: Theme.paper, appearance: style)
            let ratio = contrast(Theme.ink, signalChipBackground, appearance: style)
            #expect(ratio >= 4.5, "signal chip [\(style)]: \(ratio)")
        }
    }
}
