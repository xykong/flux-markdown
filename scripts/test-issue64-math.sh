#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
ISSUE64_RUN=$(mktemp -d "${TMPDIR:-/tmp}/flux-issue64-e2e.XXXXXX")
trap 'printf "Issue 64 validation failed; inspect logs in %s\n" "$ISSUE64_RUN" >&2' ERR
printf 'Issue 64 evidence directory: %s\n' "$ISSUE64_RUN"
cd "$PROJECT_ROOT"
python3 - "$ISSUE64_RUN" <<'PY'
from pathlib import Path
import json, hashlib, base64, sys
root=Path.cwd(); out=Path(sys.argv[1]); fixture=root/'Tests/fixtures/issues/64'
manifest=json.loads((root/'docs/research/issue64/manifest.json').read_text())
for entry in manifest['files']:
    data=(fixture/entry['path']).read_bytes()
    assert len(data)==entry['bytes'] and hashlib.sha256(data).hexdigest()==entry['sha256'],entry['path']
original=(fixture/'markdown-preview-test.md').read_text()
cases=json.loads((root/'docs/research/issue64/math-cases.json').read_text())
section=original[original.index('## 10 ·'):original.index('<a id="diagrams">')]
valid='\n'.join(line for line in section.splitlines() if 'unknownMarkdownPreviewCommand' not in line)
valid=next(c['tex'] for c in cases if c['id']=='M13')+'\n\n'+valid
svg=base64.b64encode((fixture/'markdown-preview-test-assets/sample.svg').read_bytes()).decode()
payload={'original':original,'valid':valid,'invalid':r'$\unknownMarkdownPreviewCommand{x}$','imageData':{'markdown-preview-test-assets/sample.svg':'data:image/svg+xml;base64,'+svg}}
(out/'input.json').write_text(json.dumps(payload))
PY
npm test --prefix web-renderer -- --runInBand --silent > "$ISSUE64_RUN/jest.log" 2>&1
npm run --prefix web-renderer build > "$ISSUE64_RUN/build.log" 2>&1
env -u FLUX_WEBKIT_CASE_FILTER scripts/test-renderer-webkit.sh > "$ISSUE64_RUN/native-suite.log" 2>&1
swiftc Sources/Shared/RendererBundleSchemeHandler.swift scripts/research/issue64-math/main.swift -o "$ISSUE64_RUN/probe"
"$ISSUE64_RUN/probe" 'flux-renderer://bundle/index.html' "$PROJECT_ROOT/web-renderer/dist" "$PROJECT_ROOT/scripts/issue64/math-resource-boundary.js" "$ISSUE64_RUN/input.json" 45 > "$ISSUE64_RUN/math-resource-boundary.json" 2> "$ISSUE64_RUN/math-resource-boundary.log"
if rg -q 'FORBIDDEN_MATH_RESOURCE_REQUEST' "$ISSUE64_RUN/math-resource-boundary.log"; then
    printf 'Unsupported mathematical image initiated a resource request\n' >&2
    exit 1
fi
python3 scripts/issue64/verify-math-resource-http.py "$ISSUE64_RUN/probe" "$PROJECT_ROOT/web-renderer/dist" "$ISSUE64_RUN/http-resource-boundary" > "$ISSUE64_RUN/http-resource-boundary-run.log" 2>&1
for ISSUE64_WIDTH in 320 600 960; do
    for ISSUE64_ZOOM in 1 2; do
        for ISSUE64_THEME in light dark; do
            FLUX_MATH_PROBE_WIDTH="$ISSUE64_WIDTH" FLUX_MATH_PROBE_ZOOM="$ISSUE64_ZOOM" FLUX_MATH_PROBE_THEME="$ISSUE64_THEME" "$ISSUE64_RUN/probe" 'flux-renderer://bundle/index.html' "$PROJECT_ROOT/web-renderer/dist" "$PROJECT_ROOT/scripts/issue64/math-layout.js" "$ISSUE64_RUN/input.json" 45 > "$ISSUE64_RUN/layout-$ISSUE64_WIDTH-$ISSUE64_ZOOM-$ISSUE64_THEME.json" 2> "$ISSUE64_RUN/layout-$ISSUE64_WIDTH-$ISSUE64_ZOOM-$ISSUE64_THEME.log"
        done
    done
done
python3 scripts/issue64/asset-closure.py > "$ISSUE64_RUN/asset-closure.json"
"$ISSUE64_RUN/probe" 'flux-renderer://bundle/index.html' "$PROJECT_ROOT/web-renderer/dist" "$PROJECT_ROOT/scripts/issue64/asset-closure.js" "$ISSUE64_RUN/asset-closure.json" 60 > "$ISSUE64_RUN/asset-runtime.json" 2> "$ISSUE64_RUN/asset-runtime.log"
python3 - "$ISSUE64_RUN" <<'PY'
from pathlib import Path
import json, shutil, subprocess, sys
out=Path(sys.argv[1]);fault=out/'missing-glyph-bundle'
shutil.copytree('web-renderer/dist',fault)
modules=json.loads((out/'asset-closure.json').read_text())['modules']
missing=next(name for name in modules if Path(name).name.startswith('double-struck-'))
(fault/missing).unlink()
result=subprocess.run([sys.executable,'scripts/issue64/asset-closure.py',str(fault)],capture_output=True,text=True)
assert result.returncode and 'Missing or escaping bundled resource' in result.stderr,'Missing glyph escaped static verification'
(out/'asset-fault-static.log').write_text(result.stderr)
PY
if "$ISSUE64_RUN/probe" 'flux-renderer://bundle/index.html' "$ISSUE64_RUN/missing-glyph-bundle" "$PROJECT_ROOT/scripts/issue64/asset-closure.js" "$ISSUE64_RUN/asset-closure.json" 30 > "$ISSUE64_RUN/asset-fault-runtime.json" 2> "$ISSUE64_RUN/asset-fault-runtime.log"; then
    printf 'Missing glyph escaped native module verification\n' >&2
    exit 1
