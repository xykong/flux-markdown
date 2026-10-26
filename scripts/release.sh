#!/bin/bash
set -euo pipefail

VERSION_FILE=".version"
CHANGELOG_FILE="CHANGELOG.md"
DMG_PATH="build/artifacts/FluxMarkdown.dmg"

if ! command -v gh &> /dev/null; then
    echo "❌ Error: 'gh' (GitHub CLI) is not installed."
    exit 1
fi

RESUME=false
if [ "${1:-}" = "--resume" ]; then RESUME=true; fi
BUMP_TYPE=${1:-minor}
if $RESUME; then BUMP_TYPE=patch; fi
if [ "$(git branch --show-current)" != "master" ]; then echo "Release requires master" >&2; exit 1; fi
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then echo "Commit tracked changes before release preparation" >&2; exit 1; fi

if [[ "$BUMP_TYPE" == "minus" ]]; then
    BUMP_TYPE="minor"
fi

if [[ "$BUMP_TYPE" != "major" && "$BUMP_TYPE" != "minor" && "$BUMP_TYPE" != "patch" ]]; then
    echo "❌ Error: Invalid bump type '$BUMP_TYPE'. Use major, minor, or patch."
    exit 1
fi

if [ ! -f "$VERSION_FILE" ]; then
    echo "1.0.0" > "$VERSION_FILE"
fi

CURRENT_FULL_VERSION=$(cat "$VERSION_FILE")
IFS='.' read -r major minor build <<< "$CURRENT_FULL_VERSION"

# Get current git commit count for build number alignment
COMMIT_COUNT=$(git rev-list --count HEAD)

if [[ "$BUMP_TYPE" == "major" ]]; then
    major=$((major + 1))
    minor=0
    build=$COMMIT_COUNT
    echo "🚀 Bumping Major Version: $CURRENT_FULL_VERSION -> $major.$minor.$build (aligned with commit #$COMMIT_COUNT)"
elif [[ "$BUMP_TYPE" == "minor" ]]; then
    minor=$((minor + 1))
    build=$COMMIT_COUNT
    echo "🚀 Bumping Minor Version: $CURRENT_FULL_VERSION -> $major.$minor.$build (aligned with commit #$COMMIT_COUNT)"
elif [[ "$BUMP_TYPE" == "patch" ]]; then
    build=$COMMIT_COUNT
    echo "🚀 Patch Version: $CURRENT_FULL_VERSION -> $major.$minor.$build (aligned with commit #$COMMIT_COUNT)"
fi

NEW_FULL_VERSION="$major.$minor.$build"

if $RESUME; then
    NEW_FULL_VERSION=$CURRENT_FULL_VERSION
    git rev-parse "v$NEW_FULL_VERSION^{commit}" >/dev/null
    [ "$(git show "v$NEW_FULL_VERSION:.version")" = "$NEW_FULL_VERSION" ] || exit 1
    git merge-base --is-ancestor "v$NEW_FULL_VERSION" HEAD
    if ! git diff --quiet "v$NEW_FULL_VERSION" -- Sources web-renderer project.yml Makefile scripts; then
        echo "Build inputs differ from the prepared tag; resume from an isolated checkout of that tag." >&2
        exit 1
    fi
    [ -f release_notes_tmp.md ] || { echo "Missing prepared release notes; recover them before resuming" >&2; exit 1; }
else
    if git rev-parse --verify "refs/tags/v$NEW_FULL_VERSION" >/dev/null 2>&1; then
        echo "Tag already exists. Use scripts/release.sh --resume to rebuild the prepared version." >&2
        exit 1
    fi
echo "🎯 Target Version: $NEW_FULL_VERSION"

echo "$NEW_FULL_VERSION" > "$VERSION_FILE"

echo "📝 Extracting user-facing release notes..."
RELEASE_NOTES_FILE="release_notes_tmp.md"

python3 -c "
import sys
import re

BLACKLIST = ['架构', 'Architecture', '内部', 'Internal', '构建', 'Build', '测试', 'Test', 'CI', 'Refactor']

