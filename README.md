# Marée

App iOS native (SwiftUI) de consultation **hors ligne** des fiches espèces sous-marines
[DORIS](https://doris.ffessm.fr) (FFESSM). Portage repensé d'une PWA dont iOS purgeait
le stockage après ~7 jours — ici, la base est embarquée : *« j'ouvre l'app au bord de
l'eau, sans réseau, trois semaines après ma dernière plongée »* fonctionne toujours.

Projet personnel, double objectif : une app réellement utilisable en plongée, et
l'apprentissage du développement iOS.

## Contenu

- 2 837 fiches espèces (zones Europe : côtes françaises, Atlantique NE/NO, Méditerranée),
  extraites de la base DORIS et embarquées dans l'app (`maree.db`, SQLite + FTS5, ~19 Mo).
- Vignettes téléchargées automatiquement au premier lancement (~46 Mo, 2 821 images ;
  16 fiches sans photo dans le bucket source affichent un espace réservé) ; photos plein
  format à la demande avec cache persistant et préchargement « préparer une sortie ».

## Structure

| Chemin | Rôle |
|---|---|
| `docs/PRD.md` | Périmètre v1 validé — la référence produit |
| `tools/` | Pipeline de préparation des données (`prepare-db`, `generate-thumbs`) |
| `Maree/` | Projet Xcode (target ASCII `Maree`, affiché « Marée ») — `project.yml` source de vérité, `.xcodeproj` généré |

## Prérequis

- Xcode 26.6+, iOS 26 SDK.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) et
  Node.js (pour le pipeline de données).
- Signature en compte Apple gratuit (free provisioning) : profil 7 jours, dev au
  simulateur, déploiement iPhone ponctuel. Aucune publication App Store.

## Démarrer

Le dépôt ne contient ni la base embarquée ni le projet Xcode : les deux sont générés
et gitignorés.

```bash
node tools/prepare-db.mjs      # écrit Maree/Resources/maree.db (~19 Mo)
cd Maree && xcodegen generate  # écrit Maree.xcodeproj depuis project.yml
open Maree.xcodeproj           # puis Cmd+R dans le simulateur
```

`prepare-db.mjs` lit par défaut `~/src/skynewz/doris-pwa/DorisAndroid.db` (base source
DORIS, non incluse au dépôt — projet personnel) ; passer `--source=<chemin>` sinon.
Cette base est le seul intrant non reproductible du projet — extraite de l'app Android
DORIS, 50,3 Mo (52 791 296 octets), base datée du 07/08/2025, copie locale du 20/06/2026,
sha256 `354ca2f47a322b4a65eeffb942ef85800454baa000a38bf3a792ecbbb0d7b7a4`.

Les vignettes se téléchargent au premier lancement de l'app (voir `tools/generate-thumbs.mjs`
pour republier le pack sur le bucket ; déjà fait pour la v1, inutile en usage normal).

## Données et droits

Les fiches et photos appartiennent à la FFESSM/DORIS (source : base de l'app Android
DORIS). Usage strictement personnel, déploiement développeur uniquement.
