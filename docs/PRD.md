# PRD : Marée v1 — consultation hors-ligne des fiches DORIS

Statut : validé (brainstorming du 2026-07-30). Portage natif iOS de la PWA doris-pwa.

## 1. Introduction

Marée est une app iOS native (SwiftUI) de consultation des fiches espèces sous-marines
DORIS/FFESSM. Elle remplace une PWA dont iOS purge le stockage après ~7 jours sans
ouverture — précisément le scénario d'usage réel : *« j'ouvre l'app au bord de l'eau,
sans réseau, trois semaines après ma dernière plongée »*.

**Critère d'arbitrage n°1 de toute décision : le contenu doit être disponible hors
ligne, sans condition.** Une fonctionnalité qui exige le réseau au moment de la plongée
est hors sujet.

Second objectif, assumé : servir de support d'apprentissage du développement iOS au
propriétaire. Le coût d'apprentissage du natif est un but, pas un effet de bord.

## 2. Objectifs

- 100 % du texte des fiches consultable hors ligne, immédiatement après installation.
- Une vignette par fiche disponible hors ligne après le premier lancement (pack ≈ 43 Mo).
- Recherche instantanée (nom commun, scientifique, autres dénominations, accents ignorés).
- Navigation par groupes taxonomiques et par zones géographiques.
- Favoris et « préparer une sortie » (préchargement explicite de photos plein format).
- App simple, lisible, utilisable de 7 à 77 ans.

## 3. Données

### 3.1 Couverture

Sous-ensemble **Europe** de la base DORIS : zones 1 (côtes françaises), 2 (Atlantique NE),
3 (Méditerranée), 5 (Atlantique NO) → **2 837 fiches** (sur 5 437), ~22 400 photos.

### 3.2 Pipeline de préparation (`tools/`, exécuté sur le Mac, rejoué à chaque MAJ DORIS)

