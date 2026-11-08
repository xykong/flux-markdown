#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
if [[ $# -ne 2 ]]; then
    printf 'Usage: %s /path/to/FluxMarkdown.app NEW_EVIDENCE_DIRECTORY\n' "$0" >&2
    exit 2
fi
ISSUE64_APP="$1"
ISSUE64_EXPORT="$2"
mkdir "$ISSUE64_EXPORT"
ISSUE64_EXPORT=$(cd "$ISSUE64_EXPORT" && pwd)
trap 'printf "Product export validation failed; inspect %s\n" "$ISSUE64_EXPORT" >&2' ERR
cd "$PROJECT_ROOT"
codesign --verify --deep --strict "$ISSUE64_APP" > "$ISSUE64_EXPORT/signature.log" 2>&1
cmp web-renderer/dist/index.html "$ISSUE64_APP/Contents/Resources/dist/index.html"
python3 scripts/issue64/asset-closure.py "$ISSUE64_APP/Contents/Resources/dist" > "$ISSUE64_EXPORT/asset-closure.json"
python3 - "$ISSUE64_APP" <<'PY'
from pathlib import Path
import json,sys
current=Path('web-renderer/dist');packaged=Path(sys.argv[1])/'Contents/Resources/dist'
manifest=json.loads((current/'.vite/manifest.json').read_text())
files={'index.html','.vite/manifest.json'}
for entry in manifest.values():
    files.add(entry['file']);files.update(entry.get('css',[]));files.update(entry.get('assets',[]))
for name in files:
    if (current/name).read_bytes() != (packaged/name).read_bytes():
        raise SystemExit('Packaged renderer differs from current build: '+name)
PY
"$ISSUE64_APP/Contents/MacOS/FluxMarkdown" --export-pdf "$PROJECT_ROOT/docs/research/issue64/valid-original-syntax.md" "$ISSUE64_EXPORT/valid.pdf" > "$ISSUE64_EXPORT/valid.log" 2>&1
swift scripts/issue64/inspect-product-pdf.swift "$ISSUE64_EXPORT/valid.pdf" > "$ISSUE64_EXPORT/structure.json"
printf '%s\n' '$\unknownMarkdownPreviewCommand{x}$' > "$ISSUE64_EXPORT/invalid.md"
if "$ISSUE64_APP/Contents/MacOS/FluxMarkdown" --export-pdf "$ISSUE64_EXPORT/invalid.md" "$ISSUE64_EXPORT/invalid.pdf" > "$ISSUE64_EXPORT/invalid.log" 2>&1; then
    printf 'Invalid formula incorrectly allowed product PDF export\n' >&2
    exit 1
else
    ISSUE64_INVALID_EXIT=$?
fi
test ! -e "$ISSUE64_EXPORT/invalid.pdf"
python3 - "$ISSUE64_EXPORT" "$ISSUE64_APP" "$ISSUE64_INVALID_EXIT" <<'PY'
from pathlib import Path
import hashlib,json,subprocess,sys
out=Path(sys.argv[1]);app=Path(sys.argv[2]);digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
r={'sourceCommit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'worktreeDirty':bool(subprocess.check_output(['git','status','--porcelain'],text=True).strip()),'platform':subprocess.check_output(['sw_vers','-productVersion'],text=True).strip(),'architecture':subprocess.check_output(['uname','-m'],text=True).strip(),'fixtureSha256':digest(Path('docs/research/issue64/valid-original-syntax.md')),'bundleIndexSha256':digest(app/'Contents/Resources/dist/index.html'),'executableSha256':digest(app/'Contents/MacOS/FluxMarkdown'),'pdfSha256':digest(out/'valid.pdf'),'structure':json.loads((out/'structure.json').read_text()),'signatureVerified':True,'invalidExport':{'exitCode':int(sys.argv[3]),'outputCreated':False},'notCovered':['visual review of this PDF','PDF viewer interaction/VoiceOver','actual selected QuickLook/Finder extension','minimum operating system']}
r['assetClosure']=json.loads((out/'asset-closure.json').read_text())
(out/'report.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n')
PY
printf 'PASS actual product PDF export structure and invalid-input rejection: %s\n' "$ISSUE64_EXPORT"
