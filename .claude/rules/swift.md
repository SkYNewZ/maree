# Règles Swift / SwiftUI

Sources : guide claude-code-ios-dev-guide (keskinonur) + Apple Swift API Design Guidelines,
adaptées au projet (voir arbitrage tests en fin de fichier).

## Style Swift

- Swift 6, concurrence stricte. *Approachable Concurrency* / *Default Actor
  Isolation = MainActor* activés dans les build settings : app mono-utilisateur, cela
  supprime l'essentiel du bruit de concurrence sans rien coûter.
- `@Observable` plutôt que `ObservableObject`. `async/await` partout, jamais de
  completion handlers.
- `guard` pour les sorties anticipées. Types valeur (`struct`) par défaut.
- Erreurs typées via `LocalizedError`, jamais de `catch` muet.
- Nommage : Apple API Design Guidelines (clarté au point d'appel, pas d'abréviations).

## SwiftUI

- Extraire une vue dès qu'elle dépasse ~100 lignes.
- `@State` pour l'état local uniquement, `@Environment` pour l'injection de
  dépendances, `@Bindable` pour se lier à un `@Observable`.
- `NavigationStack` avec routage typé (`enum Route: Hashable`), jamais `NavigationView`.

## Interdits

- Force unwrapping (`!`) sans justification écrite en commentaire.
- Vues monolithiques, APIs dépréciées, UIKit là où SwiftUI suffit.
- Ignorer un avertissement de concurrence Swift 6.

## Tests

- Framework : **Swift Testing** (`@Test` / `#expect`), pas XCTest.
- Cible : la logique métier — requêtes DB, recherche, filtres, parsing. Un test
  exécutable par logique non triviale, pas une suite par fonction.
- Pas de quota de couverture (le « 80 % » du guide est écarté : il contredit le mode
  ponytail global). Pas de tests UI pendant le scaffolding.
