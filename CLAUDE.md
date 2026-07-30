# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@.claude/rules/swift.md
@docs/PRD.md

## Projet

Marée : app iOS native SwiftUI de consultation hors-ligne des fiches DORIS/FFESSM.
Le PRD importé ci-dessus est la référence produit — le critère n°1 y est défini :
tout contenu doit être disponible hors ligne, sans condition.

État : phase de cadrage terminée (PRD validé). Le projet Xcode n'est pas encore
scaffoldé — mettre à jour ce fichier (commandes de build/test) dès qu'il existe.

## Commandes

- Build/test : via `xcodebuild -scheme Maree` une fois le projet créé ; utiliser
  `/ios-simulator-skill` pour build, lancement et pilotage du simulateur.
- Générer la base embarquée : `node tools/prepare-db.mjs` (écrit `Maree/Resources/maree.db`,
  ~19 Mo, non commité — obligatoire avant tout build). Vérifier : `node tools/verify-db.mjs`.
- Tests du pipeline : `node --test 'tools/lib/*.test.mjs'` (la forme répertoire
  `node --test tools/lib/` est cassée sur ce build Node 26.5).
- Publier les vignettes : `node tools/generate-thumbs.mjs` — à créer, voir PRD §3.2.

## Données DORIS — particularités

- Source : `~/src/skynewz/doris-pwa/DorisAndroid.db` (50 Mo, SQLite extrait de l'APK
  Android). **doris-pwa est en lecture seule, ne jamais y écrire.** Le schéma est
  documenté dans `doris-pwa/scripts/fetch-doris.js`, dont la logique de nettoyage
  (markup `{{…}}`, sections typées) est à réutiliser dans `tools/prepare-db`.
- `fiche._id` ≠ `fiche.numeroFiche` : les jointures internes utilisent `_id`, mais la
  clé publique (et les chemins d'images) est **`numeroFiche`**.
- Images : bucket public `https://s3.us-east-005.backblazeb2.com/doris-production`,
  chemins `images/{numeroFiche}/{n}.jpg` (indices alignés sur `photoFiche` trié par
  `_id`, vérifié) ; vignettes app sous `0_maree.jpg`. Ne pas modifier le contenu
  existant du bucket (la PWA déployée le consomme).
- Filtre Europe : zones `1,2,3,5` → 2 837 fiches. Les 15 titres de `sectionFiche`
  forment une enum fermée.

## Pièges

- Le dossier `Marée` est en NFD (accent) : **target, scheme et bundle id restent
  ASCII (`Maree`)**, `CFBundleDisplayName = Marée`. Toujours quoter les chemins.
- Free provisioning : profil 7 jours — dev au simulateur, l'iPhone n'est qu'une
  validation ponctuelle. Un seul bundle identifier (quota 10 App IDs / 7 jours).
  App Groups, push, CloudKit, widgets : indisponibles, ne pas en proposer.
