# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@.claude/rules/swift.md
@docs/PRD.md

## Projet

Marée : app iOS native SwiftUI de consultation hors-ligne des fiches DORIS/FFESSM.
Le PRD importé ci-dessus est la référence produit — le critère n°1 y est défini :
tout contenu doit être disponible hors ligne, sans condition.

État : v1 implémentée (pipeline + app, 11 tâches), puis refonte visuelle
(palette guide de terrain, code couleur par embranchement, icône). Le projet Xcode
(`Maree/Maree.xcodeproj`) est **généré par XcodeGen** à partir de `Maree/project.yml`
et n'est pas commité (gitignoré) — éditer `project.yml`, jamais le `.xcodeproj`.

## Commandes

- Avant le premier build (dans cet ordre) :
  1. `node tools/prepare-db.mjs` — écrit `Maree/Resources/maree.db` (SQLite + FTS5,
     ~19 Mo, gitignoré, régénéré à chaque run). Vérifier : `node tools/verify-db.mjs`.
  2. `cd Maree && xcodegen generate` — (re)génère `Maree.xcodeproj` depuis `project.yml`.
- Build/test : `cd Maree && xcodebuild test -scheme MareeTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` ;
  ou `/ios-simulator-skill` pour build, lancement et pilotage du simulateur.
- Vérifs d'accessibilité au simulateur (UDID via `xcrun simctl list devices booted`) :
  `xcrun simctl ui <UDID> content_size accessibility-extra-extra-extra-large` et
  `xcrun simctl ui <UDID> appearance dark` — remettre `medium` / `light` ensuite.
- Tests du pipeline : `node --test 'tools/lib/*.test.mjs'` (la forme répertoire
  `node --test tools/lib/` est cassée sur ce build Node 26.5, échoue en `MODULE_NOT_FOUND`).
