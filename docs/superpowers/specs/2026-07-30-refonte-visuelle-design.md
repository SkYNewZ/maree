# Refonte visuelle de Marée — « guide de terrain »

Statut : validé (brainstorming du 2026-07-30). Fait suite à la v1 fonctionnelle.

## 1. Problème

L'app v1 est fonctionnellement complète mais visuellement muette : listes de texte sur
blanc, fiche en longue colonne, Explorer en listes nues. Rien ne distingue un mollusque
d'une algue avant d'avoir lu, et l'app n'a ni icône propre ni écran de lancement.

## 2. Ce que la refonte change, et ce qu'elle ne change pas

**Purement présentation.** La structure de navigation, les 4 onglets, l'ordre des
sections, la couche données et le comportement hors ligne ne bougent pas. Aucune image
supplémentaire n'est chargée depuis le réseau.

## 3. Identité

- **Icône d'app** : celle de la PWA reprise telle quelle — carré arrondi bleu pétrole
  `#1F4D5C`, deux vagues (`#CFE1E3`, `#3D8A99`), silhouette de poisson. Source :
  `~/src/skynewz/doris-pwa/public/icons/icon.svg` (587 octets), à décliner aux tailles
  iOS. Une icône saturée se repère mieux sur l'écran d'accueil, et le bleu dit « mer ».
- **Écran de lancement** : fond papier crème avec le motif de vagues en terre cuite,
  pour entrer dans l'app sans rupture de palette. `LaunchScreen` statique, sans code.
- Le bleu pétrole du logo devient la **couleur d'accent** de l'app (liens, sélection),
  ce qui relie l'icône aux écrans sans imposer sa saturation partout.

## 4. Palette

| Rôle | Clair | Sombre |
|---|---|---|
| Fond de page | `#FBF7EF` | `#171410` |
| Surface (carte, ligne) | `#FFFDF8` | `#211D18` |
| Texte principal | `#2E2415` | `#F2EBDF` |
| Texte secondaire | `#7A6A50` | `#A99B84` |
| Filets | `#E3D9C6` | `#332C24` |
| Accent | `#1F4D5C` | `#7FB2C0` |
| Signal (réglementée, dangereuse) | `#C9762F` | `#E09A5A` |

**Contrainte ferme** : toute paire texte/fond tient le ratio AA (4,5:1). Le crème
réchauffe sans réduire le contraste — c'est ce qui autorise cette direction pour un
usage en plein soleil, au bord de l'eau.

Les couleurs `couleurGroupe` de DORIS sont **écartées** : les 177 valeurs sont
`hsv(teinte, 0.50, 0.75)` — saturation et valeur identiques, teinte attribuée par
position dans l'arbre. Les cinq racines, que l'utilisateur voit côte à côte, tombent
donc dans la même bande olive (`#BFA360`, `#BFA960`, `#ACBF60`, `#A6BF60`, `#BF9360`)
et sont indistinguables là où il faudrait distinguer.

## 5. Les 18 embranchements

Chaque groupe de niveau 2 reçoit une couleur et une icône ; les 160 groupes descendants
en héritent. Une table de 18 lignes, jamais 160.

| Embranchement | Espèces | Base (trait, filet) | Teinte (fond de pastille) | Icône |
|---|---|---|---|---|
| Mollusques | 597 | `#306E9B` | `#D9E7F1` | coquille de gastéropode en spirale |
| Vertébrés | 541 | `#303F9B` | `#D9DCF1` | poisson de profil |
| Arthropodes | 323 | `#57309B` | `#E2D9F1` | crevette |
| Éponges ou Spongiaires | 210 | `#8C309B` | `#EED9F1` | éponge tubulaire |
| Cnidaires | 205 | `#9B3074` | `#F1D9E8` | méduse |
| Vers | 151 | `#9B303F` | `#F1D9DC` | spirographe |
| Lophophorates | 150 | `#9B5730` | `#F1E2D9` | bryozoaire en éventail |
| Procordés | 145 | `#836D29` | `#F1EBD9` | ascidie |
| Échinodermes | 90 | `#697424` | `#EEF1D9` | oursin |
| Cténaires | 14 | `#437C27` | `#E1F1D9` | cténophore ovale strié |
| Animaux unicellulaires | 9 | `#287F4C` | `#D9F1E3` | foraminifère |
| Autres groupes mineurs | 5 | `#277C74` | `#D9F1EF` | trois points |
| Algues | 247 | `#277C5C` | `#D9F1E8` | fronde d'algue |
| Plantes à fleurs | 115 | `#517825` | `#E6F1D9` | posidonie en touffe |
| Diatomées et autre phytoplancton | 15 | `#2A7887` | `#D9EDF1` | diatomée hexagonale |
| Fougères aquatiques | 1 | `#287F34` | `#D9F1DC` | crosse de fougère |
| Champignons et Lichens | 9 | `#97632F` | `#F1E5D9` | lichen ramifié |
| Procaryotes | 8 | `#74309B` | `#E8D9F1` | bactérie en bâtonnet |

