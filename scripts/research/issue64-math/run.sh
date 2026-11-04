#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
MATH_LAB=$(mktemp -d "${TMPDIR:-/tmp}/flux-issue64-math.XXXXXX")
cp "$PROJECT_ROOT/scripts/research/issue64-math/"{package.json,package-lock.json,semantic-probe.mjs,candidate.html,candidate-probe.js,main.swift} "$MATH_LAB/"
cp "$PROJECT_ROOT/docs/research/issue64/math-cases.json" "$MATH_LAB/cases.json"
(cd "$MATH_LAB" && npm ci --ignore-scripts --no-audit --no-fund)
node "$MATH_LAB/semantic-probe.mjs"
swiftc "$PROJECT_ROOT/Sources/Shared/RendererBundleSchemeHandler.swift" "$MATH_LAB/main.swift" -o "$MATH_LAB/probe"
"$MATH_LAB/probe" 'flux-renderer://bundle/candidate.html' "$MATH_LAB" "$MATH_LAB/candidate-probe.js" "$MATH_LAB/cases.json" > "$MATH_LAB/webkit-results.json" 2> "$MATH_LAB/webkit.log"
node - "$MATH_LAB" <<'JS'
const fs = require('node:fs');
const assert = require('node:assert/strict');
const lab = process.argv[2];
const semantic = JSON.parse(fs.readFileSync(`${lab}/semantic-results.json`, 'utf8'));
const webkit = JSON.parse(fs.readFileSync(`${lab}/webkit-results.json`, 'utf8'));
assert.equal(semantic.full.math.length, 13);
assert.equal(semantic.full.errors.length, 1);
assert(semantic.full.errors[0].includes('unknownMarkdownPreviewCommand'));
assert(semantic.full.math[9].mml.includes('(1)'));
assert(semantic.edge.math[0].mml.includes('(A)'));
assert(semantic.edge.math[3].mml.includes('(???)'));
for (const phase of ['full', 'repeat']) {
  assert.equal(webkit[phase].items.length, 13);
  assert.equal(webkit[phase].labels['eq:pythagoras'].tag, '1');
  for (const item of webkit[phase].items) {
    assert(item.svgCount > 0, item.id);
    assert(item.height > 0, item.id);
    assert.equal(item.errorCount, item.expect === 'error' ? 1 : 0, item.id);
  }
  const ref = webkit[phase].items.find(item => item.id === 'M10').refs[0];
  assert(ref.mathJaxTargetExists);
}
assert.equal(webkit.edge.labels['eq:forward'].tag, 'A');
assert.equal(webkit.edge.items.find(item => item.id === 'duplicate').errorCount, 1);
assert.equal(webkit.edge.items.find(item => item.id === 'missing').errorCount, 0);
assert(!fs.readFileSync(`${lab}/webkit.log`, 'utf8').includes('CSP '));
console.log(`Research probes passed. Evidence: ${lab}`);
console.log('This validates the isolated engine, not the production Markdown pipeline or visual acceptance.');
JS