fi
if ! rg -qi 'Importing a module script failed|Failed to fetch dynamically imported module|error loading dynamically imported module' "$ISSUE64_RUN/asset-fault-runtime.log"; then
    printf 'Native glyph fault failed for an unexpected reason\n' >&2
    exit 1
fi
FLUX_MATH_PROBE_FEEDBACK_RECORDING=1 "$ISSUE64_RUN/probe" 'flux-renderer://bundle/index.html' "$ISSUE64_RUN/missing-glyph-bundle" "$PROJECT_ROOT/scripts/issue64/resource-failure.js" "$ISSUE64_RUN/asset-closure.json" 30 > "$ISSUE64_RUN/resource-failure.json" 2> "$ISSUE64_RUN/resource-failure.log"
"$ISSUE64_RUN/probe" 'flux-renderer://bundle/index.html' "$PROJECT_ROOT/web-renderer/dist" "$PROJECT_ROOT/scripts/issue64/production-corpus.js" "$ISSUE64_RUN/input.json" 90 > "$ISSUE64_RUN/production.json" 2> "$ISSUE64_RUN/production.log"
python3 - "$ISSUE64_RUN" <<'PY'
from pathlib import Path
import json,sys
out=Path(sys.argv[1]);result=json.loads((out/'production.json').read_text());html=result.pop('html');(out/'export.html').write_text(html)
assert '<head>' in html
csp='<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; style-src \'unsafe-inline\'; img-src data:; font-src \'none\'">'
(out/'offline.html').write_text(html.replace('<head>','<head>'+csp,1))
(out/'production-summary.json').write_text(json.dumps(result,indent=2)+'\n')
PY
"$ISSUE64_RUN/probe" 'flux-renderer://bundle/offline.html' "$ISSUE64_RUN" "$PROJECT_ROOT/scripts/issue64/offline-export.js" "$ISSUE64_RUN/input.json" 30 > "$ISSUE64_RUN/offline.json" 2> "$ISSUE64_RUN/offline.log"
python3 - "$ISSUE64_RUN" <<'PY'
from pathlib import Path
import json,sys,subprocess,hashlib
out=Path(sys.argv[1]);assert 'CSP ' not in (out/'offline.log').read_text(),'Offline export requested blocked resources'
report={'sourceCommit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'platform':subprocess.check_output(['sw_vers','-productVersion'],text=True).strip(),'architecture':subprocess.check_output(['uname','-m'],text=True).strip(),'bundleIndexSha256':hashlib.sha256(Path('web-renderer/dist/index.html').read_bytes()).hexdigest(),'production':json.loads((out/'production-summary.json').read_text()),'offline':json.loads((out/'offline.json').read_text()),'notCovered':['actual selected App/QuickLook/Finder UI','minimum macOS/Intel','VoiceOver speech','PDF visual inspection','memory acceptance','independent reviewer sign-off']}
report['assetClosure']={'static':json.loads((out/'asset-closure.json').read_text()),'native':json.loads((out/'asset-runtime.json').read_text()),'missingGlyphDetected':{'static':True,'native':True}}
report['resourceFailure']=json.loads((out/'resource-failure.json').read_text())
report['mathResourceBoundary']=json.loads((out/'math-resource-boundary.json').read_text())
report['mathResourceBoundary']['sentinelResourceRequests']=(out/'math-resource-boundary.log').read_text().count('FORBIDDEN_MATH_RESOURCE_REQUEST')
report['mathResourceHTTP']=json.loads((out/'http-resource-boundary/report.json').read_text())
report['mathLayout']=[case for path in sorted(out.glob('layout-*.json')) for case in json.loads(path.read_text())['cases']]
report['worktreeDirty']=bool(subprocess.check_output(['git','status','--porcelain'],text=True).strip())
report['validationSourceHashes']={name:hashlib.sha256(Path(name).read_bytes()).hexdigest() for name in ['scripts/test-issue64-math.sh','scripts/issue64/asset-closure.py','scripts/issue64/asset-closure.js','scripts/issue64/resource-failure.js','scripts/research/issue64-math/main.swift','web-renderer/vite.config.ts']}
(out/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('PASS current-machine renderer and standalone-HTML end-to-end checks')
print('Evidence:',out)
print('Remaining gates:',', '.join(report['notCovered']))
PY
