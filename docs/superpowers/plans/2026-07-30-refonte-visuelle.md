# Refonte visuelle « guide de terrain » — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Donner à Marée une identité visuelle — icône, écran de lancement, palette papier chaud, et un code couleur + icône par embranchement taxonomique — sans toucher à la navigation, aux données ni au comportement hors ligne.

**Architecture:** Le pipeline précalcule un `phylumId` par espèce et par groupe (remonter l'arbre à chaque ligne de liste serait le défaut de conception que ce projet vient de corriger). L'app lit cette colonne et la traverse dans une table statique de 19 entrées qui associe une couleur et un SF Symbol. Toute la présentation passe par un unique fichier `Theme.swift` ; les vues n'écrivent jamais une couleur en dur.

**Tech Stack:** Node 26 (`node:sqlite`, `node:test`) · Swift 6 / SwiftUI / iOS 26 · GRDB 7.11.1 · Swift Testing · XcodeGen

## Global Constraints

- iOS 26.0, iPhone uniquement, portrait. Swift 6, concurrence stricte, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. **Un avertissement compilateur est un échec de tâche.**
- Dépendance Swift unique : GRDB 7.11.1. Dans `tools/` : modules `node:` intégrés uniquement.
- Textes affichés en **français** accentué ; code, commentaires et symboles en **anglais**.
- Le type `Section` masque volontairement `SwiftUI.Section` : ne jamais le renommer, qualifier `SwiftUI.Section` au point d'appel. L'erreur de base s'appelle `AppDatabaseError`.
- `@Entry` génère une valeur **calculée** : toute valeur d'environnement doit pointer vers un singleton déjà mémoïsé.
- Sous *Approachable Concurrency*, `nonisolated async` hérite de l'isolation de l'appelant ; utiliser `@concurrent nonisolated` pour sortir un travail bloquant.
- **Toute paire texte/fond tient AA (4,5:1).** Aucune information portée par la couleur seule.
- **Interdit de toucher** : la navigation, les 4 onglets, l'ordre des sections, la couche données au-delà de la colonne ajoutée en tâche 1, et tout ce qui concerne le réseau ou le cache d'images.
- `Maree/Maree.xcodeproj` est généré par XcodeGen — éditer `project.yml`.
- `node tools/generate-thumbs.mjs` **écrit en production** : ne jamais l'exécuter dans ce chantier.
- Commits conventionnels, sur `develop`.

## Faits vérifiés (ne pas re-mesurer)

- Arbre des groupes : 160 nœuds — 5 racines (profondeur 0), **18 embranchements** (profondeur 1), 54 / 81 / 2 aux profondeurs suivantes.
- Les espèces se rattachent à toutes les profondeurs : 2 à une racine, 54 à un embranchement, 1 070 / 1 688 / 23 plus bas. **Les 2 espèces de profondeur 0 sont sous `AUTRES`, une racine sans enfant** — elles n'ont donc pas d'ancêtre de niveau 1. La table Swift compte pour cette raison **19 entrées** : les 18 embranchements plus la racine `AUTRES`.
- Les 19 SF Symbols sont vérifiés présents dans `CoreGlyphs.bundle/name_availability.plist`.
- Vues existantes et leur taille : `SpeciesRow` 33 l., `ExploreView` 54 l., `GroupView` 94 l., `FicheView` 132 l., `FicheSections` 98 l., `SettingsView` 116 l.
- `TaxonGroup` expose déjà `id`, `parentId`, `name`, `scientificHint`, `speciesCount`.

## Structure de fichiers

| Fichier | Responsabilité |
|---|---|
| `tools/lib/schema.sql` | + colonne `phylumId` sur `species` et `taxonGroup` |
| `tools/prepare-db.mjs` | calcul du `phylumId` par remontée d'arbre |
| `tools/verify-db.mjs` | + assertion : tout `phylumId` est résoluble |
| `Maree/Sources/Views/Theme.swift` | **nouveau** — palette et table des 19 embranchements |
| `Maree/Sources/Database/Models.swift` | + `phylumId` sur `Species` et `TaxonGroup` |
| `Maree/Sources/Views/PhylumBadge.swift` | **nouveau** — la pastille, seule vue qui dessine une icône |
| `Maree/Sources/Views/SpeciesRow.swift` | pastille + vignette 72 px |
| `Maree/Sources/Views/ExploreView.swift`, `GroupView.swift` | pastille par ligne de groupe |
| `Maree/Sources/Views/FicheView.swift`, `FicheSections.swift` | bandeau, filet coloré, titres capitalisés |
| `Maree/Sources/Views/SearchView.swift` | état d'accueil illustré |
| `Maree/Resources/Assets.xcassets` | icône d'app, couleurs nommées |
| `Maree/project.yml` | clés `INFOPLIST` de l'écran de lancement |
| `Maree/Tests/ThemeTests.swift` | **nouveau** — contraste AA, couverture des 19 entrées |

---

### Task 1 : `phylumId` précalculé par le pipeline

**Files:**
- Modify: `tools/lib/schema.sql`
- Modify: `tools/prepare-db.mjs`
- Modify: `tools/verify-db.mjs`

**Interfaces:**
- Consumes: rien.
- Produces : colonnes `species.phylumId` et `taxonGroup.phylumId`, toutes deux `INTEGER NOT NULL REFERENCES taxonGroup(id)`. Définition : l'ancêtre de profondeur 1 du groupe, ou le groupe lui-même s'il est une racine. La tâche 2 en dépend.

- [ ] **Step 1 : ajouter la colonne au schéma**

Dans `tools/lib/schema.sql`, ajouter à `species` (après `groupId`) et à `taxonGroup` (après `parentId`) :

```sql
  phylumId         INTEGER NOT NULL REFERENCES taxonGroup(id),
```

Et un index, à côté des autres :

```sql
CREATE INDEX species_phylumId ON species(phylumId);
```

- [ ] **Step 2 : écrire l'assertion de vérification d'abord**

Dans `tools/verify-db.mjs`, ajouter à la map `orphans` :

```js
    'species.phylumId': count('SELECT COUNT(*) AS c FROM species WHERE phylumId NOT IN (SELECT id FROM taxonGroup)'),
    'taxonGroup.phylumId': count('SELECT COUNT(*) AS c FROM taxonGroup WHERE phylumId NOT IN (SELECT id FROM taxonGroup)'),
```

et, après les contrôles existants, l'assertion de forme — un `phylumId` doit être une racine ou l'enfant d'une racine :

```js
  const badPhylum = count(`
    SELECT COUNT(*) AS c FROM taxonGroup p
    WHERE p.id IN (SELECT phylumId FROM taxonGroup UNION SELECT phylumId FROM species)
      AND p.parentId IS NOT NULL
      AND p.parentId NOT IN (SELECT id FROM taxonGroup WHERE parentId IS NULL)
  `)
  if (badPhylum > 0) problems.push(`${badPhylum} phylumId are neither a root nor a root's child`)
```

- [ ] **Step 3 : lancer la vérification contre la base actuelle**

Run: `node tools/verify-db.mjs`
Expected: FAIL — `no such column: phylumId`. C'est la preuve RED : l'assertion regarde bien une colonne qui n'existe pas encore.

- [ ] **Step 4 : calculer `phylumId` dans `prepare-db.mjs`**

Après le calcul récursif de `speciesCount` et **avant** l'élagage des branches vides, insérer :

```js
// The phylum is the depth-1 ancestor — the level the UI colours and iconifies.
// A species attached straight to a root (AUTRES has no children) is its own phylum.
db.exec(`
  WITH RECURSIVE climb(id, cur, parent) AS (
    SELECT id, id, parentId FROM taxonGroup
    UNION ALL
    SELECT c.id, g.id, g.parentId FROM climb c JOIN taxonGroup g ON g.id = c.parent
  )
  UPDATE taxonGroup SET phylumId = (
    SELECT cur FROM climb
    WHERE climb.id = taxonGroup.id AND (climb.parent IS NULL OR climb.parent IN (
      SELECT id FROM taxonGroup WHERE parentId IS NULL
    ))
    LIMIT 1
  )
`)
db.exec(`UPDATE species SET phylumId = (SELECT phylumId FROM taxonGroup WHERE id = species.groupId)`)
```

`taxonGroup` étant inséré avec `phylumId` non nul, ajouter la colonne à l'insert avec une valeur provisoire — l'`id` lui-même :

```js
const insertGroup = db.prepare(
  'INSERT INTO taxonGroup (id, parentId, name, scientificHint, speciesCount, phylumId) VALUES (?, ?, ?, ?, 0, ?)'
)
```
appelé avec `insertGroup.run(g._id, parentId, clean(g.nomGroupe), scientificHint(g.descriptionGroupe), g._id)`.

Même chose pour `species` : ajouter `phylumId` à la liste de colonnes et passer `f.groupe_id` comme valeur provisoire, corrigée par l'`UPDATE` ci-dessus.

- [ ] **Step 5 : régénérer et vérifier**

Run: `node tools/prepare-db.mjs && node tools/verify-db.mjs`
Expected: `OK`, `species: 2837`.

- [ ] **Step 6 : contrôler la distribution à la main**

Run:
```bash
sqlite3 -box Maree/Resources/maree.db "SELECT g.name, COUNT(*) AS especes FROM species s JOIN taxonGroup g ON g.id = s.phylumId GROUP BY g.name ORDER BY especes DESC;"
```
Expected : 19 lignes au plus, dont `Mollusques` 597, `Vertébrés` 541, `Arthropodes` 323 et `AUTRES` 2. La somme fait 2 837.

- [ ] **Step 7 : commit**

```bash
git add tools/lib/schema.sql tools/prepare-db.mjs tools/verify-db.mjs
git commit -m "feat(tools): precompute each species' phylum"
```

---

### Task 2 : `Theme.swift` — palette et table des embranchements

**Files:**
- Create: `Maree/Sources/Views/Theme.swift`
- Modify: `Maree/Sources/Database/Models.swift`
- Test: `Maree/Tests/ThemeTests.swift`

**Interfaces:**
- Consumes: `species.phylumId`, `taxonGroup.phylumId` (tâche 1).
- Produces :
  - `enum Theme` avec `static let paper/surface/ink/inkSoft/rule/accent/signal: Color`
  - `struct Phylum { let id: Int; let base: Color; let tint: Color; let symbol: String }`
  - `Theme.phylum(_ id: Int) -> Phylum` — jamais optionnel, retourne une entrée neutre si l'id est inconnu
  - `Species.phylumId: Int` et `TaxonGroup.phylumId: Int`

- [ ] **Step 1 : écrire les tests d'abord**

`Maree/Tests/ThemeTests.swift` :

```swift
import Testing
import SwiftUI
@testable import Maree

@Suite("Thème")
@MainActor
struct ThemeTests {
    /// WCAG relative luminance, then the AA contrast ratio.
    private func contrast(_ a: Color, _ b: Color) -> Double {
        func luminance(_ color: Color) -> Double {
            let c = UIColor(color).cgColor.components ?? [0, 0, 0]
            func channel(_ v: CGFloat) -> Double {
                let v = Double(v)
                return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(c[0]) + 0.7152 * channel(c[1]) + 0.0722 * channel(c[2])
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
```

- [ ] **Step 2 : lancer les tests pour les voir échouer**

Run: `cd Maree && xcodebuild test -scheme MareeTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20`
Expected: échec de compilation — `cannot find 'Theme' in scope`.

- [ ] **Step 3 : ajouter `phylumId` aux records**

Dans `Maree/Sources/Database/Models.swift`, ajouter `var phylumId: Int` à `Species` (après `groupId`) et à `TaxonGroup` (après `parentId`).

- [ ] **Step 4 : écrire `Theme.swift`**

```swift
import SwiftUI

/// The app's whole palette and the phylum table. No view writes a colour literal:
/// changing the look means changing this file and nothing else.
enum Theme {
    static let paper = Color("Paper")
    static let surface = Color("Surface")
    static let ink = Color("Ink")
    static let inkSoft = Color("InkSoft")
    static let rule = Color("Rule")
    static let accent = Color("Accent")
    static let signal = Color("Signal")

    /// One entry per taxonomic phylum, plus the AUTRES root — two species hang
    /// straight off it and it has no children, so it is its own phylum.
    /// Hues are spaced so that groups shown side by side stay distinguishable;
    /// DORIS's own `couleurGroupe` is not usable here (all five roots land in the
    /// same olive band).
    static let allPhyla: [Phylum] = [
        Phylum(id: 30, base: 0x306E9B, tint: 0xD9E7F1, symbol: "fossil.shell"),
        Phylum(id: 31, base: 0x303F9B, tint: 0xD9DCF1, symbol: "fish"),
        Phylum(id: 32, base: 0x57309B, tint: 0xE2D9F1, symbol: "ant"),
        Phylum(id: 33, base: 0x8C309B, tint: 0xEED9F1, symbol: "circles.hexagonpath"),
        Phylum(id: 34, base: 0x9B3074, tint: 0xF1D9E8, symbol: "umbrella"),
        Phylum(id: 35, base: 0x9B303F, tint: 0xF1D9DC, symbol: "hurricane"),
        Phylum(id: 36, base: 0x9B5730, tint: 0xF1E2D9, symbol: "circles.hexagongrid"),
        Phylum(id: 37, base: 0x836D29, tint: 0xF1EBD9, symbol: "capsule.portrait"),
        Phylum(id: 38, base: 0x697424, tint: 0xEEF1D9, symbol: "allergens"),
        Phylum(id: 39, base: 0x437C27, tint: 0xE1F1D9, symbol: "oval"),
        Phylum(id: 40, base: 0x287F4C, tint: 0xD9F1E3, symbol: "microbe"),
        Phylum(id: 41, base: 0x277C74, tint: 0xD9F1EF, symbol: "circle.grid.cross"),
        Phylum(id: 42, base: 0x277C5C, tint: 0xD9F1E8, symbol: "leaf"),
        Phylum(id: 43, base: 0x517825, tint: 0xE6F1D9, symbol: "camera.macro"),
        Phylum(id: 44, base: 0x2A7887, tint: 0xD9EDF1, symbol: "hexagon"),
        Phylum(id: 45, base: 0x287F34, tint: 0xD9F1DC, symbol: "laurel.leading"),
        Phylum(id: 46, base: 0x97632F, tint: 0xF1E5D9, symbol: "point.3.connected.trianglepath.dotted"),
        Phylum(id: 47, base: 0x74309B, tint: 0xE8D9F1, symbol: "capsule"),
        Phylum(id: 48, base: 0x5F5E5A, tint: 0xEDECEA, symbol: "circle.grid.cross"),
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
```

**Les identifiants 30 à 48 sont des exemples et sont presque certainement faux.**
Récupérer les vrais avant d'écrire le fichier :

```bash
sqlite3 Maree/Resources/maree.db "SELECT DISTINCT s.phylumId, g.name FROM species s JOIN taxonGroup g ON g.id = s.phylumId ORDER BY g.name;"
```

Associer chaque ligne à sa couleur et à son symbole d'après le tableau de
`docs/superpowers/specs/2026-07-30-refonte-visuelle-design.md` §5, en faisant
correspondre les **noms**. La dernière entrée du tableau ci-dessus (gris neutre) est
`AUTRES`. Le test `tableCoversTheDatabase` échouera tant qu'un identifiant manque —
c'est lui qui garantit que l'association est complète.

- [ ] **Step 5 : créer les couleurs nommées**

Dans `Maree/Resources/Assets.xcassets`, créer sept Color Sets avec une variante « Any » et une variante « Dark » :

| Nom | Clair | Sombre |
|---|---|---|
| `Paper` | `#FBF7EF` | `#171410` |
| `Surface` | `#FFFDF8` | `#211D18` |
| `Ink` | `#2E2415` | `#F2EBDF` |
| `InkSoft` | `#7A6A50` | `#A99B84` |
| `Rule` | `#E3D9C6` | `#332C24` |
| `Accent` | `#1F4D5C` | `#7FB2C0` |
| `Signal` | `#C9762F` | `#E09A5A` |

Un Color Set est un dossier `<Nom>.colorset` contenant un `Contents.json`. Modèle pour `Paper` :

```json
{
  "colors" : [
    { "color" : { "color-space" : "srgb", "components" : { "red" : "0xFB", "green" : "0xF7", "blue" : "0xEF", "alpha" : "1.000" } }, "idiom" : "universal" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "color" : { "color-space" : "srgb", "components" : { "red" : "0x17", "green" : "0x14", "blue" : "0x10", "alpha" : "1.000" } }, "idiom" : "universal" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 6 : lancer les tests**

Run: `cd Maree && xcodegen generate && xcodebuild test -scheme MareeTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20`
Expected: PASS, sans avertissement. Si `basesAreLegibleOnPaper` échoue, **assombrir la base fautive** — ne jamais abaisser le seuil.

- [ ] **Step 7 : commit**

```bash
git add Maree/Sources/Views/Theme.swift Maree/Sources/Database/Models.swift Maree/Tests/ThemeTests.swift Maree/Resources/Assets.xcassets
git commit -m "feat(app): add the field-guide palette and the phylum table"
```

---

### Task 3 : la pastille et la ligne d'espèce

**Files:**
- Create: `Maree/Sources/Views/PhylumBadge.swift`
- Modify: `Maree/Sources/Views/SpeciesRow.swift`
- Modify: `Maree/Sources/Views/SpeciesListView.swift`

**Interfaces:**
- Consumes: `Theme.phylum(_:)`, `Species.phylumId` (tâche 2).
- Produces: `struct PhylumBadge: View { init(phylumId: Int, size: CGFloat = 28) }` — un cercle teinté portant le symbole, décoratif.

- [ ] **Step 1 : écrire `PhylumBadge.swift`**

```swift
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
```

- [ ] **Step 2 : appliquer à `SpeciesRow`**

Remplacer le corps de `SpeciesRow` par :

```swift
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
```

- [ ] **Step 3 : habiller la liste**

Dans `SpeciesListView`, appliquer les surfaces au `List` — sans changer sa structure :

```swift
List(species) { item in
    NavigationLink(value: Route.species(item.id)) {
        SpeciesRow(species: item)
    }
    .listRowBackground(Theme.surface)
}
.listStyle(.plain)
.scrollContentBackground(.hidden)
.background(Theme.paper)
```

- [ ] **Step 4 : compiler et lancer la suite**

Run: `cd Maree && xcodebuild test -scheme MareeTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -8`
Expected: PASS, zéro avertissement.

- [ ] **Step 5 : commit**

```bash
git add Maree/Sources/Views/PhylumBadge.swift Maree/Sources/Views/SpeciesRow.swift Maree/Sources/Views/SpeciesListView.swift
git commit -m "feat(app): colour species rows by phylum"
```

---

### Task 4 : Explorer et les listes de groupes

**Files:**
- Modify: `Maree/Sources/Views/ExploreView.swift`
- Modify: `Maree/Sources/Views/GroupView.swift`

**Interfaces:**
- Consumes: `PhylumBadge`, `Theme`, `TaxonGroup.phylumId`.
- Produces: rien de nouveau.

- [ ] **Step 1 : pastille et surfaces dans `ExploreView`**

Dans `GroupLabel`, mettre la pastille en tête et appliquer les couleurs :

```swift
struct GroupLabel: View {
    let group: TaxonGroup

    var body: some View {
        HStack(spacing: 12) {
            PhylumBadge(phylumId: group.phylumId)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name).foregroundStyle(Theme.ink)
                HStack(spacing: 6) {
                    if let hint = group.scientificHint {
                        Text(hint).italic()
                    }
                    Text("\(group.speciesCount) espèces")
                }
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
            }
        }
    }
}
```

Sur le `List` d'`ExploreView`, ajouter `.listRowBackground(Theme.surface)` à chaque ligne des deux `SwiftUI.Section`, puis `.scrollContentBackground(.hidden)` et `.background(Theme.paper)` sur le `List`.

- [ ] **Step 2 : mêmes surfaces dans `GroupView`**

Appliquer `.listRowBackground(Theme.surface)`, `.scrollContentBackground(.hidden)` et `.background(Theme.paper)` au `List` des sous-groupes. Ne pas toucher au bouton « Préparer » ni à la logique de branche.

- [ ] **Step 3 : compiler**

Run: `cd Maree && xcodebuild build -scheme Maree -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -3`
Expected: `BUILD SUCCEEDED`, zéro avertissement.

- [ ] **Step 4 : commit**

```bash
git add Maree/Sources/Views/ExploreView.swift Maree/Sources/Views/GroupView.swift
git commit -m "feat(app): badge and warm surfaces in the explore tab"
```

---

### Task 5 : la fiche

**Files:**
- Modify: `Maree/Sources/Views/FicheView.swift`
- Modify: `Maree/Sources/Views/FicheSections.swift`

**Interfaces:**
- Consumes: `Theme`, `PhylumBadge`, `SpeciesDetail`.
- Produces: rien de nouveau.

- [ ] **Step 1 : bandeau plein cadre et filet coloré**

Dans `FicheView.header(_:)`, l'image passe pleine largeur sans marge et un filet de 3 px à la couleur de l'embranchement la sépare du texte :

```swift
private func header(_ detail: SpeciesDetail) -> some View {
    VStack(alignment: .leading, spacing: 0) {
        if detail.species.photoCount > 0 {
            RemoteImage(.photo(speciesId: detail.species.id, position: 0))
                .frame(height: 260)
                .frame(maxWidth: .infinity)
                .clipped()
        }
        Rectangle()
            .fill(Theme.phylum(detail.species.phylumId).base)
            .frame(height: 3)

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                PhylumBadge(phylumId: detail.species.phylumId, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(detail.species.displayName)
                        .font(.title2.bold())
                        .foregroundStyle(Theme.ink)
                    Text(detail.species.scientificName)
                        .font(.headline).italic()
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            badges(detail)
        }
        .padding(.horizontal)
        .padding(.top, 14)
    }
}
```

- [ ] **Step 2 : badges à la palette**

Dans `badges(_:)`, remplacer les teintes système : le groupe prend `Theme.phylum(...).tint` en fond et `.base` en texte, « Réglementée » et « Dangereuse » prennent `Theme.signal`. Le badge de statut a déjà été supprimé, ne pas le réintroduire.

- [ ] **Step 3 : titres de sections et chips de zones**

Dans `FicheSections`, les titres passent en capitales espacées et les chips de zones à la palette :

```swift
Text(section.kind.title)
    .font(.caption.weight(.semibold))
    .textCase(.uppercase)
    .tracking(0.8)
    .foregroundStyle(Theme.inkSoft)
```

et le corps en `Theme.ink`. Les chips de zones utilisent `Theme.signal` en texte sur `Theme.signal.opacity(0.14)`.

- [ ] **Step 4 : fond de la fiche**

Sur le `ScrollView` de `FicheView`, ajouter `.background(Theme.paper)`.

- [ ] **Step 5 : compiler et lancer la suite**

Run: `cd Maree && xcodebuild test -scheme MareeTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -8`
Expected: PASS, zéro avertissement.

- [ ] **Step 6 : commit**

```bash
git add Maree/Sources/Views/FicheView.swift Maree/Sources/Views/FicheSections.swift
git commit -m "feat(app): restyle the species screen"
```

---

### Task 6 : icône d'app, écran de lancement, écrans restants

**Files:**
- Modify: `Maree/Resources/Assets.xcassets` (AppIcon)
- Modify: `Maree/project.yml`
- Modify: `Maree/Sources/Views/SearchView.swift`
- Modify: `Maree/Sources/Views/SettingsView.swift`, `FavoritesView.swift`

**Interfaces:**
- Consumes: `Theme`.
- Produces: rien de nouveau.

- [ ] **Step 1 : produire l'icône d'app**

La source est `~/src/skynewz/doris-pwa/public/icons/icon.svg` (587 octets, **lecture seule — ne rien écrire dans ce dépôt**). En produire un PNG 1024×1024 sans transparence, dans `Maree/Resources/Assets.xcassets/AppIcon.appiconset/` :

```bash
cp ~/src/skynewz/doris-pwa/public/icons/icon.svg /tmp/maree-icon.svg
qlmanage -t -s 1024 -o /tmp /tmp/maree-icon.svg
sips -s format png -z 1024 1024 /tmp/maree-icon.svg.png --out /tmp/AppIcon-1024.png
```

Si `qlmanage` ne rend pas le SVG, ouvrir le fichier dans un navigateur et capturer, ou redessiner le même contenu en PNG : carré plein `#1F4D5C`, deux vagues (`#CFE1E3` puis `#3D8A99`) et une silhouette de poisson `#CFE1E3`. **Vérifier le résultat à l'œil avant de continuer** — une icône d'app tronquée ou transparente est rejetée au build.

`Contents.json` de l'appiconset, format iOS 26 (une seule taille) :

```json
{
  "images" : [ { "filename" : "AppIcon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" } ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 2 : écran de lancement**

Dans `Maree/project.yml`, sous les `settings.base` de la cible `Maree`, remplacer `INFOPLIST_KEY_UILaunchScreen_Generation: YES` par :

```yaml
        INFOPLIST_KEY_UILaunchScreen_UIColorName: Paper
```

Le fond du lancement devient le papier crème, donc la bascule vers l'app ne montre plus de blanc système.

- [ ] **Step 3 : état d'accueil de la recherche**

Dans `SearchView`, le `ContentUnavailableView` prend la palette :

```swift
private var startScreen: some View {
    ContentUnavailableView {
        Label("Chercher une espèce", systemImage: "magnifyingglass")
    } description: {
        Text("Tapez un nom commun ou scientifique. La recherche fonctionne hors ligne, accents facultatifs.")
    }
    .foregroundStyle(Theme.inkSoft)
    .background(Theme.paper)
}
```

et le `NavigationStack` reçoit `.background(Theme.paper)`.

- [ ] **Step 4 : Réglages et Favoris**

Sur le `List` de `SettingsView` : `.listRowBackground(Theme.surface)` sur chaque ligne, `.scrollContentBackground(.hidden)`, `.background(Theme.paper)`. `FavoritesView` hérite de `SpeciesListView`, ne rien y ajouter d'autre que le fond de son `NavigationStack`.

- [ ] **Step 5 : compiler**

Run: `cd Maree && xcodegen generate && xcodebuild build -scheme Maree -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -3`
Expected: `BUILD SUCCEEDED`, zéro avertissement.

- [ ] **Step 6 : commit**

```bash
git add Maree/Resources/Assets.xcassets Maree/project.yml Maree/Sources/Views
git commit -m "feat(app): add the app icon, launch screen and remaining surfaces"
```

---

### Task 7 : accessibilité et finition

**Files:**
- Modify: les vues où la vérification révèle un défaut
- Modify: `docs/PRD.md`

**Interfaces:** aucune.

- [ ] **Step 1 : vérifier Dynamic Type jusqu'à AX3**

Run:
```bash
xcrun simctl ui 0AE4DCEC-D8FA-4401-B73B-130457C7BEF8 content_size accessibility-extra-extra-extra-large
```
Parcourir Rechercher, Explorer, une fiche, Réglages. Chercher : troncature d'un nom d'espèce, pastille qui écrase le texte, chips de zones qui débordent. Corriger ce qui casse — une pastille peut passer en `ViewThatFits`, une ligne peut passer en `VStack` aux grandes tailles.

Remettre ensuite la taille par défaut :
```bash
xcrun simctl ui 0AE4DCEC-D8FA-4401-B73B-130457C7BEF8 content_size medium
```

- [ ] **Step 2 : vérifier le mode sombre**

Run:
```bash
xcrun simctl ui 0AE4DCEC-D8FA-4401-B73B-130457C7BEF8 appearance dark
```
Vérifier les mêmes écrans : aucun texte illisible, aucune surface restée claire, les pastilles restent distinctes. Puis `appearance light`.

- [ ] **Step 3 : vérifier VoiceOver**

Activer VoiceOver au simulateur et balayer une ligne d'espèce. Attendu : le nom commun, le nom scientifique et éventuellement « Espèce dangereuse » sont annoncés **une seule fois** ; la pastille n'est pas annoncée.

- [ ] **Step 4 : mettre le PRD à jour**

Dans `docs/PRD.md` §7 « Design », remplacer la mention d'une conception à faire par ce qui existe : direction guide de terrain, palette AA vérifiée, code couleur et icône par embranchement hérité des 160 groupes.

- [ ] **Step 5 : vérification complète**

Run:
```bash
node --test 'tools/lib/*.test.mjs'
node tools/prepare-db.mjs && node tools/verify-db.mjs
cd Maree && xcodebuild test -scheme MareeTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
Expected: tout au vert, zéro avertissement.

- [ ] **Step 6 : commit**

```bash
git add -A
git commit -m "fix(app): accessibility pass on the redesigned screens"
```

---

## Auto-relecture

**Couverture de la spec :** §3 identité → tâche 6 · §4 palette → tâche 2 (Color Sets) · §5 les 19 entrées → tâches 1 (données) et 2 (table) · §6 écran par écran → tâches 3 (Rechercher), 4 (Explorer), 5 (Fiche), 6 (accueil, Réglages, Favoris) · §7 garde-fous → tâche 7, plus le test de contraste en tâche 2 · §8 hors périmètre → contraintes globales · §9 risque → chaque tâche se termine par la suite de tests.

La galerie n'a délibérément aucune tâche : la spec la déclare inchangée.

**Point de vigilance majeur :** les identifiants de la table `Theme.allPhyla` (30-48 dans l'exemple) sont **faux par construction** — la tâche 2 fait explicitement récupérer les vrais par SQL et les associer par nom, et le test `tableCoversTheDatabase` échoue tant que l'association est incomplète. C'est le seul endroit du plan où le code donné n'est pas à recopier tel quel, et c'est signalé en gras dans la tâche.

**Cohérence des noms vérifiée :** `Theme.phylum(_:)` et `Phylum.base/tint/symbol` (tâche 2) sont consommés tels quels par `PhylumBadge` (tâche 3), `GroupLabel` (tâche 4) et `FicheView` (tâche 5) ; `species.phylumId` / `taxonGroup.phylumId` (tâche 1) portent le même nom en SQL et en Swift.
