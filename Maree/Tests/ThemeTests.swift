import Testing
import SwiftUI
@testable import Maree

@Suite("Thème")
@MainActor
struct ThemeTests {
    /// WCAG relative luminance, then the AA contrast ratio.
    ///
    /// `Color("Paper")` etc. are dynamic (light + dark variants), so resolving them
    /// through `UIColor(color).cgColor.components` would depend on whatever trait
    /// collection happens to be current — undefined in a unit test. Resolve
    /// explicitly against light mode instead, and read channels with
    /// `getRed(_:green:_:blue:_:alpha:)`, which always yields RGB regardless of the
    /// underlying colour space (unlike `.cgColor.components`, which can return fewer
    /// than three entries for a non-RGB space).
    private func contrast(_ a: Color, _ b: Color) -> Double {
        func luminance(_ color: Color) -> Double {
            let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
            resolved.getRed(&r, green: &g, blue: &b, alpha: &alpha)
            func channel(_ v: CGFloat) -> Double {
                let v = Double(v)
                return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
        }
        let (l1, l2) = (luminance(a), luminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    @Test("chaque couleur de base tient AA sur le papier")
    func basesAreLegibleOnPaper() {
        for phylum in Theme.allPhyla {
            let ratio = contrast(phylum.base, Theme.paper)
            #expect(ratio >= 4.5, "phylum \(phylum.id) : \(ratio)")
        }
    }

    @Test("le texte principal tient AA sur le papier et sur la surface")
    func inkIsLegible() {
        #expect(contrast(Theme.ink, Theme.paper) >= 4.5)
        #expect(contrast(Theme.ink, Theme.surface) >= 4.5)
    }

    @Test("un identifiant inconnu retourne l'entrée neutre au lieu de planter")
    func unknownIdFallsBack() {
        let neutral = Theme.phylum(999_999)
        #expect(neutral.symbol == "circle.grid.cross")
    }

    @Test("la table couvre tous les phylumId de la base")
    func tableCoversTheDatabase() throws {
        let reader = try AppDatabase().reader
        let ids = try reader.read { db in
            try Int.fetchSet(db, sql: "SELECT DISTINCT phylumId FROM species")
        }
        let known = Set(Theme.allPhyla.map(\.id))
        #expect(ids.subtracting(known).isEmpty, "phylumId sans entrée : \(ids.subtracting(known))")
    }

    @Test("deux embranchements affichés ensemble n'ont pas le même symbole")
    func symbolsAreDistinct() {
        let symbols = Theme.allPhyla.map(\.symbol)
        #expect(Set(symbols).count == symbols.count)
    }
}