Toutes les bases tiennent AA sur le crème (4,6:1 au minimum). Les teintes sont espacées
de sorte que les groupes **affichés ensemble** soient distincts : les 12 enfants
d'ANIMAUX font le tour complet de la roue, et les 4 végétaux sont séparés (vert,
olive, bleu-vert, vert franc) au lieu de se confondre.

**Format des icônes** : SVG monochromes, trait uniforme, grille de 24 px, un fichier
par icône dans un catalogue d'assets, rendus en `Image(decorative:)` et teintés par
code. Pas de variante sombre : seule la teinte appliquée change. Les 18 dessins sont
**produits dans le cadre de ce chantier** — ils n'existent nulle part aujourd'hui.

**Où elles apparaissent** : pastille ronde dans les lignes d'Explorer, pastille dans
l'en-tête de fiche à côté du nom de groupe, et en filigrane large dans l'état vide d'un
groupe.

## 6. Écran par écran

- **Rechercher** — lignes plus aérées, vignette de 64 → 72 px à coin arrondi, pastille
  d'embranchement à droite. L'écran d'accueil vide passe du gris système à une
  illustration au trait sur le crème.
- **Explorer** — chaque ligne de groupe gagne sa pastille colorée ; le compteur
  d'espèces devient une puce discrète. C'est l'écran qui change le plus.
- **Fiche** — photo en bandeau plein cadre sans marge, filet coloré de 3 px sous
  l'en-tête à la couleur de l'embranchement, titres de sections en capitales espacées
  (`.textCase(.uppercase)` + `.tracking`, pas de fonte à petites capitales), chips de
  zones en terre cuite. **Le corps de texte ne bouge pas** : c'est ce qu'on vient lire.
- **Galerie** — inchangée, elle reste noire. Une visionneuse doit disparaître derrière
  l'image.
- **Favoris, Réglages** — héritent des surfaces et des filets, rien de spécifique.

## 7. Garde-fous

Ils empêchent une refonte de dégrader une app qui marche :

- Dynamic Type jusqu'à AX3 sans troncature ni chevauchement, vérifié à l'écran.
- Aucune information portée par la couleur seule : l'icône porte toujours le sens,
  ce qui protège les daltoniens.
- Tous les tests existants restent verts ; zéro avertissement compilateur.
- Le hors-ligne n'est pas touché.

## 8. Hors périmètre

- Toute modification de la navigation, de l'ordre des sections ou de la couche données.
- Icônes par espèce (2 837 dessins) ou par groupe au-delà du niveau 2 (héritage).
- Transitions et animations personnalisées.
- Réutilisation des illustrations `cleURLImage` de DORIS : leur chemin renvoie un 404,
  elles ne sont pas accessibles.

## 9. Risque assumé

La refonte touche 8 vues sur 10, et ces vues viennent de passer douze tours de revue.
Le risque est d'y réintroduire des défauts. Il est limité en ne touchant que
l'apparence — jamais la logique — et en repassant la vérification visuelle sur chaque
écran.

## 10. Préalable

Fait : les passes `/simplify` et `/ponytail-review` portaient sur ces mêmes fichiers de
vues et sont appliquées (commits `00d4f42`..`568a9d7`). La refonte part d'une base
stabilisée.
