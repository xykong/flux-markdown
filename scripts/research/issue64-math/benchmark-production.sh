#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
MATH_BENCH=$(mktemp -d "${TMPDIR:-/tmp}/flux-issue64-production-bench.XXXXXX")
swiftc "$PROJECT_ROOT/Tests/Support/TestWindowPolicy.swift" "$PROJECT_ROOT/Sources/Shared/RendererBundleSchemeHandler.swift" "$PROJECT_ROOT/scripts/research/issue64-math/main.swift" -o "$MATH_BENCH/probe"
"$MATH_BENCH/probe" 'flux-renderer://bundle/index.html' "$PROJECT_ROOT/web-renderer/dist" "$PROJECT_ROOT/scripts/research/issue64-math/benchmark-production.js" "$PROJECT_ROOT/Tests/fixtures/issues/64/markdown-preview-test.md" 175 > "$MATH_BENCH/results.json" 2> "$MATH_BENCH/run.log"
python3 - "$MATH_BENCH/results.json" <<'PY'
import json, math, sys
results = json.load(open(sys.argv[1]))
for count in ['100', '1000']:
    samples = sorted(results[count]['samples'])
    assert len(samples) == 30
    print(count, 'items p50/p95 ms:', samples[14], samples[math.ceil(.95 * len(samples)) - 1], 'DOM bytes:', results[count]['domBytes'])
PY
printf 'Production benchmark evidence: %s\n' "$MATH_BENCH"
