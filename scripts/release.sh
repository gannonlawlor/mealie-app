#!/bin/bash
set -euo pipefail

SKIP_ENV="Skip.env"
PBXPROJ="Darwin/MealieApp.xcodeproj/project.pbxproj"
SCHEME="MealieApp App"

# Read current version from Skip.env
CURRENT_VERSION=$(grep '^MARKETING_VERSION' "$SKIP_ENV" | sed 's/.*= *//')
CURRENT_BUILD=$(grep '^CURRENT_PROJECT_VERSION' "$SKIP_ENV" | sed 's/.*= *//')

# Parse major.minor.patch
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Bump minor version, reset patch
NEW_MINOR=$((MINOR + 1))
NEW_VERSION="${MAJOR}.${NEW_MINOR}.0"
NEW_BUILD=$((CURRENT_BUILD + 1))

echo "Version: $CURRENT_VERSION → $NEW_VERSION"
echo "Build:   $CURRENT_BUILD → $NEW_BUILD"
echo ""

# Confirm
read -p "Proceed? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# 1. Update Skip.env
sed -i '' "s/^MARKETING_VERSION = .*/MARKETING_VERSION = $NEW_VERSION/" "$SKIP_ENV"
sed -i '' "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $NEW_BUILD/" "$SKIP_ENV"

# 2. Update ShareExtension versions in pbxproj
sed -i '' "s/MARKETING_VERSION = $CURRENT_VERSION;/MARKETING_VERSION = $NEW_VERSION;/g" "$PBXPROJ"
sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT_BUILD;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PBXPROJ"

echo "Updated version files."

# 3. Build for release (archive)
echo "Archiving..."
ARCHIVE_PATH="build/MealieApp.xcarchive"
xcodebuild -project Darwin/MealieApp.xcodeproj -scheme "$SCHEME" \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    archive SKIP_ACTION=none \
    CODE_SIGN_STYLE=Automatic \
    | tail -5

# 4. Export and upload to TestFlight
echo "Uploading to TestFlight..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist scripts/ExportOptions.plist \
    -allowProvisioningUpdates \
    | tail -5

# 5. Commit and tag
git add "$SKIP_ENV" "$PBXPROJ"
git commit -m "Release v$NEW_VERSION (build $NEW_BUILD)"
git tag "v$NEW_VERSION"
git push && git push --tags

echo ""
echo "Released v$NEW_VERSION (build $NEW_BUILD) to TestFlight."
