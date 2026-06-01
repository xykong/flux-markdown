#!/bin/bash
set -e

APP_NAME="FluxMarkdown"
APP_BUNDLE="${APP_NAME}.app"
BUILD_DIR="${HOME}/Library/Developer/Xcode/DerivedData/FluxMarkdown-*"
DMG_NAME="FluxMarkdown.dmg"
OUTPUT_DIR="build/artifacts"

echo "🚀 Starting DMG creation for ${APP_NAME}..."

# 1. Ensure clean build
echo "📦 Building application..."
make app

# 2. Locate the built app
EXPECTED_VERSION="$(cat .version 2>/dev/null || true)"
APP_PATH=""

if [ -n "$EXPECTED_VERSION" ]; then
    while IFS= read -r candidate; do
        info_plist="$candidate/Contents/Info.plist"
        if [ ! -f "$info_plist" ]; then
            continue
        fi

        candidate_version=$(/usr/bin/defaults read "$info_plist" CFBundleShortVersionString 2>/dev/null || true)
        candidate_build=$(/usr/bin/defaults read "$info_plist" CFBundleVersion 2>/dev/null || true)

        if [ "$candidate_version" = "$EXPECTED_VERSION" ]; then
            APP_PATH="$candidate"
            break
        fi

        expected_build="$(echo "$EXPECTED_VERSION" | awk -F. '{print $3}')"
        if [ -n "$expected_build" ] && [ "$candidate_build" = "$expected_build" ]; then
            APP_PATH="$candidate"
            break
        fi
    done < <(find "$HOME/Library/Developer/Xcode/DerivedData" -name "${APP_BUNDLE}" -path "*/Build/Products/Release/*" 2>/dev/null)
fi

if [ -z "$APP_PATH" ]; then
    APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "${APP_BUNDLE}" -path "*/Build/Products/Release/*" | head -n 1)
fi

if [ -z "$APP_PATH" ]; then
    echo "❌ Error: Could not find built ${APP_BUNDLE}"
    exit 1
fi

echo "✅ Found app at: $APP_PATH"

# 3. Create artifacts directory
mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR/$DMG_NAME"

# 4. Prepare temporary folder
TMP_DIR=$(mktemp -d)
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

# 6. Cleanup
rm -rf "$TMP_DIR"

echo ""
echo "✅ DMG created successfully at: $OUTPUT_DIR/$DMG_NAME"
echo ""
