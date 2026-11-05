#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
if [[ $# -ne 1 || "$1" != /* || ! -f "$1" ]]; then
    printf 'Usage: %s /absolute/path/to/fixture.md\n' "$0" >&2
    exit 2
fi
HOST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/flux-issue64-system-host.XXXXXX")
HOST_APP="$HOST_DIR/Issue64QuickLookHost.app"
mkdir -p "$HOST_APP/Contents/MacOS"
python3 - "$HOST_APP" <<'PY'
import plistlib,sys
from pathlib import Path
p=Path(sys.argv[1])/'Contents/Info.plist'
p.write_bytes(plistlib.dumps({'CFBundleIdentifier':'com.xykong.Issue64QuickLookHost','CFBundleName':'Issue64QuickLookHost','CFBundleExecutable':'Issue64QuickLookHost','CFBundlePackageType':'APPL','LSUIElement':True}))
PY
swiftc "$ROOT/Tests/Support/TestWindowPolicy.swift" "$ROOT/scripts/research/issue64-math/quicklook-host.swift" -o "$HOST_APP/Contents/MacOS/Issue64QuickLookHost"
codesign --force --sign - "$HOST_APP"
printf 'Task-owned QuickLook host: %s\n' "$HOST_APP"
"$HOST_APP/Contents/MacOS/Issue64QuickLookHost" "$1"
