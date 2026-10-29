# Cookbook - Mealie Companion

A native recipe app for iOS and Android. Save recipes on your device or connect to
your own [Mealie](https://mealie.io) server. Cookbook is an independent companion,
not the official Mealie app.

## Features

- Import recipes from websites or your phone's share menu.
- Browse, search, edit, and favorite recipes, with offline access.
- Plan meals and manage shopping lists with a Mealie server.
- Optional iCloud sync and Reminders integration on iOS.
- Phone and tablet layouts, with light and dark themes.

## Screenshots

| Recipes | Recipe Detail | Meal Plan |
|---|---|---|
| <img src="docs/screenshots/iphone-recipes.png" width="230" alt="Recipe list"> | <img src="docs/screenshots/iphone-recipe-detail.png" width="230" alt="Recipe detail"> | <img src="docs/screenshots/iphone-meal-plan.png" width="230" alt="Meal plan"> |

## Getting started

Open the app and choose **Use Without Server**, or enter your Mealie server address
and sign in. Server connections currently use email and password.

Requires **iOS 17+** or **Android 8.0+**. A browser extension for saving recipes to
Mealie is also available; see the [extension guide](extension/README.md).

## Development

- **iOS:** Open `ios/Darwin/MealieApp.xcodeproj` in Xcode, select the
  **MealieApp App** scheme, and run on an installed simulator or device.
- **Android:** Open `android/` in Android Studio with SDK platform 36 and JDK 17.
  Build with `./gradlew :app:assembleDebug` from that directory.

For more detail, see the [iOS test guide](ios/Tests/MealieUISnapshotTests/README.md),
[Android test guide](android/app/src/test/java/com/jackabee/mealie/screenshots/README.md),
and [Android release guide](docs/ANDROID_RELEASE.md).

## Support

[Report an issue](https://github.com/gannonlawlor/mealie-app/issues) ·
[Troubleshooting](docs/SUPPORT.md) · [Privacy policy](docs/PRIVACY.md)
