# Mealie App

A native mobile app for [Mealie](https://mealie.io) — the self-hosted recipe manager. Built with [Skip Fuse](https://skip.tools/docs/modules/skip-fuse/), a single Swift/SwiftUI codebase compiles to **native iOS** and **native Android**.

## Features

- **Recipes** — Browse, search, import from URL, edit, and favorite recipes
- **Meal Planning** — Weekly meal plan view with add/delete support
- **Shopping Lists** — Create lists, add items manually or from recipe ingredients, check off items
- **Dark Mode** — System, Light, and Dark theme options
- **Offline Cache** — Data loads instantly from local cache, then refreshes from the server
- **iPad Support** — Adaptive sidebar + split view layout on larger screens

## Screenshots

*Coming soon*

## Requirements

- A running [Mealie](https://mealie.io) server (v1.0+)
- **iOS**: Xcode 16+, iOS 17+
- **Android**: Swift Android SDK via [Skip](https://skip.tools) (`skip android sdk install`)

## Getting Started

1. Clone the repository:
   ```sh
   git clone https://github.com/gannonlawlor/mealie-app.git
   cd mealie-app
   ```

2. Build and run on iOS Simulator:
   ```sh
   xcodebuild -project Darwin/MealieApp.xcodeproj -scheme "MealieApp App" \
     -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
     build SKIP_ACTION=none
   ```

3. Build for both iOS and Android:
   ```sh
   xcodebuild -project Darwin/MealieApp.xcodeproj -scheme "MealieApp App" \
     -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
     build SKIP_ACTION=build
   ```

   The first build downloads ~1GB of Gradle dependencies and is slow. Subsequent builds are fast.

4. Open the app and enter your Mealie server URL to connect.

## Project Structure

```
Sources/
  MealieApp/      # App entry point, RootView
  MealieModel/    # API client, Codable models, ViewModels
  MealieUI/       # All SwiftUI views
Darwin/           # Xcode project, assets, Info.plist
Android/          # Android-specific Kotlin entry point
Skip.env          # Shared config (bundle ID, version)
```

## Tech Stack

- **Swift 6** / **SwiftUI** — UI and business logic
- **Skip Fuse** — Cross-platform bridging (native Swift on Android via Kotlin/JVM)
- **URLSession** — Networking
- **OSLog** — Structured logging (iOS), with print fallback (Android)
- **Keychain** — Secure token storage (via skip-keychain)

## License

MIT
