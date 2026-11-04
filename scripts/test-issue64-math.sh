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
scripts/test-renderer-webkit.sh > "$ISSUE64_RUN/native-suite.log" 2>&1
swiftc Sources/Shared/RendererBundleSchemeHandler.swift scripts/research/issue64-math/main.swift -o "$ISSUE64_RUN/probe"
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
(out/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('PASS current-machine renderer and standalone-HTML end-to-end checks')
print('Evidence:',out)
print('Remaining gates:',', '.join(report['notCovered']))
PY
