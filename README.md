# Marée

App iOS native (SwiftUI) de consultation hors ligne de fiches d'espèces sous-marines.
L'app embarque 2 837 fiches couvrant les côtes européennes (côtes françaises, Atlantique
nord-est et nord-ouest, Méditerranée) et une recherche plein texte. C'est le portage
repensé d'une PWA dont iOS purgeait le stockage après environ sept jours d'inactivité ;
ici la base vit dans le bundle, et *« j'ouvre l'app au bord de l'eau, sans réseau, trois
semaines après ma dernière plongée »* fonctionne toujours.

Projet personnel, avec un double objectif : une app réellement utilisable en plongée,
et l'apprentissage du développement iOS.

## Contenu

- 2 837 fiches espèces embarquées dans `maree.db` (SQLite + FTS5, ~19 Mo, lecture
  seule). Une mise à jour du contenu se fait en rejouant le pipeline puis en
  rebuildant l'app.
- Vignettes téléchargées au premier lancement (~46 Mo, 2 821 images) ; photos plein
  format à la demande, avec cache disque persistant et préchargement « préparer une
  sortie ». Les 16 fiches sans photo affichent un espace réservé.

## Structure

| Chemin | Rôle |
|---|---|
| `docs/PRD.md` | Périmètre v1 validé, la référence produit |
| `tools/` | Pipeline de préparation des données (`prepare-db`, `generate-thumbs`) |
| `Maree/` | Projet Xcode (target ASCII `Maree`, affiché « Marée ») : `project.yml` est la source de vérité, le `.xcodeproj` est généré |

## Prérequis

- Xcode 26.6 ou plus récent, SDK iOS 26.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) et
  Node.js pour le pipeline de données.
- Signature en compte Apple gratuit (free provisioning) : profil de 7 jours,
  développement au simulateur, déploiement iPhone ponctuel. Aucune publication
  App Store.

## Démarrer

Le dépôt ne contient ni la base embarquée ni le projet Xcode : les deux sont générés
et gitignorés.

```bash
node tools/prepare-db.mjs      # écrit Maree/Resources/maree.db (~19 Mo)
cd Maree && xcodegen generate  # écrit Maree.xcodeproj depuis project.yml
open Maree.xcodeproj           # puis Cmd+R dans le simulateur
```

`prepare-db.mjs` lit une base source locale absente du dépôt (projet personnel) ;
passer `--source=<chemin>` pour la désigner. Cette base est le seul intrant non
reproductible du projet : un instantané SQLite de 50,3 Mo (52 791 296 octets), daté
du 07/08/2025, copie locale du 20/06/2026, sha256
`354ca2f47a322b4a65eeffb942ef85800454baa000a38bf3a792ecbbb0d7b7a4`.
`node tools/verify-db.mjs` contrôle la base produite.

Les vignettes se téléchargent toutes seules au premier lancement de l'app.
`tools/generate-thumbs.mjs` sert à republier le pack sur le bucket ; c'est déjà fait
pour la v1, inutile en usage normal.

## Tests

```bash
cd Maree && xcodebuild test -scheme MareeTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

```bash
node --test 'tools/lib/*.test.mjs'
```

## Données et droits

Les textes et photos des fiches restent la propriété de leurs auteurs ; ils ne sont
pas distribués avec ce dépôt, et l'app relève d'un usage strictement personnel. Le
code est sous licence [GPL-3.0](LICENSE).
