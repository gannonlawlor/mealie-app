# JVM Screenshot Tests (Roborazzi + Robolectric)

Pixel-diff regression tests for the app's Compose screens. They run entirely on
the JVM — no emulator or device — using Robolectric native graphics to render
and [Roborazzi](https://github.com/takahirom/roborazzi) to record/compare PNGs.

Golden images live in `android/app/src/test/roborazzi/*.png` and are committed.

## Record vs verify

```sh
# Re-record goldens (do this after an intentional UI change; commit the PNGs)
./gradlew :app:recordRoborazziDebug

# Compare current rendering against the committed goldens (CI / pre-commit)
./gradlew :app:verifyRoborazziDebug

# On failure, diff/actual images are written under app/build/outputs/roborazzi
# and an HTML report under app/build/reports/roborazzi.
```

`./gradlew test` behavior:

- `testDebugUnitTest` **includes** the screenshot tests, but in plain test runs
  Roborazzi is inactive (no record/verify system properties), so they only
  assert that the screens compose without crashing — no images are written or
  compared. Image comparison only happens via the `*RoborazziDebug` tasks.
- `testReleaseUnitTest` **excludes** `**/screenshots/**` (configured in
  `app/build.gradle.kts`) because the `ComponentActivity` used by
  `createComposeRule()` comes from `androidx.compose.ui:ui-test-manifest`,
  which is a `debugImplementation` dependency. The 103 plain ViewModel/store
  tests still run in both variants.

The Roborazzi Gradle plugin registers `src/test/roborazzi` (set via the
`roborazzi.outputDir` extension) as a test-task input, so editing/corrupting a
golden correctly re-triggers and fails `verifyRoborazziDebug`.

## Device qualifiers

- Phone screens: `RobolectricDeviceQualifiers.Pixel7` (1078x2399 output)
- Wide-layout (tablet / unfolded foldable) screens:
  `RobolectricDeviceQualifiers.MediumTablet` (2560x1600 output) — used by
  `WideLayoutScreenshotTest` for `RecipesPane(isWideLayout = true)` and
  `ShoppingPane(isWideLayout = true)`

All classes use `@RunWith(RobolectricTestRunner::class)`,
`@GraphicsMode(GraphicsMode.Mode.NATIVE)` and `@Config(sdk = [35])`.

## Determinism rules

State is built through the **real ViewModels** using the same hand-rolled fakes
as the ViewModel unit tests (`FakeMealieApiSource`, `FakeLocalRecipeDao`,
`FakeKeyValueStore`, ... — see `ScreenshotEnv` in `ScreenshotTestSupport.kt`),
never by stubbing UI-level state. Keep these rules when adding tests:

1. **No network.** All data comes from the fakes. Recipe screens run in local
   mode so Coil resolves thumbnails/hero images to the deterministic
   placeholder icon instead of fetching URLs.
2. **Fixed dates only.** `MealPlanViewModel` takes an injectable `today`
   provider; it is pinned to `ScreenshotFixtures.weekStart` (Mon 2025-03-10).
   The week is deliberately in the past so `MealPlanScreen`'s own
   `LocalDate.now()` today-highlight can never match a rendered day,
   regardless of when the test runs.
3. **No random values** in anything that renders. Fixture ids/strings are
   hardcoded in `ScreenshotFixtures`. (`PendingGroceryItem` generates a random
   UUID id, but it is never displayed.)
4. **Forced theme.** Wrap content in `ScreenshotTheme { ... }` which applies
   `MealieTheme` with an explicit LIGHT (or DARK) preference plus an opaque
   `Surface`, so the host machine's appearance can't leak in. One dark
   variant exists: `RecipeDetail_dark`.
5. **Synchronous loads.** ViewModels are constructed with
   `Dispatchers.Unconfined` as their io dispatcher, so the fake-backed suspend
   loads inside `LaunchedEffect`s finish before the first captured frame — no
   sleeps, no idling hacks.

## Covered screens (goldens)

| Golden | Screen / state |
| --- | --- |
| `LoginScreen_serverSetup.png` | Server setup form with a saved server + typed URL |
| `LoginScreen_loginForm.png` | Login form after successful server validation |
| `RecipesPane_compact.png` | Phone recipe list, 3 fixture recipes with category/tag chips |
| `RecipeDetail_light.png` | Rich recipe: sectioned ingredients, instructions, nutrition, times |
| `RecipeDetail_dark.png` | Same recipe in dark theme |
| `MealPlan_week.png` | Pinned week (Mar 10-16, 2025) with recipe + note entries |
| `ShoppingListDetail_sections.png` | Pending Upload + To Buy + Completed sections |
| `Settings_localMode.png` | Settings in local mode |
| `RecipesPane_wide_selected.png` | Tablet two-pane recipes with a selected recipe |
| `ShoppingPane_wide_selected.png` | Tablet two-pane shopping with a selected list |
