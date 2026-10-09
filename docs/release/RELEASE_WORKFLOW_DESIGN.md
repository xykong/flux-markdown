# Fork Release Workflow

## Scope and attribution

This workflow serves an unofficial personal fork of xykong's FluxMarkdown.
It preserves upstream history, copyright, and contributor attribution.
It does not update upstream releases, signing keys, appcasts, or Homebrew taps.

## Version ownership

`.version` contains the numeric native version.
The release script derives its build component from the release commit count.
The version and dated changelog belong to the tagged commit.
Fork tags use `v<VERSION>-xluffy.1`.
The app and extension display `<VERSION>-xluffy.1` without changing their bundle identifiers.

## Build ownership

GitHub's `macos-15` ARM64 runner builds the exact tagged commit.
Renderer dependencies come from `npm ci` and the committed lockfile.
Native builds use project-local `build/DerivedData`.
Packaging reads only that checkout's Release application.
It cannot select an unrelated application from global DerivedData.

## Verification and publication

The build verifies the actual app and extension signatures and entitlements.
It rejects updater configuration, updater permissions, missing license notices, and embedded Sparkle.
Renderer and native tests run before the publish job.
The source archive contains matching repository source and installed renderer runtime dependencies.
The publish job receives only verified build artifacts.
Only the publish job has repository write permission.
Manual workflow runs upload artifacts without publishing a release.

Published tags and assets are immutable.
Existing releases are not deleted or replaced by this workflow.
A changed source tree requires a new version.

## Installation ownership

Nix pins one fork DMG version and content hash.
Home Manager installs that artifact.
The application does not update itself.
This avoids two competing update mechanisms.

## Signing limit

Current personal releases use ad-hoc signatures.
They are not Developer ID signed or notarized.
Notarized public distribution requires the fork maintainer's own Apple credentials.
