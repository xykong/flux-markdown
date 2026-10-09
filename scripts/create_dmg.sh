#!/bin/bash
set -euo pipefail

APP_NAME="FluxMarkdown"
APP_BUNDLE="${APP_NAME}.app"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
APP_PATH="$REPO_ROOT/build/DerivedData/Build/Products/Release/$APP_BUNDLE"
DMG_NAME="FluxMarkdown.dmg"
OUTPUT_DIR="build/artifacts"

echo "🚀 Starting DMG creation for ${APP_NAME}..."

# 1. Ensure clean build
# CLEAN=1 forces xcodebuild to drop all previous outputs before building.
echo "📦 Building application..."
make app CONFIGURATION=Release CLEAN=1

# Package only the Release app built by this checkout.
if [ ! -d "$APP_PATH" ]; then
    echo "Error: Built app not found: $APP_PATH" >&2
    exit 1
fi
EXPECTED_VERSION="$(cat .version)"
ACTUAL_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")
if [ "$ACTUAL_VERSION" != "$EXPECTED_VERSION" ]; then
    echo "Error: Built app version $ACTUAL_VERSION does not match $EXPECTED_VERSION" >&2
    exit 1
fi
./scripts/verify-release-entitlements.sh "$APP_PATH"

# 3. Create artifacts directory
mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR/$DMG_NAME"

# 4. Prepare temporary folder
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
echo "📂 Preparing DMG content in $TMP_DIR..."
cp -R "$APP_PATH" "$TMP_DIR/"
# 4.5. Pre-seed the background directory with Retina asset for Finder
mkdir -p "$TMP_DIR/.background"
cp assets/dmg/background@2x.png "$TMP_DIR/.background/background@2x.png"

# 5. Create DMG using create-dmg
echo "💿 Creating styled DMG using create-dmg..."

# Volume name must change to bypass Finder cache for the layout
VOLUME_NAME="Install ${APP_NAME}"
create-dmg \
  --volname "${VOLUME_NAME}" \
  --background "assets/dmg/background.tiff" \
  --window-pos 200 120 \
  --window-size 660 468 \
  --icon-size 100 \
  --icon "${APP_BUNDLE}" 180 220 \
  --app-drop-link 480 220 \
  --icon ".background" 120 120 \
  "$OUTPUT_DIR/$DMG_NAME" \
  "$TMP_DIR/"

echo "🔐 Verifying release entitlements..."
./scripts/verify-release-entitlements.sh "$OUTPUT_DIR/$DMG_NAME"


echo ""
echo "✅ DMG created successfully at: $OUTPUT_DIR/$DMG_NAME"
echo ""
