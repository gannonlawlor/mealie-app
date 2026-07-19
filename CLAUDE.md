# Mealie App

Mobile clients for [Mealie.io](https://mealie.io) (self-hosted recipe manager): a **native iOS
app** (Swift/SwiftUI) and a **native Android app** (Kotlin, Jetpack Compose, MVVM) in one repo.
(Formerly a single Skip Fuse codebase — see `docs/ANALYSIS.md` for the rewrite rationale and
the feature parity checklist. `main` prior to the `native-rewrite` merge holds the Skip version.)

## Project Structure

```
ios/
  Package.swift        # SPM package: MealieApp, MealieUI, MealieModel (+ MealieModelTests)
  Sources/
    MealieApp/         # App entry point, RootView
    MealieModel/       # API client, Codable models, @Observable ViewModels, stores
      API/             # MealieAPI (URLSession), AuthService, sync/offline/cache stores,
                       # RecipeURLParser (JSON-LD), SwiftData local store
      Models/          # Auth, Recipe, MealPlan, ShoppingList, User, paginated responses
      ViewModels/      # Auth/Recipe/MealPlan/Shopping ViewModels (@MainActor @Observable)
    MealieUI/          # All SwiftUI views (iPhone tabs + iPad sidebar/split layouts)
  Tests/MealieModelTests
  Darwin/              # Xcode project (MealieApp.xcodeproj), assets, Info.plist, ShareExtension
android/
  app/src/main/java/com/jackabee/mealie/
    data/              # model (kotlinx.serialization), api (Retrofit + auth interceptor),
                       # auth, settings, store (sync/offline/cache/Room local), parser (JSON-LD),
                       # repository
    di/                # AppContainer (manual DI), MealieApplication
    ui/                # theme, navigation, viewmodel (StateFlow UiState), screens/<feature>
  app/src/test/        # JUnit unit tests (no mocking framework; hand-rolled fakes)
docs/                  # ANALYSIS.md (feature inventory), UI_SPECS.md (screen behavior specs)
scripts/               # release.sh (iOS TestFlight)
```

## Build Commands

```sh
# iOS build
xcodebuild -project ios/Darwin/MealieApp.xcodeproj -scheme "MealieApp App" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# iOS unit tests (swift test does NOT work — MealieUI needs UIKit)
cd ios && xcodebuild test -scheme mealie-app-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Android build + unit tests
cd android && ./gradlew assembleDebug test
```

Android needs `android/local.properties` with `sdk.dir=$HOME/Library/Android/sdk`
(gitignored; SDK platform 35 + build-tools 35.0.0).

## Architecture Rules

Both apps implement the same feature set (parity checklist in `docs/ANALYSIS.md`). When adding
a feature, add it to both, and keep user-facing strings consistent across platforms.

- **iOS**: `@MainActor @Observable` ViewModels in MealieModel; views in MealieUI; singletons
  (`MealieAPI.shared`, `AuthService.shared`, …). iPad uses a custom sidebar + two-pane split
  layouts keyed off `horizontalSizeClass`.
- **Android**: MVVM — `ViewModel` + `StateFlow<UiState>` (one UiState data class per VM),
  constructor-injected deps from `AppContainer`, screens read state via
  `collectAsStateWithLifecycle`. Adaptive layout: `NavigationSuiteScaffold` (bottom bar ↔ rail)
  and `isWideLayout` two-pane modes in Recipes/Shopping for foldables/tablets.
- Unit tests accompany logic changes on both platforms: XCTest (iOS, run on simulator),
  JUnit + kotlinx-coroutines-test with hand-rolled fakes (Android, plain JVM — no Robolectric).

## Mealie API (v2) — casing quirks matter

- **Auth**: `POST /api/auth/token` (form-encoded) → snake_case (`access_token`, `token_type`)
- **Everything else** uses **camelCase** JSON keys — do NOT add snake_case mappings
- **Exceptions**: pagination `per_page`/`total_pages`, meal-plan query params
  `start_date`/`end_date` are snake_case; `MealPlanEntry.id` is **Int**;
  `RecipeSettings.public` → `isPublic`
- Shopping item update: `PUT /api/households/shopping/items` with a **list** body;
  delete body is `[{"itemId": id}]`; create-recipe endpoints return a bare JSON string (slug)
- Images: `GET /api/media/recipes/{id}/images/{tiny-original.webp|min-original.webp}`
- 401 handling: refresh token → re-login with saved credentials → retry once → soft logout

## Key Config Values

- Bundle ID (iOS) / Application ID (Android): `com.jackabee.mealie`
- Version: `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` in `ios/Darwin/MealieApp.xcconfig`
  and `versionName`/`versionCode` in `android/app/build.gradle.kts` — bump BOTH together
- Xcode scheme: `"MealieApp App"`; Android root project: `mealie-android`, module `:app`

## Error Handling

All network errors must be logged with details. Never silently swallow errors — at minimum log
them even if the UI shows a generic message. Both platforms surface a dismissible error banner
with a debug-only expandable detail line.