def is_user_facing(line):
    match = re.search(r'\*\*(.*?)\*\*:', line)
    if match:
        scope = match.group(1)
        for b in BLACKLIST:
            if b in scope:
                return False
    return True

try:
    with open('$CHANGELOG_FILE', 'r', encoding='utf-8') as f:
        content = f.read()
    
    pattern = r'## \[Unreleased\]\n(.*?)(\n## \[|$)'
    match = re.search(pattern, content, re.DOTALL)
    
    if match:
        raw_notes = match.group(1).strip()
        filtered_lines = []
        for line in raw_notes.split('\n'):
            if line.strip().startswith('-'):
                if is_user_facing(line):
                    filtered_lines.append(line)
            else:
                filtered_lines.append(line)
        
        final_notes = re.sub(r'\n{3,}', '\n\n', '\n'.join(filtered_lines)).strip()
        print(final_notes)
    else:
        sys.stderr.write('Warning: No [Unreleased] section found.\n')
except Exception as e:
    sys.stderr.write(f'Error: {e}\n')
    sys.exit(1)
" > "$RELEASE_NOTES_FILE"

if [ ! -s "$RELEASE_NOTES_FILE" ]; then
    echo "⚠️ Warning: Release notes are empty. Continuing..."
    echo "No significant user-facing changes." > "$RELEASE_NOTES_FILE"
else
    echo "✅ Release notes extracted:"
    cat "$RELEASE_NOTES_FILE"
    echo "----------------------------------------"
fi

DATE_STR=$(date "+%Y-%m-%d")
TEMP_CHANGELOG=$(mktemp)
sed "s/^## \[Unreleased\]$/## [Unreleased]\\
_无待发布的变更_\\
\\
## [$NEW_FULL_VERSION] - $DATE_STR/" "$CHANGELOG_FILE" > "$TEMP_CHANGELOG"
mv "$TEMP_CHANGELOG" "$CHANGELOG_FILE"

echo "💾 Committing changes..."
git add "$VERSION_FILE" "$CHANGELOG_FILE"
if git ls-files --error-unmatch .build_number >/dev/null 2>&1; then
    git rm .build_number
fi
if git ls-files --error-unmatch scripts/increment_version.sh >/dev/null 2>&1; then
    git rm scripts/increment_version.sh
fi

git commit -m "chore(release): bump version to $NEW_FULL_VERSION"
git tag "v$NEW_FULL_VERSION"


fi
# Both first preparation and resume synchronize the existing tag before building.
git push origin master
git push origin "v$NEW_FULL_VERSION"
echo "🔨 Building project and DMG..."
if [ "${RELEASE_REMOTE_BUILD:-0}" = 1 ]; then
    RELEASE_APP_PATH=$(./scripts/build-release-remotely.sh "v$NEW_FULL_VERSION")
    export RELEASE_APP_PATH
fi
make dmg

if [ ! -f "$DMG_PATH" ]; then
    echo "❌ Error: DMG not found at $DMG_PATH"
    exit 1
fi

echo "📦 Building MacPorts source tarball..."
MACPORTS_TARBALL="build/artifacts/FluxMarkdown-${NEW_FULL_VERSION}-macports-source.tar.gz"
if ./scripts/create_macports_tarball.sh "$NEW_FULL_VERSION"; then
    echo "✅ MacPorts tarball created: $MACPORTS_TARBALL"
    if [ -f "macports/Portfile" ]; then
        git add macports/Portfile
        if ! git diff --cached --quiet; then
            git commit -m "chore(macports): update Portfile checksums for v$NEW_FULL_VERSION"
        fi
        git push origin master
        echo "✅ macports/Portfile committed"
    fi
else
    echo "❌ MacPorts tarball creation failed; release preparation stopped" >&2
    exit 1
fi

python3 scripts/release-manifest.py write
if [ "${RELEASE_PREPARE_ONLY:-0}" = 1 ]; then
    echo "Release artifacts prepared. Validate installation, then run scripts/publish-release.sh."
    exit 0
fi
./scripts/publish-release.sh