1. **`prepare-db`** (Node, logique de nettoyage reprise de `fetch-doris.js` de la PWA) :
   lit `DorisAndroid.db` (50 Mo, extrait de l'APK Android), produit **`maree.db`**
   (~28 Mo, mesuré) :
   - filtrage zones 1/2/3/5 ;
   - markup DORIS `{{…}}` et HTML nettoyés une fois pour toutes ;
   - sections typées — les 15 titres de rubriques constituent une enum fermée ;
   - clé publique = `numeroFiche` (alignée avec les chemins d'images du bucket, vérifié) ;
   - table **FTS5** précalculée (nom commun, nom scientifique, autres dénominations ;
     `unicode61 remove_diacritics 2`) ;
   - tables conservées : fiches, sections, photos (titres/légendes), groupes (arbre,
     176 nœuds), zones, classification, dénominations ;
   - auto-vérification en fin d'exécution (comptages, absence de `{{` résiduel, FTS peuplée).
2. **`generate-thumbs`** : télécharge la première photo de chaque fiche, réduit à
   **400 px, HEIC qualité 50** (15 Ko de moyenne, mesuré sur 39 échantillons), publie
   dans le bucket sous `images/{numeroFiche}/0_maree.heic` → pack ≈ **43 Mo**.
   Idempotent (skip si présent).

### 3.3 Sources à l'exécution

- **Base** : `maree.db` embarquée dans le bundle, lecture seule via GRDB. Aucune mise à
  jour de données à l'exécution : MAJ DORIS = re-jouer le pipeline + rebuild (cohérent
  avec le redéploiement hebdomadaire imposé par le profil gratuit).
- **Images** : bucket public Backblaze `https://s3.us-east-005.backblazeb2.com/doris-production`.
  Chemins déductibles de la base : `images/{numeroFiche}/{n}.jpg` (plein format, indices
  alignés sur `photoFiche`, vérifié) et `0_maree.heic` (vignette). Les JSON du bucket ne
  sont pas utilisés.

## 4. User stories

### US-001 : Pipeline `prepare-db`
**Description :** En tant que mainteneur, je veux générer `maree.db` depuis
`DorisAndroid.db` pour embarquer une base propre, réduite et indexée.

**Critères d'acceptation :**
- [ ] `maree.db` contient 2 837 fiches, leurs sections/photos/dénominations/classification, l'arbre des groupes et les zones
- [ ] Aucun `{{` ni balise HTML résiduels dans les textes
- [ ] FTS5 peuplée ; « elephant » trouve « éléphant », recherche par préfixe fonctionnelle
- [ ] Auto-vérification du script passe (exit ≠ 0 sinon)

### US-002 : Pipeline `generate-thumbs`
**Description :** En tant que mainteneur, je veux publier une vignette réduite par fiche
dans le bucket pour que le pack hors-ligne initial reste léger (≈ 43 Mo).

**Critères d'acceptation :**
- [ ] 2 837 vignettes 400 px HEIC q50 publiées sous `images/{numeroFiche}/0_maree.heic`
- [ ] Poids moyen ≤ 20 Ko (15 Ko mesuré) ; re-exécution = 0 upload (idempotence)

### US-003 : Projet Xcode + couche base
**Description :** En tant que développeur, je veux un projet `Maree` (iOS 26, Swift 6,
GRDB) lisant `maree.db` pour bâtir toutes les vues dessus.

**Critères d'acceptation :**
- [ ] Target/scheme ASCII `Maree`, `CFBundleDisplayName = Marée`
- [ ] Build sans avertissement de concurrence Swift 6
- [ ] Structs records + requêtes : recherche FTS (classement bm25), arbre des groupes, fiches par groupe/zone, détail complet
- [ ] Tests Swift Testing : recherche (accents, préfixe, nom scientifique), sections d'une fiche dans l'ordre, comptages attendus

### US-004 : Onglet Rechercher
**Description :** En tant qu'utilisateur, je veux chercher une espèce par n'importe quel
nom et voir les résultats instantanément.

**Critères d'acceptation :**
- [ ] Résultats à la frappe (vignette, nom commun, nom scientifique)
- [ ] Insensible aux accents et à la casse, préfixes acceptés
- [ ] État vide informatif ; aucune requête réseau nécessaire
- [ ] Vérifié au simulateur (ios-simulator-skill)

### US-005 : Onglet Explorer
**Description :** En tant qu'utilisateur, je veux feuilleter par groupe taxonomique ou
par zone pour identifier une espèce que je ne sais pas nommer.

**Critères d'acceptation :**
- [ ] Drill-down dans l'arbre des groupes (176 nœuds, compteurs d'espèces) ; feuille → liste d'espèces
- [ ] Entrée par zone géographique → liste d'espèces
- [ ] Routage typé `enum Route: Hashable` dans une `NavigationStack` par onglet
- [ ] Vérifié au simulateur (ios-simulator-skill)

### US-006 : Fiche détail
**Description :** En tant qu'utilisateur, je veux une fiche complète et lisible pour
identifier et comprendre l'espèce.

**Critères d'acceptation :**
- [ ] Photo principale, badges (groupe, statut, réglementée/dangereuse), nom commun + scientifique
- [ ] Sections dans l'ordre : critères de reconnaissance, distribution + chips de zones, biotope (profondeur/température), description, biologie, noms & origines, espèces ressemblantes, classification, galerie
- [ ] `ShareLink` vers l'URL doris.ffessm.fr ; bloc attribution FFESSM en pied
- [ ] Entièrement consultable hors ligne (images absentes → placeholder discret)
- [ ] Vérifié au simulateur (ios-simulator-skill)

### US-007 : Galerie
**Description :** En tant qu'utilisateur, je veux feuilleter toutes les photos d'une
fiche en plein écran.

**Critères d'acceptation :**
- [ ] Grille dans la fiche → visionneuse plein écran, balayage entre photos, zoom par pincement
- [ ] Légendes affichées quand présentes
- [ ] Vérifié au simulateur (ios-simulator-skill)

### US-008 : Favoris
**Description :** En tant qu'utilisateur, je veux marquer des espèces pour les retrouver
avant/pendant une sortie.

**Critères d'acceptation :**
- [ ] Toggle depuis la fiche ; onglet Favoris = même liste que les résultats, filtrée
- [ ] Persistance `UserDefaults`, survit au relancement
- [ ] Vérifié au simulateur (ios-simulator-skill)

### US-009 : Pack vignettes + cache images
**Description :** En tant qu'utilisateur, je veux que les vignettes se téléchargent
seules au premier lancement pour que les listes fonctionnent hors ligne sans action de
ma part.

