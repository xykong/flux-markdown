#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
MATH_LAB=$(mktemp -d "${TMPDIR:-/tmp}/flux-issue64-design.XXXXXX")
cp "$PROJECT_ROOT/scripts/research/issue64-math/"{package.json,package-lock.json,compare.js,compare.py,contracts.mjs,svg.html,chtml.html,main.swift} "$MATH_LAB/"
cp "$PROJECT_ROOT/docs/research/issue64/math-cases.json" "$MATH_LAB/cases.json"
(cd "$MATH_LAB" && npm ci --ignore-scripts --no-audit --no-fund)
python3 - "$PROJECT_ROOT" "$MATH_LAB" <<'PY'
from pathlib import Path
import sys
source = (Path(sys.argv[1]) / 'Sources/Shared/RendererBundleSchemeHandler.swift').read_text()
needle = 'let data = try Data(contentsOf: fileURL)'
assert source.count(needle) == 1
source = source.replace(needle, needle + '\n            fputs("ASSET \\(data.count) \\(url.absoluteString)\\n", stderr)')
(Path(sys.argv[2]) / 'RendererBundleSchemeHandler.swift').write_text(source)
PY
swiftc "$PROJECT_ROOT/Tests/Support/TestWindowPolicy.swift" "$MATH_LAB/RendererBundleSchemeHandler.swift" "$MATH_LAB/main.swift" -o "$MATH_LAB/probe-traced"
python3 "$MATH_LAB/compare.py"
node "$MATH_LAB/contracts.mjs"
printf 'Design research evidence: %s\n' "$MATH_LAB"
