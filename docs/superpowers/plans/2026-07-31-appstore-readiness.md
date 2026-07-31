# App Store Readiness — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendre Marée soumissible à l'App Store : manifeste de confidentialité + clés Info.plist, captures 6,9″ habillées, page publique confidentialité/support sur GitHub Pages.

**Architecture:** Trois chantiers indépendants exécutés A → C → B. A et C se font sur une branche `feature/appstore-readiness` depuis `develop` (merge final `--no-ff`). B vit sur une branche `gh-pages` orpheline, poussée directement.

**Tech Stack:** XcodeGen, xcodebuild, simctl (iPhone 17 Pro Max), playwright-cli (rendu PNG), HTML/CSS statique, `gh` CLI (GitHub Pages).

**Spec:** `docs/superpowers/specs/2026-07-31-appstore-readiness-design.md`

## Global Constraints

- Chemins : le dossier repo `Marée` est en NFD — **toujours quoter les chemins**.
- Le `.xcodeproj` est généré : éditer `Maree/project.yml`, jamais le projet, puis `cd Maree && xcodegen generate`.
- Page publique et titres de captures : **français**, **aucune mention de DORIS ni de la FFESSM**.
- Palette (issue des Color Sets, clair / sombre) : Paper `#FBF7EF`/`#171410`, Ink `#2E2415`/`#F2EBDF`, InkSoft `#7A6A50`/`#A99B84`, Accent `#1F4D5C`/`#7FB2C0`, Surface `#FFFDF8`/`#211D18`, Rule `#E3D9C6`/`#332C24`, Signal `#C9762F`/`#E09A5A`.
- Captures finales : PNG **1320×2868 px** exactement (6,9″), format exigé par App Store Connect.
- Clavier simulateur en AZERTY : ne saisir que des textes aux lettres identiques QWERTY/AZERTY (« poulpe », « poisson ») et vérifier à l'écran ce qui s'est écrit.
- Design (Tasks 3 et 4) : invoquer `frontend-design:frontend-design`, `ui-ux-pro-max:ui-ux-pro-max` et `ui-ux-pro-max:ui-styling` avant d'écrire le HTML/CSS ; passer les textes finaux au skill `humanizer`.
- Commits : Conventional Commits, messages en anglais.

## File Structure

- `Maree/Support/PrivacyInfo.xcprivacy` — créé (Task 1), manifeste de confidentialité, bundlé à la racine de l'app.
- `Maree/Support/LaunchScreenInfo.plist` — modifié (Task 1), + `ITSAppUsesNonExemptEncryption`.
- `Maree/project.yml` — modifié (Task 1), versions + ressource manifeste.
- `docs/appstore/raw/0{1..5}-*.png` — créés (Task 2), captures brutes du simulateur.
- `docs/appstore/template/frame.html` — créé (Task 3), template d'habillage unique.
- `docs/appstore/final/0{1..5}-*.png` — créés (Task 3), les 5 PNG à téléverser.
- `docs/appstore/README.md` — créé (Task 6), valeurs App Store Connect.
- Branche `gh-pages` (orpheline) : `index.html`, `app-icon.png`, `favicon.png`, `.nojekyll` — créés (Task 4).

---

### Task 1: Chantier A — manifeste de confidentialité et clés Info.plist

**Files:**
- Create: `Maree/Support/PrivacyInfo.xcprivacy`
- Modify: `Maree/Support/LaunchScreenInfo.plist`
- Modify: `Maree/project.yml`

**Interfaces:**
- Consumes: rien.
- Produces: build versionné 1.0 (1) ; l'app bundle contient `PrivacyInfo.xcprivacy` à sa racine — les Tasks 2 et 6 buildent depuis cet état.

- [ ] **Step 1: Créer la branche de travail**

```bash
cd '/Users/quentin/src/skynewz/Marée'
git checkout develop && git pull --ff-only
git checkout -b feature/appstore-readiness
```

- [ ] **Step 2: Écrire le manifeste**

Créer `Maree/Support/PrivacyInfo.xcprivacy` :

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

