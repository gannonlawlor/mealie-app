---
name: release
description: Bump version, archive, and upload to TestFlight. Use this skill when the user says "release", "testflight", "deploy", or "push to testflight". Runs the scripts/release.sh workflow. Accepts an optional argument of "patch" or "minor" (default: patch).
---

Bump the app version, archive an iOS build, upload to TestFlight, then commit and tag the release.

## Workflow

### Step 1: Determine bump type

Check if the user specified "patch" or "minor". Default is **patch**.

### Step 2: Run the release script

```bash
bash scripts/release.sh <patch|minor> --yes
```

The `--yes` flag skips the interactive confirmation prompt so it can run unattended.

This script:
1. Reads current version from `Skip.env`
2. Bumps the version (minor or patch) and increments the build number
3. Updates `Skip.env` and `Darwin/MealieApp.xcodeproj/project.pbxproj`
4. Archives the app with `xcodebuild archive`
5. Exports and uploads to TestFlight via `xcodebuild -exportArchive`
6. Commits the version bump, creates a git tag, and pushes both

### Important notes

- The archive and upload steps take several minutes.
- Requires valid Apple Developer signing credentials and Xcode configured with automatic signing.
- The ExportOptions.plist at `scripts/ExportOptions.plist` is configured for App Store Connect upload with team ID `6EFWX7FRKP`.
- To run interactively (with confirmation prompt), omit the `--yes` flag.

### Step 3: Confirm

After the script completes, verify the release by checking:
- `git log --oneline -1` — confirm the release commit
- `git tag --sort=-creatordate | head -3` — confirm the tag was created
