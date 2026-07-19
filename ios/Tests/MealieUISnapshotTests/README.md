# MealieUISnapshotTests

SwiftUI screenshot tests using [pointfreeco/swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing).
Each test renders a key screen with deterministic fixture state (see `Fixtures.swift`)
and compares it pixel-by-pixel (precision 0.99, perceptual precision 0.98) against a
golden image in `__Snapshots__/`.

## Environment

Goldens are recorded on the **iPhone 17 Pro simulator** (current iOS SDK). The views
are laid out at fixed device configs (`.iPhone13(.portrait)` for phone,
`.iPadPro11(.landscape)` for the iPad split-layout tests) in forced light mode
(plus one dark-mode variant of the recipe detail), so any simulator model can run
them — but the **OS version matters**: system fonts, bars, and controls change
between iOS releases, so re-record if you switch simulator runtimes.

## Running

```sh
cd ios
xcodebuild test -scheme mealie-app-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

This runs both `MealieModelTests` and `MealieUISnapshotTests`.

## Re-recording goldens

Either:

- Delete the `__Snapshots__/` folder and run the tests **twice** — the first run
  records new goldens and fails (expected), the second run asserts against them; or
- Set `isRecording = true` (or pass `record: true` to `assertSnapshot`) in
  `MealieUISnapshotTests.swift`, run once to overwrite the goldens, then remove it
  and run again to verify.

Always eyeball the new PNGs before committing them.

## Determinism notes

- ViewModels are constructed directly and populated with fixture state; `MealieAPI`
  is never configured, so any `.task` loader that does fire either exits early
  (data already present) or fails fast with an unsupported-URL error that leaves
  the pre-set state untouched. `AsyncImage` URLs are dead, so rows/heroes render
  their stable placeholder.
- `RecipeDetailView`'s `.task` unconditionally reloads `selectedRecipe` (which
  would blank the fixture), so those tests snapshot its `recipeContent(_:)`
  subview instead of the full screen. Consequence: the `@Environment(\.colorScheme)`
  read inside that subview resolves to the default (light) for the AdaptiveColors
  surface tiles even in the dark-mode variant; system colors still follow the trait.
- The meal-plan week is pinned to Mon 2025-03-10 (fully in the past) so the
  "today" highlight can never appear in a snapshot.