(`CA92.1` = accès à `UserDefaults` limité aux données de l'app — les favoris. Seule API « required reason » des sources ; GRDB embarque son propre manifeste.)

- [ ] **Step 3: Ajouter la clé d'exemption chiffrement**

Dans `Maree/Support/LaunchScreenInfo.plist`, ajouter dans le `<dict>` racine, après le bloc `UILaunchScreen` :

```xml
	<key>ITSAppUsesNonExemptEncryption</key>
	<false/>
```

**Pas** de variante `INFOPLIST_KEY_` : ce toolchain ignore silencieusement les clés hors whitelist (piège documenté dans CLAUDE.md) ; le plist fusionné via `INFOPLIST_FILE` est le chemin garanti.

- [ ] **Step 4: Éditer project.yml**

Dans `settings.base` (niveau projet), ajouter :

```yaml
    MARKETING_VERSION: "1.0"
    CURRENT_PROJECT_VERSION: 1
```

Dans `targets.Maree.sources`, ajouter l'entrée :

```yaml
      - path: Support/PrivacyInfo.xcprivacy
        buildPhase: resources
```

- [ ] **Step 5: Régénérer et builder**

```bash
cd '/Users/quentin/src/skynewz/Marée/Maree' && xcodegen generate
xcodebuild build -scheme Maree \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath "$SCRATCH/dd"
```

(`$SCRATCH` = le scratchpad de session. Si `Maree/Resources/maree.db` manque : `node tools/prepare-db.mjs` d'abord.)

- [ ] **Step 6: Vérifier le bundle compilé**

```bash
APP="$SCRATCH/dd/Build/Products/Debug-iphonesimulator/Maree.app"
ls "$APP/PrivacyInfo.xcprivacy"
plutil -p "$APP/Info.plist" | rg 'ITSAppUsesNonExemptEncryption|CFBundleShortVersionString|CFBundleVersion'
```

Attendu : le manifeste existe à la racine du bundle ; `ITSAppUsesNonExemptEncryption => 0`, `CFBundleShortVersionString => "1.0"`, `CFBundleVersion => "1"`.

- [ ] **Step 7: Tests**

```bash
cd '/Users/quentin/src/skynewz/Marée/Maree'
xcodebuild test -scheme MareeTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Attendu : suite verte, aucune régression.

- [ ] **Step 8: Commit**

```bash
cd '/Users/quentin/src/skynewz/Marée'
git add Maree/Support/PrivacyInfo.xcprivacy Maree/Support/LaunchScreenInfo.plist Maree/project.yml
git commit -m 'build(app): add the privacy manifest, encryption exemption, and explicit version numbers'
```

---

### Task 2: Chantier C — captures brutes 6,9″

**Files:**
- Create: `docs/appstore/raw/01-rechercher.png` … `05-favoris.png`

**Interfaces:**
- Consumes: le build de la Task 1.
- Produces: 5 PNG **1320×2868** dans `docs/appstore/raw/`, nommés `01-rechercher.png`, `02-fiche.png`, `03-explorer.png`, `04-galerie.png`, `05-favoris.png` — consommés tels quels par la Task 3.

- [ ] **Step 1: Démarrer le simulateur iPhone 17 Pro Max**

Invoquer `/ios-simulator-skill` pour builder, installer et lancer l'app sur **iPhone 17 Pro Max** (résolution native 1320×2868). Récupérer l'UDID : `xcrun simctl list devices booted`.

- [ ] **Step 2: Barre de statut propre et apparence claire**

```bash
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl ui "$UDID" appearance light
```

- [ ] **Step 3: Préparer l'état de l'app**

Dans l'app (pilotage via le skill simulateur) :
1. Ouvrir 4 fiches d'espèces visuellement réussies (photo nette) et les mettre en favoris.
2. Laisser chaque photo se charger complètement — **jamais de placeholder visible sur une capture**.

- [ ] **Step 4: Capturer les 5 scènes**

Pour chaque scène : naviguer, attendre le chargement des images, puis
`xcrun simctl io "$UDID" screenshot 'docs/appstore/raw/<nom>.png'`.

1. `01-rechercher.png` — onglet Rechercher, requête « poulpe » saisie (lettres identiques AZERTY/QWERTY ; vérifier le texte affiché ; repli : « poisson »), liste de résultats visible.
2. `02-fiche.png` — une fiche espèce, haut de page avec photo pleine largeur et badge d'embranchement.
3. `03-explorer.png` — onglet Explorer, grille des groupes.
4. `04-galerie.png` — galerie photos d'une fiche riche en images.
5. `05-favoris.png` — onglet Favoris avec les 4 favoris de l'étape 3.

- [ ] **Step 5: Vérifier la résolution et remettre le simulateur d'équerre**

```bash
for f in docs/appstore/raw/*.png; do sips -g pixelWidth -g pixelHeight "$f"; done
xcrun simctl status_bar "$UDID" clear
```

Attendu : 5 fichiers, tous exactement 1320×2868.

- [ ] **Step 6: Commit**

```bash
git add docs/appstore/raw && git commit -m 'docs(appstore): capture the five raw 6.9-inch screenshots'
```

---

### Task 3: Chantier C — habillage des captures

**Files:**
- Create: `docs/appstore/template/frame.html`
- Create: `docs/appstore/final/01-rechercher.png` … `05-favoris.png`

**Interfaces:**
- Consumes: `docs/appstore/raw/*.png` (Task 2), logo `Maree/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`.
- Produces: 5 PNG finaux 1320×2868 dans `docs/appstore/final/`, prêts pour App Store Connect.

- [ ] **Step 1: Design**

Invoquer `frontend-design:frontend-design`, `ui-ux-pro-max:ui-ux-pro-max` et `ui-ux-pro-max:ui-styling` pour affiner la base ci-dessous : sobre, langage « guide de terrain » de l'app, palette des Global Constraints, apparence claire uniquement (fond Paper clair).

- [ ] **Step 2: Écrire le template**

Créer `docs/appstore/template/frame.html` — base à affiner par le design, paramétrée par l'URL (`?shot=…&title=…`) :

```html
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8">
<style>
  :root {
    --paper: #FBF7EF; --surface: #FFFDF8; --ink: #2E2415;
    --ink-soft: #7A6A50; --accent: #1F4D5C; --rule: #E3D9C6;
  }
  * { margin: 0; box-sizing: border-box; }
  body {
    width: 660px; height: 1434px; background: var(--paper);
    display: flex; flex-direction: column; align-items: center;
    font-family: ui-serif, "New York", Georgia, serif;
  }
  header { padding: 56px 48px 36px; text-align: center; }
  header img { width: 44px; border-radius: 10px; margin-bottom: 16px; }
  h1 { color: var(--ink); font-size: 38px; line-height: 1.2; font-weight: 600; max-width: 520px; }
  .device {
    border: 12px solid var(--ink); border-radius: 58px; overflow: hidden;
    background: var(--surface); box-shadow: 0 24px 60px rgb(46 36 21 / 0.18);
  }
  .device img { display: block; width: 486px; }
</style>
</head>
<body>
  <header>
    <img src="app-icon.png" alt="">
    <h1 id="title"></h1>
  </header>
  <div class="device"><img id="shot" alt=""></div>
  <script>
    const p = new URLSearchParams(location.search);
    document.getElementById('title').textContent = p.get('title');
    document.getElementById('shot').src = p.get('shot');
  </script>
</body>
</html>
```

Copier le logo à côté du template : `cp 'Maree/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png' docs/appstore/template/app-icon.png`.

- [ ] **Step 3: Rendre les 5 PNG**

Invoquer `playwright-cli` : pour chaque capture, ouvrir `file://…/frame.html?shot=../raw/<nom>.png&title=<titre>` avec **viewport 660×1434 et deviceScaleFactor 2**, screenshot pleine page vers `docs/appstore/final/<nom>.png`. Titres (à passer au `humanizer` si reformulés) :

1. `01-rechercher.png` — « La recherche instantanée, même sans réseau »
2. `02-fiche.png` — « Des fiches complètes et illustrées »
3. `03-explorer.png` — « Explorez les espèces par groupe »
4. `04-galerie.png` — « Les photos en pleine page »
5. `05-favoris.png` — « Vos espèces toujours à portée »

- [ ] **Step 4: Vérifier**

```bash
for f in docs/appstore/final/*.png; do sips -g pixelWidth -g pixelHeight "$f"; done
```

Attendu : 5 fichiers, exactement 1320×2868. Ouvrir chaque PNG (Read) et contrôler visuellement : titre lisible, capture nette dans le cadre, aucun placeholder d'image.

- [ ] **Step 5: Commit**

```bash
git add docs/appstore/template docs/appstore/final
git commit -m 'docs(appstore): frame the screenshots with the field-guide template'
```

---

### Task 4: Chantier B — page confidentialité/support sur gh-pages

**Files:**
- Create (branche `gh-pages`, orpheline) : `index.html`, `app-icon.png`, `favicon.png`, `.nojekyll`

**Interfaces:**
- Consumes: logo `AppIcon-1024.png` (copié depuis `develop` avant le switch de branche).
- Produces: branche `gh-pages` poussée sur `origin`, activée par la Task 5. Ancres stables : `#confidentialite`, `#support`.

- [ ] **Step 1: Créer la branche orpheline dans un worktree**

(`$SCRATCH` = le scratchpad de session, comme en Task 1.)

```bash
cd '/Users/quentin/src/skynewz/Marée'
sips -Z 320 'Maree/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png' --out "$SCRATCH/app-icon.png"
sips -Z 64  'Maree/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png' --out "$SCRATCH/favicon.png"
git worktree add --detach "$SCRATCH/gh-pages-wt"
cd "$SCRATCH/gh-pages-wt"
git checkout --orphan gh-pages
git rm -rf --quiet .
cp "$SCRATCH/app-icon.png" "$SCRATCH/favicon.png" .
touch .nojekyll
```

- [ ] **Step 2: Design et rédaction**

Invoquer `frontend-design:frontend-design`, `ui-ux-pro-max:ui-ux-pro-max` et `ui-ux-pro-max:ui-styling`, puis écrire `index.html` : page unique autonome (CSS inline, zéro requête externe), palette des Global Constraints avec clair/sombre via `prefers-color-scheme`, typographie sobre « guide de terrain ». Structure et copie de référence (passer le texte final au `humanizer`) :

- `<head>` : `<title>Marée — Confidentialité et support</title>`, favicon `favicon.png`, `meta viewport`, `meta description`.
- En-tête : `app-icon.png`, « Marée », « Guide d'identification des espèces sous-marines d'Europe, entièrement hors ligne. »
- `<section id="confidentialite">` « Confidentialité » :
  - « Marée ne collecte aucune donnée. Pas de compte, pas de statistiques d'usage, pas de traceur publicitaire. Vos favoris et le cache des photos restent sur votre appareil et n'en sortent jamais. »
  - « La seule communication réseau de l'app est le téléchargement des photos d'espèces depuis notre hébergement d'images. Comme pour tout serveur web, votre adresse IP transite lors de ces téléchargements ; nous ne l'enregistrons pas et ne la recoupons avec rien. Une fois les photos en cache, l'app fonctionne sans aucune connexion. »
- `<section id="support">` « Support » :
  - « Une question, un problème, une suggestion ? Écrivez à quentin@lemairepro.fr ou ouvrez un ticket sur GitHub. » (mailto + lien `https://github.com/SkYNewZ/maree/issues`)
- Pied de page : « Marée est un logiciel libre sous licence GPL-3.0 · Code source » (lien repo).

**Interdit sur cette page : toute mention de DORIS ou de la FFESSM.**

- [ ] **Step 3: Vérifier au navigateur**

Servir le dossier (`python3 -m http.server` dans le worktree) et vérifier via `playwright-cli` : rendu clair **et** sombre (capture des deux), ancres `#confidentialite` et `#support` fonctionnelles, aucune requête réseau externe, lisibilité mobile (viewport 390×844).

- [ ] **Step 4: Commit et push**

```bash
cd "$SCRATCH/gh-pages-wt"
git add -A
git commit -m 'docs: add the privacy and support page'
git push -u origin gh-pages
cd '/Users/quentin/src/skynewz/Marée'
git worktree remove "$SCRATCH/gh-pages-wt"
```

---

### Task 5: Chantier B — activation GitHub Pages

**Files:** aucun (opérations `gh` uniquement).

**Interfaces:**
- Consumes: branche `gh-pages` sur `origin` (Task 4).
- Produces: `https://skynewz.github.io/maree/` en ligne — URL consommée par la Task 6.

- [ ] **Step 1: Réactiver les Actions (prérequis Pages)**

Le déploiement Pages depuis une branche passe par le workflow interne GitHub « pages build and deployment » ; les Actions du repo sont actuellement désactivées (`enabled: false`, vérifié). Le repo ne contient aucun fichier de workflow : réactiver n'exécute rien d'autre.

```bash
gh api -X PUT repos/SkYNewZ/maree/actions/permissions -F enabled=true -f allowed_actions=all
```

- [ ] **Step 2: Créer le site Pages**

```bash
gh api -X POST repos/SkYNewZ/maree/pages -f 'source[branch]=gh-pages' -f 'source[path]=/'
```

(Si le site existe déjà : `-X PUT` sur la même route pour pointer la source.)

- [ ] **Step 3: Attendre le déploiement et vérifier**

```bash
for i in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w '%{http_code}' https://skynewz.github.io/maree/)
  [ "$code" = 200 ] && break
  sleep 10
done
curl -s https://skynewz.github.io/maree/ | rg -c 'id="confidentialite"|id="support"'
```

Attendu : HTTP 200 et les deux ancres présentes (compte ≥ 2). Ouvrir ensuite l'URL publique via `playwright-cli` et confirmer le rendu (clair + sombre).

---

### Task 6: Finalisation — README App Store Connect, revue, merge

**Files:**
- Create: `docs/appstore/README.md`

**Interfaces:**
- Consumes: URL publique (Task 5), captures finales (Task 3).
- Produces: `develop` à jour, tout mergé `--no-ff`.

- [ ] **Step 1: Écrire le README**

Créer `docs/appstore/README.md` :

```markdown
# App Store Connect — valeurs préparées

- **URL confidentialité** : https://skynewz.github.io/maree/#confidentialite
- **URL support** : https://skynewz.github.io/maree/#support
- **Version** : 1.0 (build 1) — `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` dans `Maree/project.yml`
- **Chiffrement** : `ITSAppUsesNonExemptEncryption = NO` (HTTPS uniquement)
- **Manifeste** : `Maree/Support/PrivacyInfo.xcprivacy` — aucune collecte, UserDefaults `CA92.1`
- **Captures 6,9″** : `final/01-rechercher.png` … `final/05-favoris.png` (1320×2868)
- **Régénérer une capture** : refaire la brute (voir plan, Task 2) puis rendre
  `template/frame.html?shot=…&title=…` en 660×1434 @2x via playwright.

Restent hors de ce dépôt : compte Apple Developer (99 €/an), autorisation
écrite du détenteur des droits sur les contenus, fiche App Store (description,
mots-clés, catégorie, classification d'âge, statut DSA non-commerçant).
```

```bash
git add docs/appstore/README.md
git commit -m 'docs(appstore): record the App Store Connect values'
```

- [ ] **Step 2: Revue de fin de tâche**

Invoquer `/simplify` puis `/ponytail:ponytail-review` sur la branche ; appliquer les ajustements nécessaires et les committer.

- [ ] **Step 3: Merge gitflow**

```bash
cd '/Users/quentin/src/skynewz/Marée'
git checkout develop
git merge --no-ff feature/appstore-readiness -m 'feat: prepare the App Store submission assets'
git branch -d feature/appstore-readiness
git push origin develop
```
