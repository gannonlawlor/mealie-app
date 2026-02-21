# Mealie App

Mobile app for [Mealie.io](https://mealie.io) (self-hosted recipe manager) built with [Skip Fuse](https://skip.tools/docs/modules/skip-fuse/) — a single Swift/SwiftUI codebase that compiles to native iOS and native Android.

## Project Structure

```
Sources/
  MealieApp/      # App entry point, RootView, platform delegate protocol
  MealieModel/    # API client, Codable models, @Observable ViewModels
    API/          # MealieAPI (URLSession), AuthService (Keychain)
    Models/       # Auth, Recipe, MealPlan, ShoppingList, User, PaginatedResponse
    ViewModels/   # AuthViewModel, RecipeViewModel, MealPlanViewModel, ShoppingViewModel
  MealieUI/       # All SwiftUI views (SkipFuseUI on Android)
    Views/
      RecipesTab/   # RecipeListView, RecipeDetailView, RecipeSplitView (iPad)
      MealPlanTab/  # MealPlanView, AddMealPlanView
      ShoppingTab/  # ShoppingListsView, ShoppingListDetailView, ShoppingSplitView (iPad)
      SettingsTab/  # SettingsView
      LoginView.swift
      SidebarView.swift   # iPad sidebar navigation
    ContentView.swift     # Adaptive layout: TabView (iPhone) / Sidebar+Split (iPad)
Darwin/           # Xcode project, xcconfig, assets, Info.plist
Android/          # Android-specific source (Kotlin entry point)
Skip.env          # Shared config (bundle ID, version, Android package name)
```

## Build Commands

```sh
# iOS only (skip Android Gradle build)
xcodebuild -project Darwin/MealieApp.xcodeproj -scheme "MealieApp App" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build SKIP_ACTION=none

# iOS + Android (build only, no launch)
xcodebuild -project Darwin/MealieApp.xcodeproj -scheme "MealieApp App" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build SKIP_ACTION=build

# iOS + Android (build and launch on emulator)
xcodebuild -project Darwin/MealieApp.xcodeproj -scheme "MealieApp App" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build
```

First build downloads ~1GB of Gradle dependencies and is slow. Subsequent builds are fast.

## Skip Fuse Constraints

These SwiftUI APIs are **not available** in SkipFuseUI (Android). Avoid them or use the workarounds noted:

- `NavigationSplitView` — use custom `HStack` layout with `@Environment(\.horizontalSizeClass)`
- `Color(.systemGray6)` — use `Color(white: 0.9)`
- `.keyboardType()`, `.textInputAutocapitalization()` — not available, omit
- `.foregroundStyle(.accent)` — use `Color.accentColor`
- `.fixedSize(horizontal:vertical:)` — not available, remove
- `ForEach(0..<count, id: \.self)` — use `ForEach(Array(items.enumerated()), id: \.offset)`
- `import OSLog` / `Logger` — use `#if canImport(OSLog)` guard or `print()`
- Generic types can't bridge across Skip Fuse — use concrete types (e.g. `RecipePaginatedResponse` not `PaginatedResponse<T>`)

## Skip Module Configuration

- `MealieModel` and `MealieUI` use `skip: mode: native, bridging: true` in their `skip.yml`
- `MealieApp` uses `build: contents:` (transpiled wrapper)
- All Views and their properties must be `public` or default access (not `private`)
- Use `@MainActor` on ViewModels to fix Swift 6 concurrency issues with `@Bindable`

## Key Config Values

- **Bundle ID (iOS)**: `com.jackabee.mealie` (in Skip.env as `PRODUCT_BUNDLE_IDENTIFIER`)
- **Application ID (Android)**: `com.jackabee.mealie` (in Skip.env as `ANDROID_APPLICATION_ID`)
- **Android package name**: `mealie.app` (in Skip.env as `ANDROID_PACKAGE_NAME`) — must match `rootProject.name` in Gradle (derived from SPM package name) and Kotlin source path. This is NOT the user-facing app ID.
- **Xcode project**: `Darwin/MealieApp.xcodeproj`, scheme `"MealieApp App"`
- The pbxproj must have `XCLocalSwiftPackageReference` pointing to `..` (SPM root) or the skipstone build plugin won't run

## Mealie API (v2)

- **Auth**: `POST /api/auth/token` (form-encoded) returns JWT Bearer token — uses snake_case (`access_token`, `token_type`)
- **All other endpoints** use **camelCase** JSON keys (e.g. `recipeIngredient`, `entryType`, `shoppingListId`) — do NOT use snake_case CodingKeys for these
- **Pagination** is the exception: uses `per_page` and `total_pages` (snake_case)
- **Recipes**: `GET /api/recipes` (paginated), `GET /api/recipes/{slug}` (detail)
- **Meal Plans**: `GET/POST /api/households/mealplans` — entry `id` is `Int`, not `String`
- **Shopping Lists**: `GET /api/households/shopping/lists`, `/items`
- **Images**: `GET /api/media/recipes/{id}/images/min-original.webp`

## iPad Layout

The app uses an adaptive layout based on `horizontalSizeClass`:
- **Compact** (iPhone): Standard `TabView` with four tabs
- **Regular** (iPad): Custom sidebar (240pt) + content area with two-column split views for Recipes and Shopping tabs

On iPad, recipe and shopping list selection uses `Button` (not `NavigationLink`) to set selection state in the split view. `RecipeDetailView` accepts an optional `onDelete` closure so the split view can clear selection after deletion.

## Error Handling

All network errors must be logged with details. In `catch` blocks for API calls, always `print()` the underlying error so it appears in the console. Never silently swallow errors — at minimum log them even if the UI shows a generic message.
