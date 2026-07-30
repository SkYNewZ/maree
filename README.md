# Marée

App iOS native (SwiftUI) de consultation **hors ligne** des fiches espèces sous-marines
[DORIS](https://doris.ffessm.fr) (FFESSM). Portage repensé d'une PWA dont iOS purgeait
le stockage après ~7 jours — ici, la base est embarquée : *« j'ouvre l'app au bord de
l'eau, sans réseau, trois semaines après ma dernière plongée »* fonctionne toujours.

Projet personnel, double objectif : une app réellement utilisable en plongée, et
l'apprentissage du développement iOS.

## Contenu

- 2 837 fiches espèces (zones Europe : côtes françaises, Atlantique NE/NO, Méditerranée),
  extraites de la base DORIS et embarquées dans l'app (`maree.db`, SQLite + FTS5, ~28 Mo).
- Vignettes téléchargées automatiquement au premier lancement (~40 Mo) ; photos plein
  format à la demande avec cache persistant et préchargement « préparer une sortie ».

## Structure

| Chemin | Rôle |
|---|---|
| `docs/PRD.md` | Périmètre v1 validé — la référence produit |
| `tools/` | Pipeline de préparation des données (`prepare-db`, `generate-thumbs`) |
| `Maree/` | Projet Xcode (target ASCII `Maree`, affiché « Marée ») |

## Prérequis

- Xcode 26.6+, iOS 26 SDK.
- Signature en compte Apple gratuit (free provisioning) : profil 7 jours, dev au
  simulateur, déploiement iPhone ponctuel. Aucune publication App Store.

## Données et droits

Les fiches et photos appartiennent à la FFESSM/DORIS (source : base de l'app Android
DORIS). Usage strictement personnel, déploiement développeur uniquement.