**Critères d'acceptation :**
- [ ] Téléchargement auto du pack (≈ 43 Mo) au premier lancement, app utilisable pendant
- [ ] Progression visible dans Réglages ; reprise après interruption (les fichiers présents ne sont pas retéléchargés)
- [ ] Cache disque dans Application Support (jamais purgé par iOS ni par l'app)
- [ ] Photos plein format chargées à la demande puis conservées
- [ ] Vérifié au simulateur (ios-simulator-skill), y compris en mode avion

### US-010 : Préparer une sortie
**Description :** En tant qu'utilisateur, je veux précharger les photos plein format de
mes favoris et/ou d'un groupe ou d'une zone avant de partir plonger.

**Critères d'acceptation :**
- [ ] Sélection favoris / groupe / zone, estimation de poids avant lancement
- [ ] Progression et annulation ; erreurs réseau visibles avec retry
- [ ] Vérifié au simulateur (ios-simulator-skill)

### US-011 : Réglages
**Description :** En tant qu'utilisateur, je veux voir l'état du hors-ligne et les
informations de l'app.

**Critères d'acceptation :**
- [ ] État du pack vignettes, stockage utilisé, accès « préparer une sortie »
- [ ] À propos : attribution DORIS/FFESSM, version de l'app et date de la base
- [ ] Vérifié au simulateur (ios-simulator-skill)

## 5. Exigences fonctionnelles

- FR-1 : toute consultation (recherche, exploration, fiche, favoris) fonctionne sans réseau.
- FR-2 : la recherche interroge FTS5 (bm25) sur nom commun, nom scientifique et autres dénominations, diacritiques ignorés.
- FR-3 : les images proviennent exclusivement du bucket ; toute image affichée est écrite dans un cache disque persistant avant affichage.
- FR-4 : une image indisponible affiche un placeholder — jamais de spinner infini ni d'erreur bloquante.
- FR-5 : base illisible au démarrage = arrêt avec message clair (défaut de build, pas un cas utilisateur).
- FR-6 : erreurs typées `LocalizedError` ; aucun `catch` muet.
- FR-7 : les téléchargements explicites (pack, sortie) affichent progression, reprise/annulation et erreurs avec retry.

## 6. Hors périmètre (v1)

- Historique de consultation, filtres avancés (statut, réglementées), modes d'affichage multiples.
- Spotlight/CoreSpotlight, glossaire, bibliographie, carnet d'observations, appareil photo, géolocalisation.
- Widget et notifications push (impossibles en free provisioning), CloudKit, App Groups.
- Publication App Store ; iPad ; paysage ; autre langue que le français.
- Mise à jour des données à l'exécution (la base vit dans le bundle).
- Écriture dans doris-pwa (lecture seule) ou modification du contenu existant du bucket.

## 7. Design

- Simple, lisible, sobre — pas de densité d'information. Public 7–77 ans.
- Design entièrement neuf, aucune contrainte héritée de la PWA.
- Dynamic Type et VoiceOver de base respectés (labels, tailles relatives).
- Conception avec `/frontend-design` et `/ui-ux-pro-max` le moment venu.

## 8. Contraintes techniques

- iOS 26.0 minimum, iPhone uniquement, Swift 6 (concurrence stricte,
  *Default Actor Isolation = MainActor*), SwiftUI pur, dépendance unique GRDB (SPM).
- Free provisioning : profil 7 jours (dev au simulateur, déploiement iPhone ponctuel),
  3 apps max par appareil, 10 App IDs / 7 jours — un seul bundle identifier.
- Dossier `Marée` en NFD : target/scheme restent ASCII (`Maree`).
- Données FFESSM : usage personnel, déploiement développeur uniquement.

## 9. Critères de succès

- Mode avion, installation fraîche + premier lancement terminé : recherche, exploration
  et toute fiche (texte + vignette) fonctionnent.
- Trois semaines sans ouvrir l'app : rien n'a été purgé, tout fonctionne encore.
- Recherche perçue comme instantanée (< 100 ms sur 2 837 fiches).
- « Préparer une sortie » sur un groupe : toutes ses photos consultables hors ligne.

## 10. Questions ouvertes

- Ordre de tri par défaut des listes (nom commun vs `numeroFiche`) — à trancher à la première maquette.
- Faut-il précharger les vignettes des photos secondaires dans « préparer une sortie » ou seulement le plein format ? (par défaut : plein format seul)
