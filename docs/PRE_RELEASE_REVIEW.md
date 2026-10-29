# Public release assessment — October 29, 2026

Scope: source/configuration review of native iOS and Android apps, archived iOS
bundle inspection, Android debug/release tests, and current Apple/Google policy
checks. Store console metadata and live server end-to-end behavior were not
inspected. This is not a penetration test or complete device QA pass.

Recommendation: keep the current build in beta until the items below are resolved.
The existing recipe/import/planning/shopping feature set is sufficient for launch;
reliability, privacy, and release preparation should take priority over new features.

## Implementation checkpoint

The code changes below were implemented after this assessment and uploaded to
TestFlight as **1.1.20 (build 23)** on October 29, 2026. The changes and release
tag `v1.1.20` are pushed to GitHub. The original findings remain below as the
rationale; their line numbers describe the reviewed version, not the new implementation.

- Login and reauthentication share a proper UTF-8 form encoder, including the
  iOS share extension. Regression cases cover plus, ampersand, percent, spaces,
  equals, empty fields, and Unicode.
- iOS uses the shared App Group Keychain; Android uses AES-GCM with an Android
  Keystore key. Plaintext migration is retryable and deletes old values only
  after secure writes succeed. Backup rules exclude credential preferences.
  Session replacement is invalid until all fields are saved, preventing mixed
  server/token state; regression tests cover partial failures and restart.
- Privacy manifests are bundled in both iOS targets. Native Settings links to
  repository-hosted privacy and support documents. Support uses GitHub issues,
  as requested. Modern Reminders text, actual version display, Cookbook headings,
  and an HTTP disclosure are included.
- Android targets API 36 and has environment-backed upload signing with an
  explicit missing-key guard; see ANDROID_RELEASE.md.
- iOS persistence mutations throw and roll back failures. UI flows preserve
  pending changes and avoid reporting false success. Library initialization has
  retry/server-connection recovery without deleting data or replacing the store.
- Recipe records include optional external-storage photo bytes, with existing
  file backfill and local cache reconstruction. Replacing or removing an image
  clears old embedded data. A real two-device CloudKit test is still required.

### Remaining release steps

- Test the additive image schema in development, then review and deploy its
  changes to the production iCloud container using CloudKit Console. Do not reset
  production data. Apple guidance:
  https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema
- Verify a signed physical-device app and share extension can share Keychain
  credentials, including upgrade, locked-device behavior, and sign-out.
- Verify Android Keystore storage and backup/device-transfer behavior on devices.
- Supply the Android upload key/Play setup; complete store privacy disclosures,
  reviewer access, real screenshots, and a small beta/device QA pass.
- Standalone export/restore, licensing choice, CI, and broader accessibility QA
  remain follow-up work; this implementation does not claim those are complete.
- TestFlight upload succeeded; Apple processing and tester availability are
  separate from upload completion. No Google Play release was published.

### Verification after implementation

- iOS model suite: **132 passed**, zero failures, on iPhone 18 Pro/iOS 27.0.
- Android: **130 debug and 117 release tests passed**, debug APK assembled,
  lint completed with **0 errors and 57 warnings** (mostly dependency update
  suggestions, plus launcher-shape/style suggestions).
- Android screenshot verification passed all 12 references; four intentional
  login/settings references were reviewed and refreshed.
- iOS screenshots: 7 passed, 3 existing mismatches. Refreshed only two login
  references and local Settings; its version fixture is now deterministic.
  Meal Plan, dark recipe detail, and shopping detail mismatches were reproduced
  independently on unchanged HEAD `fd94814` on the same simulator. They remain
  visible follow-up work, rather than being hidden by a broad re-record.
- Final iOS validation archive succeeded at `build/CookbookReadiness.xcarchive`.
  App and extension privacy manifests, version alignment, modern Reminders
  purpose string, and display name were verified in the archive. Deep/strict
  signature validation passed with access to macOS certificate trust services.
- Android release-signing validation fails as intended when upload-key settings
  are absent, with an explicit list of required environment variables. Its task
  is compatible with Gradle's configuration cache.
- `git diff --check` passes. These checks do not replace the physical-device,
  production CloudKit, live-server, and store-console checks above.
- Privacy and support documents are now published on the repository's `main`
  branch, matching the links in the apps.

## Resolve before launch

1. **iOS login form encoding is incorrect.** In
   `ios/Sources/MealieModel/API/MealieAPI.swift:120` and `:238`, credentials use
   `CharacterSet.urlQueryAllowed` for an application/x-www-form-urlencoded body.
   A direct Foundation check leaves `a+b@example.com` and `abc&123+xyz` unchanged.
   Form decoding converts plus to space and treats ampersand as a field separator.
   Use proper form encoding for both initial login and silent reauthentication.
   Add regression tests for plus, ampersand, equals, percent, spaces, and Unicode.

2. **Protect persisted credentials on both platforms.** iOS AuthService stores
   token and password in App Group UserDefaults (`AuthService.swift:84-101`).
   Android AuthStore uses SharedPrefsKeyValueStore, whose values are ordinary
   SharedPreferences strings (`data/auth/KeyValueStore.kt:22-30`). These are app
   sandbox protected but are not credential vaults. Migrate secrets to iOS
   Keychain with appropriate extension sharing, and Android Keystore-backed
   encrypted storage. Prefer token renewal over retaining raw passwords when the
   server supports it. Remove migrated preference values; test upgrades and logout.
   Android allows backup with no explicit credential exclusions in the manifest;
   review backup/restore rules as part of this work.