- Publier les vignettes : `node tools/generate-thumbs.mjs` (idempotent, `--force` pour
  republier). **Ce script écrit dans le bucket de production** : déjà exécuté pour le pack
  v1, il n'y a aucune raison de le relancer sans intention explicite. Pour l'exercer, passer
  un `--limit` (validé depuis qu'un `--limit=0` falsy a renvoyé ~100 objets par accident).

## Données DORIS — particularités

- Source : `~/src/skynewz/doris-pwa/DorisAndroid.db` (50 Mo, SQLite extrait de l'APK
  Android). **doris-pwa est en lecture seule, ne jamais y écrire.** Le schéma est
  documenté dans `doris-pwa/scripts/fetch-doris.js`, dont la logique de nettoyage
  (markup `{{…}}`, sections typées) est à réutiliser dans `tools/prepare-db`.
- `fiche._id` ≠ `fiche.numeroFiche` : les jointures internes utilisent `_id`, mais la
  clé publique (et les chemins d'images) est **`numeroFiche`**.
- Images : bucket public `https://s3.us-east-005.backblazeb2.com/doris-production`,
  chemins `images/{numeroFiche}/{n}.jpg` (indices alignés sur `photoFiche` trié par
  `_id`, vérifié) ; vignettes app sous `images/{numeroFiche}/0_maree.heic` (400 px,
  qualité 50). Ne pas modifier le contenu existant du bucket (la PWA déployée le
  consomme).
- Pack de vignettes publié : 2 821 objets, ~16 Ko en moyenne, ~46 Mo au total. 16
  espèces n'ont aucune image dans le bucket (`photoCount` sans objet derrière, gap
  pré-existant côté PWA, hors périmètre v1) — `ImageStore` les enregistre dans
  `unavailable.json`, à côté du cache, pour ne plus jamais les retenter, y compris sur
  le chemin d'affichage. « Revérifier les images » dans Réglages efface ce registre.
- Filtre Europe : zones `1,2,3,5` → 2 837 fiches. Les 15 titres de `sectionFiche`
  forment une enum fermée.
- Une **racine est un règne, pas un embranchement** : son `phylumId` est elle-même, et
  des 5 racines seule `AUTRES` (177) figure dans `Theme.allPhyla`. `GroupLabel` ne
  dessine donc pas de pastille quand `parentId IS NULL` — sinon 4 racines partagent la
  même pastille grise. `tableCoversTheDatabase` exclut les racines pour la même raison.

## Décisions de nommage

- `Section` (`Maree/Sources/Database/Models.swift`) masque volontairement
  `SwiftUI.Section` — c'est le nom du type GRDB pour une section de fiche DORIS.
  Ne jamais le renommer ; qualifier `SwiftUI.Section` au point d'appel dans les vues.
- L'erreur de base de données s'appelle `AppDatabaseError`, pas `DatabaseError` :
  GRDB exporte déjà un `DatabaseError` public, et un type local du même nom gagnerait
  la résolution non qualifiée sans erreur de compilation — un `catch let error as
  DatabaseError` visant une panne SQLite compilerait et ne matcherait jamais.
- `@Entry` génère une valeur d'environnement **calculée** : elle se réévalue à
  chaque lecture. Toute valeur exposée par `@Entry` doit donc pointer vers un
  singleton déjà mémoïsé (`X.shared`), sinon chaque `@Environment(\.x)` reconstruit
  une nouvelle instance (nouvelle connexion DB, nouveau pack de téléchargement...).
  Ce piège a coûté trois régressions pendant l'implémentation.

## Palette et thème

- `Maree/Sources/Views/Theme.swift` est la **seule** source de couleur : aucune vue
  n'écrit de littéral. Les 7 couleurs nommées sont des Color Sets qui **s'adaptent**
  clair/sombre, les 19 `base`/`tint` d'embranchement sont des hex **fixes**. Ne jamais
  dessiner une couleur adaptative sur une couleur fixe : `Theme.ink` sur une teinte
  figée a livré un badge illisible en sombre (~1,1:1). Les fonds de chips passent par
  `Phylum.chipBackground` / `Theme.signalChip`, qui composent au-dessus de la page.
- `ThemeTests` prend une **apparence** et boucle sur `[.light, .dark]` : un helper qui
  ne résout que le clair laisse passer exactement ce bug. Ces tests comparent des paires
  de couleurs, ils ne voient pas ce que `Badge` dessine réellement.
- La couleur d'accent vient de l'asset catalog
  (`ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: Accent`), **pas** du Swift : il n'y
  a volontairement pas de `Theme.accent`.

## Pièges

- Le dossier `Marée` est en NFD (accent) : **target, scheme et bundle id restent
  ASCII (`Maree`)**, `CFBundleDisplayName = Marée`. Toujours quoter les chemins.
- Le clavier matériel du simulateur est en **AZERTY** : saisir du texte via
  `simctl`/MCP tape `q` pour `a` et `,` pour `m`. Compenser en envoyant la lettre de la
  position QWERTY (`;elosirq` produit `melosira`), ou vérifier ce qui s'est écrit.
- Free provisioning : profil 7 jours — dev au simulateur, l'iPhone n'est qu'une
  validation ponctuelle. Un seul bundle identifier (quota 10 App IDs / 7 jours).
  App Groups, push, CloudKit, widgets : indisponibles, ne pas en proposer.
- Ce toolchain **ignore silencieusement** `INFOPLIST_KEY_UILaunchScreen_UIColorName`
  (absent de la whitelist de `SWBCore`) : l'écran de lancement passe par
  `Maree/Support/LaunchScreenInfo.plist` + `INFOPLIST_FILE`. Ne pas « simplifier » en
  revenant à la clé, elle ne produit rien et le build reste vert.
- Swift Testing : `@Test(arguments:)` évalue sa collection **hors** du corps du test,
  donc elle ne peut pas contenir de `static let` isolé au MainActor (`Theme.ink` & co)
  — « expression is 'async' but is not marked with 'await' ».
