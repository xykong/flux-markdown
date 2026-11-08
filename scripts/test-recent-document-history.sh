#!/bin/bash
# Disposable bundles/preferences only; never mutates the user's recent list.
set -euo pipefail
cd "$(dirname "$0")/.."
WORK=$(mktemp -d)
ID="com.xykong.history-test.$(uuidgen)"
trap 'defaults delete "$ID" 2>/dev/null || true; defaults delete "$ID.system" 2>/dev/null || true; rm -rf "$WORK"' EXIT
APP="$WORK/HistoryProbe.app"
mkdir -p "$APP/Contents/MacOS"
swiftc Sources/Shared/RecentDocumentHistory.swift Sources/Markdown/RecentDocumentController.swift Tests/RecentDocumentIntegration/main.swift -o "$APP/Contents/MacOS/HistoryProbe"
touch "$WORK/sample.md"
write_info() {
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>$1</string><key>CFBundleExecutable</key><string>HistoryProbe</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleVersion</key><string>$2</string></dict></plist>
PLIST
codesign --force --sign - "$APP" 2>/dev/null
}
check() {
 local expected="$1"; shift
 local result
 result=$("$APP/Contents/MacOS/HistoryProbe" "$@")
 [[ "$result" == "recent-count=$expected" ]] || { echo "FAIL expected=$expected actual=$result"; exit 1; }
}
write_info "$ID.system" 1
check 1 --system-only --add "$WORK/sample.md"
check 1 --system-only
write_info "$ID.system" 2
check 0 --system-only
echo 'PASS reproduced system history loss after signing identity change'
write_info "$ID" 1
check 1 --system-only --add "$WORK/sample.md"
check 1 # migrate existing system history
write_info "$ID" 2
check 1
rm "$WORK/sample.md"
check 1 # disconnected/missing files must remain
check 0 --clear
write_info "$ID" 3
check 0
echo 'PASS migration, changed identity, unavailable file and explicit clear'
