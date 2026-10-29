# Android public release

The Android app compiles and targets API 36. Install Android SDK platform 36 and
use the project's Gradle wrapper. The iOS release script keeps the version number
in sync but does not publish Android.

## Configure upload signing

Use an existing upload key for an existing Play app. For a new Play app, create and
securely back up an upload keystore using Android Studio's **Generate Signed
Bundle / APK** workflow. Do not commit keystores or passwords. Enable Play App
Signing in Play Console and retain your upload key separately from the repository.

Supply these environment variables through your local shell or CI secret manager:

- `COOKBOOK_KEYSTORE_PATH`: absolute path to the upload keystore
- `COOKBOOK_KEYSTORE_PASSWORD`: keystore password
- `COOKBOOK_KEY_ALIAS`: upload key alias
- `COOKBOOK_KEY_PASSWORD`: key password

Gradle reads these variables to configure the release signer. Debug builds and
unit tests work without them. `bundleRelease` and `assembleRelease` fail with a
clear message when they are missing, rather than silently shipping an unsigned
artifact. Signing is not configured merely by adding this workflow: the owner must
supply the correct private key and verify its certificate against Play Console.

## Build and verify

From `android/`:

```sh
./gradlew test
./gradlew bundleRelease
```

The signed bundle is `app/build/outputs/bundle/release/app-release.aab`. Verify
its signature with `jarsigner -verify` and compare the signing certificate to the
upload certificate in Play Console. Keep the signing environment out of logs.

Upload the bundle to **Internal testing** first. Exercise fresh install, upgrade,
share imports, offline recovery, tablets/large screens, keyboard/layout behavior,
and server login on Android 16. Run the Play pre-launch report. Confirm applicable
native libraries support 16 KB page sizes using Play's bundle analysis.

Before production, publish the repository's privacy/support documents (the in-app
links refer to `main`), complete Data safety, app access/reviewer credentials,
content rating, store screenshots, developer verification, and any testing
requirements shown for your account. This workflow does not upload or promote a
release automatically.

Official references:

- [Sign your app](https://developer.android.com/studio/publish/app-signing)
- [Build from the command line](https://developer.android.com/build/building-cmdline)
- [Target API requirements](https://developer.android.com/google/play/requirements/target-sdk)
