---
name: release
description: Bump version, archive, and upload to TestFlight. Use this skill when the user says "release", "testflight", "deploy", or "push to testflight". Runs the scripts/release.sh workflow. Accepts an optional argument of "patch" or "minor" (default: patch).
---

Bump the app version, archive an iOS build, upload to TestFlight, then commit and tag the release.

## Workflow

This skill executes the `scripts/release.sh` script interactively. The user must confirm the version bump before proceeding.

### Step 1: Determine bump type

Check if the user specified "patch" or "minor". Default is **patch**.

### Step 2: Run the release script

```bash
bash scripts/release.sh <patch|minor>
```

This script:
1. Reads current version from `Skip.env`
2. Bumps the version (minor or patch) and increments the build number
3. Prompts for confirmation (user must approve)
4. Updates `Skip.env` and `Darwin/MealieApp.xcodeproj/project.pbxproj`
5. Archives the app with `xcodebuild archive`
6. Exports and uploads to TestFlight via `xcodebuild -exportArchive`
7. Commits the version bump, creates a git tag, and pushes both

### Important notes

- This script is **interactive** — it requires the user to confirm the version bump. Tell the user to run it themselves with `! bash scripts/release.sh` if Claude can't handle the interactive prompt.
- The archive and upload steps take several minutes.
- Requires valid Apple Developer signing credentials and Xcode configured with automatic signing.
- The ExportOptions.plist at `scripts/ExportOptions.plist` is configured for App Store Connect upload with team ID `6EFWX7FRKP`.

### Step 3: Confirm

After the script completes, verify the release by checking:
- `git log --oneline -1` — confirm the release commit
- `git tag --sort=-creatordate | head -3` — confirm the tag was created
