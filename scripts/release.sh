#!/bin/bash
set -euo pipefail

XCCONFIG="ios/Darwin/MealieApp.xcconfig"
PBXPROJ="ios/Darwin/MealieApp.xcodeproj/project.pbxproj"
GRADLE_APP="android/app/build.gradle.kts"
SCHEME="MealieApp App"
BUMP_TYPE="${1:-patch}"

# Read current version from the xcconfig
CURRENT_VERSION=$(grep '^MARKETING_VERSION' "$XCCONFIG" | sed 's/.*= *//')
CURRENT_BUILD=$(grep '^CURRENT_PROJECT_VERSION' "$XCCONFIG" | sed 's/.*= *//')

# Parse major.minor.patch
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

case "$BUMP_TYPE" in
    patch)
        NEW_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"
        ;;
    minor)
        NEW_VERSION="${MAJOR}.$((MINOR + 1)).0"
        ;;
    *)
        echo "Usage: $0 [minor|patch]"
        exit 1
        ;;
esac
NEW_BUILD=$((CURRENT_BUILD + 1))

echo "Version: $CURRENT_VERSION → $NEW_VERSION"
echo "Build:   $CURRENT_BUILD → $NEW_BUILD"
echo ""

# Skip confirmation with --yes / -y flag
if [[ "${2:-}" != "--yes" && "${2:-}" != "-y" ]]; then
    read -p "Proceed? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# 1. Update iOS versions (xcconfig + ShareExtension overrides in pbxproj)
sed -i '' "s/^MARKETING_VERSION = .*/MARKETING_VERSION = $NEW_VERSION/" "$XCCONFIG"
sed -i '' "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $NEW_BUILD/" "$XCCONFIG"
sed -i '' "s/MARKETING_VERSION = $CURRENT_VERSION;/MARKETING_VERSION = $NEW_VERSION;/g" "$PBXPROJ"
sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT_BUILD;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PBXPROJ"

# 2. Keep Android versions in lockstep
sed -i '' "s/versionCode = $CURRENT_BUILD/versionCode = $NEW_BUILD/" "$GRADLE_APP"
sed -i '' "s/versionName = \"$CURRENT_VERSION\"/versionName = \"$NEW_VERSION\"/" "$GRADLE_APP"

echo "Updated version files."

# 3. Build for release (archive)
echo "Archiving..."
ARCHIVE_PATH="build/MealieApp.xcarchive"
xcodebuild -project ios/Darwin/MealieApp.xcodeproj -scheme "$SCHEME" \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    archive \
    CODE_SIGN_STYLE=Automatic \
    -allowProvisioningUpdates \
    | tail -5

# 4. Export and upload to TestFlight
echo "Uploading to TestFlight..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist scripts/ExportOptions.plist \
    -allowProvisioningUpdates \
    | tail -5

# 5. Commit and tag
git add "$XCCONFIG" "$PBXPROJ" "$GRADLE_APP"
git commit -m "Release v$NEW_VERSION (build $NEW_BUILD)"
git tag "v$NEW_VERSION"
git push && git push --tags

echo ""
echo "Released v$NEW_VERSION (build $NEW_BUILD) to TestFlight."
