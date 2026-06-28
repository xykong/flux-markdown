#!/bin/bash
set -euo pipefail

TARGET_PATH="${1:-build/artifacts/FluxMarkdown.dmg}"
APP_NAME="FluxMarkdown.app"
APPEX_RELATIVE_PATH="Contents/PlugIns/MarkdownPreview.appex"
REQUIRED_ENTITLEMENT="com.apple.security.app-sandbox"
FORBIDDEN_RELEASE_ENTITLEMENTS=(
    "com.apple.security.get-task-allow"
    "com.apple.security.temporary-exception.files.absolute-path.read-only"
)

cleanup_mount=""

fail() {
    echo "❌ $1" >&2
    exit 1
}

cleanup() {
    if [ -n "$cleanup_mount" ] && [ -d "$cleanup_mount" ]; then
        hdiutil detach "$cleanup_mount" -quiet >/dev/null 2>&1 || true
        rmdir "$cleanup_mount" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

if [ ! -e "$TARGET_PATH" ]; then
    fail "Release artifact not found: $TARGET_PATH"
fi

if [[ "$TARGET_PATH" == *.dmg ]]; then
    cleanup_mount=$(mktemp -d)
    echo "🔍 Mounting DMG for entitlement verification: $TARGET_PATH"
    hdiutil attach "$TARGET_PATH" -mountpoint "$cleanup_mount" -nobrowse -readonly >/dev/null
    APP_PATH="$cleanup_mount/$APP_NAME"
else
    APP_PATH="$TARGET_PATH"
fi

APPEX_PATH="$APP_PATH/$APPEX_RELATIVE_PATH"

if [ ! -d "$APP_PATH" ]; then
    fail "App bundle not found in artifact: $APP_PATH"
fi

if [ ! -d "$APPEX_PATH" ]; then
    fail "QuickLook extension not found: $APPEX_PATH"
fi

echo "🔐 Verifying app signature..."
/usr/bin/codesign --verify --strict --deep --verbose=2 "$APP_PATH"

echo "🔐 Checking QuickLook extension sandbox entitlement..."
ENTITLEMENTS=$(/usr/bin/codesign -d --entitlements :- "$APPEX_PATH" 2>/dev/null || true)

if ! printf '%s\n' "$ENTITLEMENTS" | grep -q "$REQUIRED_ENTITLEMENT"; then
    fail "MarkdownPreview.appex is missing $REQUIRED_ENTITLEMENT"
fi

for forbidden in "${FORBIDDEN_RELEASE_ENTITLEMENTS[@]}"; do
    if printf '%s\n' "$ENTITLEMENTS" | grep -q "$forbidden"; then
        fail "MarkdownPreview.appex release entitlements must not include $forbidden"
    fi
done

if printf '%s\n' "$ENTITLEMENTS" | grep -q "/Users/"; then
    fail "MarkdownPreview.appex release entitlements must not include build-machine home paths"
fi

echo "🔐 Checking app release entitlements..."
APP_ENTITLEMENTS=$(/usr/bin/codesign -d --entitlements :- "$APP_PATH" 2>/dev/null || true)
if printf '%s\n' "$APP_ENTITLEMENTS" | grep -q "com.apple.security.get-task-allow"; then
    fail "FluxMarkdown.app release entitlements must not include com.apple.security.get-task-allow"
fi

echo "✅ Release artifact preserves MarkdownPreview.appex sandbox entitlement"
