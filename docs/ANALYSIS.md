# Mealie App — Native Rewrite Analysis

_Written 2026-07-18 on branch `native-rewrite`. This documents the state of the app as of the
Skip Fuse version (v1.1.16, build 19) and the plan for splitting it into two fully native apps
in a single repo._

## Why

The app was built with [Skip Fuse](https://skip.tools): one Swift/SwiftUI codebase compiled
natively for iOS and bridged/compiled for Android. That bought fast dual-platform iteration but
imposed a long list of API constraints (no `NavigationSplitView`, no `.swipeActions()` on
Android, no generic bridging, `skip.yml` plumbing, a Gradle build bolted onto xcodebuild, etc.)
and made the Android app feel like a translated iOS app rather than a Material one.

Goal: **one repo, two native apps** —

- `ios/` — the existing Swift/SwiftUI app, with Skip stripped out (full SwiftUI available again).
  iPhone + iPad (sidebar/split layouts).
- `android/` — a new Kotlin app: MVVM, Jetpack Compose, Material 3, adaptive layouts for
  phones, foldables, and tablets.

Both apps must compile, keep the current feature set, and carry unit tests.

## Feature inventory (parity checklist)

### Modes
- **Server mode**: connect to a self-hosted Mealie v2 server.
- **Local mode**: no server; recipes live on-device (SwiftData on iOS / Room on Android).
  Local mode hides Meal Plan + Shopping tabs.

### Auth (server mode)
- Server URL validation via `GET /api/app/about` (auto-prefix `https://`).
- Login `POST /api/auth/token` (form-encoded, snake_case response) → JWT bearer.
- Token refresh `GET /api/auth/refresh`; on failure, silent re-login with saved credentials;
  on persistent 401 → soft logout (keeps server URL + email prefilled).
- Saved servers list (max 5, most recent first) for quick re-connect.
- Session persisted (URL, token, userId, email, password).

### Recipes
- Paginated list (30/page, `orderBy=created_at desc`), pull-to-refresh, infinite scroll.
- Debounced search (300 ms). In synced/local modes search also matches **ingredients**,
  description, and shows matching-tag chips.
- Category & tag filters; favorites filter toggle.
- Favorites: server (`/api/users/{id}/favorites/{slug}`, optimistic update) or local store.
- Recipe detail: image, yield/times, expandable description, ingredients (long-press to add
  one to a shopping list), instructions with section titles, nutrition.
- Edit recipe (name, description, yield, times, ingredients, instructions), delete with confirm.
- Import from URL: server mode → `POST /api/recipes/create/url`; local mode → on-device
  **JSON-LD (schema.org) parser** with duplicate detection (by `orgURL`, then by name) offering
  Update Existing / Import Anyway / Cancel.
- Create blank local recipe → straight into editor.
- Image upload (multipart PUT), image cache (list thumbnails `tiny-original.webp`, detail
  `min-original.webp`), offline save (full recipe JSON + image) with badge in list.
- **Recipe sync** (server mode): background full sync of every recipe to disk, incremental by
  `dateUpdated`, 5-at-a-time detail fetches; list/search/detail read from the sync store first,
  API as fallback.

### Meal plans (server mode)
- Week view starting today; previous/next week, "today" jump; grouped by date;
  entry types breakfast/lunch/dinner/side ("Snack").
- Add entry (with or without recipe; from meal-plan tab or recipe detail), delete entry.
- Week data cached for instant display.

### Shopping (server mode)
- Lists: create, delete, unchecked-count badges.
- List detail: add item, check/uncheck, delete, cached for offline viewing.
- Add all recipe ingredients to a list (`POST .../lists/{id}/recipe/{recipeId}`).
- Single-ingredient add via long-press with list picker; optional **default list** skips picker.
- **Local queue mode** ("Queue Items Locally"): items buffer on-device per list, sync later
  with progress message.
- iOS-only: also add to Reminders grocery list (EventKit).

### Settings
- Theme system/light/dark; keep screen awake (recipe detail); default shopping list;
  local queue toggle; profile + server info + synced-recipe count; sign out / connect to server;
  local-mode recipe count. iOS-only: Reminders toggle, iCloud sync (SwiftData + CloudKit).

### Platform integration
- iOS: Share extension → App Group `pendingImportURL` → imported on foreground;
  `mealie://import?url=` deep link.
- Android: `ACTION_SEND` (text/plain) and `ACTION_VIEW` (http/https) → import.

## API quirks worth preserving

- Auth token response is **snake_case** (`access_token`); everything else is **camelCase** —
  except pagination fields `per_page`/`total_pages` and meal-plan query params
  `start_date`/`end_date`, which are snake_case.
- `MealPlanEntry.id` is **Int**; every other id is a String/UUID.
- `RecipeSettings.public` maps to `isPublic`.
- Shopping item update is `PUT /api/households/shopping/items` with a **list** body;
  delete takes body `[{"itemId": id}]`.
- Create-recipe endpoints return a bare JSON string (the slug).
- All model fields must tolerate missing/null keys.

## Target architecture

```
mealie-app/
├── ios/                    # Swift/SwiftUI, SPM package + Xcode project
│   ├── Package.swift       # MealieApp / MealieUI / MealieModel targets (no Skip)
│   ├── Sources/…           # unchanged layering: Model (API+stores+VMs), UI, App
│   ├── Tests/MealieModelTests
│   └── Darwin/             # Xcode project, assets, ShareExtension
├── android/                # Kotlin, single :app module
│   └── app/src/main/java/com/jackabee/mealie/
│       ├── data/ (model, api, auth, settings, store, parser, repository)
│       ├── di/   (manual AppContainer)
│       └── ui/   (theme, navigation, screens/<feature>, viewmodels)
│   └── app/src/test/       # JUnit unit tests
└── docs/ANALYSIS.md
```

Android choices: Retrofit + OkHttp + kotlinx.serialization, Coil, Room (local recipes),
DataStore/SharedPreferences (settings/auth), manual DI (no Hilt — app is small), ViewModel +
StateFlow, Navigation Compose. Foldables/tablets via `WindowSizeClass`:
`NavigationSuiteScaffold` (bottom bar ↔ rail) and `ListDetailPaneScaffold` for
Recipes/Shopping two-pane layouts — the Compose analogue of the iPad split views.

## Known debts carried over (not fixed in this pass)

- Password stored in plain UserDefaults/SharedPreferences to enable silent re-login
  (iOS had skip-keychain as a dependency but never used it). Candidate: Keychain /
  EncryptedSharedPreferences.
- Recipe sync loads all full recipes into memory for ingredient search.
- `MealieAPI` singletons make ViewModel unit testing awkward on iOS; Android side is built
  against interfaces/fakes from the start.
