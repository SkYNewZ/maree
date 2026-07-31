# Préparation App Store — spec validée

Date : 2026-07-31 · Statut : validée (brainstorming)

Préparer Marée à une éventuelle soumission App Store, sans la déclencher. Trois
chantiers indépendants, ordre d'exécution : A → C → B.

## Chantier A — Configuration App Store

### PrivacyInfo.xcprivacy

Créer `Maree/Support/PrivacyInfo.xcprivacy` :

- `NSPrivacyTracking` : `false` ; `NSPrivacyTrackingDomains` : `[]` ;
  `NSPrivacyCollectedDataTypes` : `[]`.
- `NSPrivacyAccessedAPITypes` : une seule entrée —
  `NSPrivacyAccessedAPICategoryUserDefaults`, raison `CA92.1` (stockage des
  favoris via `UserDefaults`, seul usage d'API « required reason » des sources ;
  `fileSize` dans `ImageStore` n'en fait pas partie, GRDB embarque son propre
  manifeste).

Déclarer le fichier comme ressource du target `Maree` dans `project.yml`
(`buildPhase: resources`) : il doit finir **à la racine du bundle**.

### Clés Info.plist

- `ITSAppUsesNonExemptEncryption = NO` ajouté dans
  `Maree/Support/LaunchScreenInfo.plist` (le plist fusionné via
  `INFOPLIST_FILE`), **pas** en clé `INFOPLIST_KEY_` — ce toolchain ignore
  silencieusement les clés hors whitelist (piège déjà documenté dans CLAUDE.md).
- `MARKETING_VERSION: "1.0"` et `CURRENT_PROJECT_VERSION: 1` dans
  `settings.base` de `project.yml` ; la synthèse d'Info.plist les reprend en
  `CFBundleShortVersionString` / `CFBundleVersion`.

### Vérification

`xcodegen generate` + build simulateur, puis inspection du produit compilé :
`PrivacyInfo.xcprivacy` présent à la racine du bundle, et l'Info.plist compilé
contient les trois clés (`ITSAppUsesNonExemptEncryption`,
`CFBundleShortVersionString`, `CFBundleVersion`). La suite de tests reste verte.

## Chantier B — Page GitHub Pages (confidentialité + support)

### Hébergement

- Branche **`gh-pages` orpheline**, créée dans un worktree pour ne pas toucher
  `develop`. Contenu : `index.html` autonome + le logo.
- Activation Pages via `gh api` (source : branche `gh-pages`, racine) — les
  Actions du repo restent désactivées. URL : `https://skynewz.github.io/maree/`.
- Les deux URLs App Store Connect pointent sur cette page avec les ancres
  `#confidentialite` et `#support`.

### Contenu (français)

- **En-tête** : logo de l'app (icône `AppIcon-1024.png` redimensionnée, aussi
  utilisée comme favicon), nom « Marée », une ligne de description.
- **Confidentialité** (`#confidentialite`) : aucune collecte, aucun tracking,
  aucun compte, données (favoris, cache d'images) stockées uniquement sur
  l'appareil. Seule communication réseau : téléchargement des photos depuis
  notre hébergement d'images, qui voit transiter l'adresse IP comme tout
  serveur web. **Aucune mention de DORIS ni de la FFESSM.**
- **Support** (`#support`) : contact `quentin@lemairepro.fr` + issues GitHub.
- **Pied de page** : licence GPL-3.0, lien vers le repo.

### Design

- Sobre, même langage visuel que l'app : palette Paper/Ink/accent (valeurs hex
  reprises des Color Sets), clair/sombre via `prefers-color-scheme`.
- CSS inline, zéro dépendance externe, une seule page.
- Skills à mobiliser à l'implémentation : `frontend-design`,
  `ui-ux-pro-max:ui-ux-pro-max` et `ui-ux-pro-max:ui-styling` pour le design ;
  `humanizer` sur le texte final.

## Chantier C — Captures App Store 6,9″ habillées

### Captures brutes

- Simulateur **iPhone 17 Pro Max** (1320×2868 px, résolution 6,9″ exigée),
  via `/ios-simulator-skill`. Laisser les photos réseau se charger avant de
  capturer — jamais de placeholder visible.
- Cinq scènes : Rechercher avec résultats (saisie AZERTY compensée), fiche
  espèce (haut avec photo), Explorer (grille des groupes), galerie photos,
  Favoris remplis (créer les favoris au préalable).

### Habillage

- Template HTML/CSS unique : fond palette de l'app, titre français en haut,
  rappel discret du logo, capture dans un cadre d'iPhone sobre (rectangle
  arrondi CSS, pas d'image de bezel). Rendu PNG **1320×2868** via
  `playwright-cli`, cinq instances.
- Mêmes skills design que le chantier B.

### Livrables

`docs/appstore/` commité sur `develop` : les 5 PNG finaux + le template et les
captures brutes pour pouvoir régénérer.

## Hors périmètre

Pas de soumission, pas de compte Apple Developer, pas de démarche de droits
DORIS/FFESSM (bloquants identifiés dans l'audit, traités séparément), pas de
localisation anglaise.
