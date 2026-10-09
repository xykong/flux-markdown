#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
fail() { echo "Error: $*" >&2; exit 1; }

BUMP_TYPE=${1:-patch}
[ "$#" -le 1 ] || fail "Usage: make release [major|minor|patch]"
case "$BUMP_TYPE" in major|minor|patch) ;; *) fail "Use major, minor, or patch." ;; esac

# Never publish to upstream, a sibling repository, or an extra push URL.
verify_origin() {
    local url
    while IFS= read -r url; do
        case "$url" in
            git@github.com:xluffy-fork/flux-markdown.git|https://github.com/xluffy-fork/flux-markdown.git|https://github.com/xluffy-fork/flux-markdown|ssh://git@github.com/xluffy-fork/flux-markdown.git) ;;
            *) fail "Origin must be xluffy-fork/flux-markdown; found: $url" ;;
        esac
    done < <(git remote get-url --push --all origin)
    url=$(git remote get-url origin) || fail "Missing origin remote."
    case "$url" in
        git@github.com:xluffy-fork/flux-markdown.git|https://github.com/xluffy-fork/flux-markdown.git|https://github.com/xluffy-fork/flux-markdown|ssh://git@github.com/xluffy-fork/flux-markdown.git) ;;
        *) fail "Origin fetch URL must identify xluffy-fork/flux-markdown." ;;
    esac
}
verify_origin
[ -z "$(git status --porcelain --untracked-files=all)" ] || fail "Release requires a clean working tree."
[ "$(git rev-parse --is-shallow-repository)" = false ] || fail "Fetch full history before releasing."
BRANCH=$(git symbolic-ref --quiet --short HEAD) || fail "Release requires a branch, not detached HEAD."
[ -f .github/workflows/release.yml ] || fail "Missing tag-triggered release.yml workflow."

CURRENT_VERSION=$(cat .version)
[[ "$CURRENT_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || fail "Invalid numeric three-part .version."
major=$((10#${BASH_REMATCH[1]}))
minor=$((10#${BASH_REMATCH[2]}))
# The release commit itself contributes one commit to the build component.
build=$(( $(git rev-list --count HEAD) + 1 ))
case "$BUMP_TYPE" in
    major) major=$((major + 1)); minor=0 ;;
    minor) minor=$((minor + 1)) ;;
    patch) ;;
esac
VERSION="$major.$minor.$build"
TAG="v${VERSION}-xluffy.1"
! git show-ref --verify --quiet "refs/tags/$TAG" || fail "Tag already exists locally: $TAG"
REMOTE_TAG=$(git ls-remote --tags origin "refs/tags/$TAG" "refs/tags/$TAG^{}") || fail "Cannot check remote tags."
[ -z "$REMOTE_TAG" ] || fail "Tag already exists on origin: $TAG"

# Validate the changelog before either tracked file changes. Replace files
# atomically from same-directory temporary files; preserve all release notes.
python3 - "$VERSION" <<'PY'
import datetime
import os
from pathlib import Path
import re
import sys
import tempfile

version = sys.argv[1]
changelog = Path('CHANGELOG.md')
content = changelog.read_text(encoding='utf-8')
headers = list(re.finditer(r'^## \[Unreleased\][ \t]*$', content, re.MULTILINE))
if len(headers) != 1:
    raise SystemExit('Error: CHANGELOG.md must have exactly one [Unreleased] heading.')
if re.search(r'^## \[' + re.escape(version) + r'\]', content, re.MULTILINE):
    raise SystemExit('Error: Changelog already contains this version.')
header = headers[0]
updated = (content[:header.start()] + '## [Unreleased]\n\n## [' + version + '] - '
           + datetime.date.today().isoformat() + content[header.end():])
pending = []
try:
    for path, text in ((changelog, updated), (Path('.version'), version + '\n')):
        fd, name = tempfile.mkstemp(prefix='.' + path.name + '-', dir='.')
        pending.append((name, path))
        with os.fdopen(fd, 'w', encoding='utf-8') as stream:
            stream.write(text)
        os.chmod(name, path.stat().st_mode & 0o777)
    for name, path in pending:
        os.replace(name, path)
finally:
    for name, _ in pending:
        if os.path.exists(name):
            os.unlink(name)
PY

git add -- .version CHANGELOG.md
git commit -m "chore(release): prepare $TAG"
[ "$(git rev-list --count HEAD)" = "$build" ] || fail "Release commit count changed unexpectedly; nothing pushed."
git tag "$TAG"
verify_origin
# Atomic push rejects conflicts without updating either remote ref. Never force.
git push --atomic origin "HEAD:refs/heads/$BRANCH" "refs/tags/$TAG:refs/tags/$TAG"
echo "Pushed $TAG to xluffy-fork/flux-markdown."
echo "The tag-triggered release.yml workflow builds and verifies the ad-hoc ARM64 DMG."
echo "No local binaries were uploaded; no Developer ID signing or notarization is claimed."
echo "Workflow: https://github.com/xluffy-fork/flux-markdown/actions/workflows/release.yml"