3. **Complete privacy declarations and links.** No PrivacyInfo.xcprivacy was found
   in the iOS source or archived bundle, despite UserDefaults use in app/shared
   group code. Audit required-reason APIs and bundle manifests in the relevant
   targets. No privacy-policy or support link was found in the native Settings
   views. Add accessible links and make store declarations match actual behavior,
   including recipe-site requests, user-supplied servers, optional iCloud, and
   Reminders. A successful TestFlight upload is not proof of public-review readiness.

4. **Update Android submission configuration.** compileSdk and targetSdk are 35
   (`android/app/build.gradle.kts:12-17`). Google currently requires API 36 for
   ordinary new apps and updates, effective August 31, 2026. Upgrade and test the
   affected behaviors. No release signing configuration is defined in the checked-in
   Gradle file, and the release script only uploads iOS. Confirm external signing
   if already configured; otherwise prepare a securely signed AAB, Play App Signing,
   and an internal test release before production.

5. **Do not report successful recipe saves when persistence fails.**
   SwiftDataRecipeStore.saveRecipe catches and logs save errors without returning
   failure (`:104-108`), while RecipeViewModel.importFromURL reports success after
   calling it (`:331-332`). Propagate failure and preserve the user's input for a
   retry. Container initialization also calls fatalError (`:55`); provide a
   recoverable error path that never silently discards an existing recipe database.

6. **Verify the scope of iCloud sync.** RecipeEntity syncs encoded recipe data,
   but LocalRecipeStore.saveImage writes to Application Support and returns an
   absolute local path (`:79-86`). RecipeURLParser stores that path as recipe.image
   (`:212`). No image synchronization implementation was found. On a second device
   the stored path cannot identify the first device's file. Test two physical
   devices, favorites, offline edits, and enabling/disabling sync; sync image data
   or retain usable remote references before promising complete recipe sync.

## Store and product preparation

- Supply a reachable demo Mealie server and reviewer account with recipes, meal
  plans, and shopping lists. Local mode does not exercise server-only features.
- Clearly describe standalone versus server features; identify this as an
  independent companion. Verify and state tested Mealie versions and supported
  authentication methods. The current login UI offers email/password; do not
  imply support for every SSO-only server.
- Publish working privacy/support pages, finish App Privacy and Play Data safety,
  age ratings, accurate screenshots, and review notes in the store consoles.
- Replace the hardcoded iOS Settings version `1.0.0` with bundle metadata
  (`SettingsView.swift:190`). Update remaining Mealie-only app headings where
  they represent the client brand, rather than the server product.
- Modernize Reminders permission text to NSRemindersFullAccessUsageDescription
  and test allow/deny/re-enable on a physical device. The archive currently has
  the older description key. Its presence means absence of the newer key alone
  is not sufficient evidence of a crash.
- Make HTTP server setup clearly disclose that credentials/traffic are unencrypted.
  Preserve local-server compatibility deliberately; both apps currently permit
  cleartext traffic broadly.
- Add export/backup for standalone recipes, or clearly explain recovery limitations.
- Ensure deletion confirmations, pending shopping queue handling, server switching,
  expired sessions, and sign-out never lose or cross-contaminate user data.
- Check VoiceOver/TalkBack, large text, contrast, landscape, small phones, tablets,
  keyboard coverage, and empty/error/loading states manually.
- Resolve the repository's missing standalone license and third-party notices.
  Add repeatable CI for core tests and a documented Android release workflow.

## Suggested final beta pass

Use 5–10 testers across both platforms. Exercise fresh install and upgrade; import
from several real recipe sites and the share sheet with the app closed; duplicate
handling; edit/delete/favorite; airplane mode and recovery; invalid URLs, TLS
errors, and unreachable servers; special-character credentials and token expiry;
shopping retries without duplicate items; device restart; and iCloud across two
devices. Do not require extra features to call the first release complete.

## Verification

- Android `./gradlew test --offline`: passed, 123 debug tests and 110 release
  tests, zero failures/errors/skips. Variants overlap; these are not 233 unique tests.
- iOS archive and icon asset compilation succeeded during the release workflow.
- Confirmed the login encoding defect with Foundation directly.
- iOS model tests: 115 passed on iPhone 18 Pro simulator (iOS 27.0), zero
  failures/skips/runtime warnings, verified from the xcresult summary. The README's
  iPhone 17 Pro destination is not installed; the available simulator was used.
- Screenshot golden comparisons and a fresh live-server end-to-end pass were not
  performed in this review.

## Current primary sources

- Apple App Review Guidelines (privacy links, reviewer access):
  https://developer.apple.com/app-store/review/guidelines/
- Apple required-reason API declarations:
  https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- Android target SDK submission requirements:
  https://developer.android.com/google/play/requirements/target-sdk
- Apple Reminders access:
  https://developer.apple.com/documentation/eventkit/accessing-the-event-store
