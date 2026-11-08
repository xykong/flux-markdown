#!/usr/bin/env bash
# Developer comparison/rollback artifact; never installs or replaces an app.
set -euo pipefail
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
if [[ $# -ne 2 || ( "$1" != current && "$1" != legacy ) ]]; then
    printf 'Usage: %s current|legacy NEW_OUTPUT_DIRECTORY\n' "$0" >&2
    exit 2
fi
PROFILE="$1"
ARTIFACT=$(python3 - "$PROJECT_ROOT" "$2" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]).resolve();requested=Path(sys.argv[2]).expanduser()
if requested.exists() or requested.is_symlink():raise SystemExit('Output directory already exists; choose a new directory.')
out=requested.resolve()
if any(out==p or p in out.parents for p in [root/'web-renderer',root/'.git']):
    raise SystemExit('Choose an output directory outside web-renderer and .git, such as /tmp.')
print(out)
PY
)
mkdir "$ARTIFACT"
trap 'printf "Backend build failed; inspect %s\n" "$ARTIFACT" >&2' ERR
cd "$PROJECT_ROOT"
if [[ "$PROFILE" == legacy ]]; then
    SOURCE_COMMIT=4844b1505e7116cc7b16e2a0cbe891c600d00180
    mkdir "$ARTIFACT/source"
    git archive "$SOURCE_COMMIT" web-renderer | tar -x -C "$ARTIFACT/source"
    RENDERER_SOURCE="$ARTIFACT/source/web-renderer"
    (cd "$RENDERER_SOURCE" && npm ci) > "$ARTIFACT/install.log" 2>&1
else
    SOURCE_COMMIT=$(git rev-parse HEAD)
    RENDERER_SOURCE="$PROJECT_ROOT/web-renderer"
fi
(cd "$RENDERER_SOURCE" && npm run build -- --outDir "$ARTIFACT/bundle") > "$ARTIFACT/build.log" 2>&1
python3 - "$PROFILE" "$ARTIFACT" "$SOURCE_COMMIT" "$RENDERER_SOURCE" <<'PY'
from pathlib import Path
import hashlib,json,subprocess,sys
profile,out,commit,source=sys.argv[1:];out=Path(out);source=Path(source)
digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
status=subprocess.check_output(['git','status','--porcelain','--','web-renderer'],text=True).strip() if profile=='current' else ''
report={'profile':profile,'sourceCommit':commit,'legacyRelease':'v1.42.645' if profile=='legacy' else None,'rendererWorkingTreeChanges':status.splitlines(),'packageLockSha256':digest(source/'package-lock.json'),'bundleIndexSha256':digest(out/'bundle/index.html'),'nodeVersion':subprocess.check_output(['node','--version'],text=True).strip(),'bundleDirectory':str(out/'bundle'),'scope':'Complete renderer version/configuration for developer comparison; no per-formula engine mixing and no installation. Legacy is not eligible for issue-64 feature acceptance.'}
(out/'profile.json').write_text(json.dumps(report,indent=2)+'\n')
PY
printf 'Built %s renderer profile: %s/bundle\n' "$PROFILE" "$ARTIFACT"
