# App Store Connect — valeurs préparées

- **URL confidentialité** : https://skynewz.github.io/maree/#confidentialite
- **URL support** : https://skynewz.github.io/maree/#support
- **Version** : 1.0 (build 1) — `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` dans `Maree/project.yml`
- **Chiffrement** : `ITSAppUsesNonExemptEncryption = NO` (HTTPS uniquement)
- **Manifeste** : `Maree/Support/PrivacyInfo.xcprivacy` — aucune collecte, UserDefaults `CA92.1`
- **Captures 6,9″** : `final/01-rechercher.png` … `final/05-favoris.png` (1320×2868)
- **Régénérer une capture** : refaire la brute (voir plan, Task 2) puis relancer
  `template/render.js` — sa procédure exacte est en tête du fichier, et
  `&plate=<nom>` limite le rendu à une seule planche.

Restent hors de ce dépôt : compte Apple Developer (99 €/an), autorisation
écrite du détenteur des droits sur les contenus, fiche App Store (description,
mots-clés, catégorie, classification d'âge, statut DSA non-commerçant).
