#!/bin/bash
set -euo pipefail

TARGET_PATH="${1:-build/artifacts/FluxMarkdown.dmg}"
APP_NAME="FluxMarkdown.app"
APPEX_RELATIVE_PATH="Contents/PlugIns/MarkdownPreview.appex"

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

echo "Checking the packaged app's sandbox and Nix-managed update policy..."
python3 - "$APP_PATH" "$APPEX_PATH" <<'PY'
from pathlib import Path
import plistlib
import subprocess
import sys

app, extension = map(Path, sys.argv[1:])
for bundle in (app, extension):
    output = subprocess.run(
        ['/usr/bin/codesign', '-d', '--entitlements', '-', '--xml', str(bundle)],
        check=True, capture_output=True,
    )
    entitlements = plistlib.loads(output.stdout)
    if bundle == extension and entitlements.get('com.apple.security.app-sandbox') is not True:
        raise SystemExit(f'{bundle.name} must enable App Sandbox.')
    forbidden = {
        'com.apple.security.get-task-allow',
        'com.apple.security.files.downloads.read-write',
        'com.apple.security.temporary-exception.mach-lookup.global-name',
        'com.apple.security.temporary-exception.files.absolute-path.read-write',
    }
    if bundle == extension:
        forbidden.add('com.apple.security.temporary-exception.files.absolute-path.read-only')
    for key in forbidden:
        if key in entitlements:
            raise SystemExit(f'{bundle.name} must not grant {key}.')
    if '/Users/' in str(entitlements):
        raise SystemExit(f'{bundle.name} must not contain build-machine home paths.')

with (app / 'Contents/Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
if any(key.startswith('SU') for key in info):
    raise SystemExit('The Nix-managed app must not configure Sparkle.')
if list(app.rglob('Sparkle.framework')):
    raise SystemExit('The Nix-managed app must not embed Sparkle.')
for notice in ('LICENSE', 'THIRD_PARTY_LICENSES.md', 'RENDERER_LICENSES.txt'):
    if not (app / 'Contents/Resources' / notice).is_file():
        raise SystemExit(f'The release must include {notice}.')
print('Verified QuickLook sandbox, license notices, and absence of the in-app updater.')
PY
