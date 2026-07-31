import SwiftUI

/// The app's whole palette and the phylum table. No view writes a colour literal:
/// changing the look means changing this file and nothing else.
enum Theme {
    static let paper = Color("Paper")
    static let surface = Color("Surface")
    static let ink = Color("Ink")
    static let inkSoft = Color("InkSoft")
    static let rule = Color("Rule")
    static let signal = Color("Signal")

    // No `Theme.accent` constant: the "Accent" colour set drives the app's
    // global tint (`ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` in
    // project.yml) — links, selection and every `Button` pick it up
    // automatically. Nothing in Swift needs to read the value directly; add
    // the constant back only if a view ever needs the raw colour.

    /// One entry per taxonomic phylum, plus the AUTRES root — two species hang
    /// straight off it and it has no children, so it is its own phylum.
    /// Hues are spaced so that groups shown side by side stay distinguishable;
    /// DORIS's own `couleurGroupe` is not usable here (all five roots land in the
    /// same olive band).
    static let allPhyla: [Phylum] = [
        Phylum(id: 55, base: 0x306E9B, tint: 0xD9E7F1, symbol: "fossil.shell"),
        Phylum(id: 104, base: 0x303F9B, tint: 0xD9DCF1, symbol: "fish"),
        Phylum(id: 78, base: 0x57309B, tint: 0xE2D9F1, symbol: "ant"),
        Phylum(id: 21, base: 0x8C309B, tint: 0xEED9F1, symbol: "circles.hexagonpath"),
        Phylum(id: 26, base: 0x9B3074, tint: 0xF1D9E8, symbol: "umbrella"),
        Phylum(id: 47, base: 0x9B303F, tint: 0xF1D9DC, symbol: "hurricane"),
        Phylum(id: 72, base: 0x9B5730, tint: 0xF1E2D9, symbol: "circles.hexagongrid"),
        Phylum(id: 98, base: 0x836D29, tint: 0xF1EBD9, symbol: "capsule.portrait"),
        Phylum(id: 90, base: 0x697424, tint: 0xEEF1D9, symbol: "allergens"),
        Phylum(id: 45, base: 0x437C27, tint: 0xE1F1D9, symbol: "oval"),
        Phylum(id: 20, base: 0x287F4C, tint: 0xD9F1E3, symbol: "microbe"),
        Phylum(id: 175, base: 0x277C74, tint: 0xD9F1EF, symbol: "circle.grid.cross"),
        Phylum(id: 6, base: 0x277C5C, tint: 0xD9F1E8, symbol: "leaf"),
        Phylum(id: 14, base: 0x517825, tint: 0xE6F1D9, symbol: "camera.macro"),
        Phylum(id: 5, base: 0x2A7887, tint: 0xD9EDF1, symbol: "hexagon"),
        Phylum(id: 13, base: 0x287F34, tint: 0xD9F1DC, symbol: "laurel.leading"),
        Phylum(id: 18, base: 0x97632F, tint: 0xF1E5D9, symbol: "point.3.connected.trianglepath.dotted"),
        Phylum(id: 3, base: 0x74309B, tint: 0xE8D9F1, symbol: "capsule"),
        // AUTRES (root, 2 species, no children). `circle.grid.cross` is already
        // taken by "Autres groupes mineurs" above, so this one gets its own
        // symbol — otherwise two entries would be distinguishable only by
        // colour, and `symbolsAreDistinct` would fail by construction.
        Phylum(id: 177, base: 0x5F5E5A, tint: 0xEDECEA, symbol: "questionmark.circle"),
    ]

    private static let byId = Dictionary(uniqueKeysWithValues: allPhyla.map { ($0.id, $0) })
    private static let neutral = Phylum(id: 0, base: 0x5F5E5A, tint: 0xEDECEA, symbol: "circle.grid.cross")

    /// Never optional: an unknown id renders neutrally rather than blanking a row.
    static func phylum(_ id: Int) -> Phylum { byId[id] ?? neutral }
}

struct Phylum {
    let id: Int
    let base: Color
    let tint: Color
    let symbol: String

    init(id: Int, base: UInt32, tint: UInt32, symbol: String) {
        self.id = id
        self.base = Color(hex: base)
        self.tint = Color(hex: tint)
        self.symbol = symbol
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
