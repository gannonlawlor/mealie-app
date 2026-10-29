# MealieUISnapshotTests

SwiftUI screenshot tests using [pointfreeco/swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing).
Each test renders a key screen with deterministic fixture state (see `Fixtures.swift`)
and compares it pixel-by-pixel (precision 0.99, perceptual precision 0.98) against a
golden image in `__Snapshots__/`.

## Environment

The original goldens were recorded on the **iPhone 17 Pro simulator**. Login and
Settings references were refreshed on iOS 27.0 (iPhone 18 Pro) for the Cookbook
branding and current version display. The views
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

- Preserve the affected reference files elsewhere, remove only those files, and
  run the affected tests twice — the first run records new goldens and fails
  (expected), the second run asserts against them; or
- Pass `record: true` to the selected `assertSnapshot` calls, run once, then remove
  recording mode and run again to verify. Do not broadly rebaseline unrelated OS
  rendering changes while accepting a narrow product change.

Always eyeball the new PNGs before committing them.
For failed runs, `-collect-test-diagnostics never` avoids lengthy simulator
diagnostic collection after the snapshot assertions have completed.

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
- Settings receives a fixed app-version fixture so it does not display the XCTest
  runner's bundle version in place of the product version.
