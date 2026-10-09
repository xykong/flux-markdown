---
name: publish
description: Publish a verified unofficial FluxMarkdown fork release through GitHub Actions.
model: animal-gateway/glm-5.1
---

# Publish a Fork Release

This checkout is an unofficial personal fork of xykong's FluxMarkdown.
Preserve original copyright, license documents, commit authorship, and contributor credit.
Do not publish to upstream or its Homebrew tap.
Do not use upstream signing identities or imply endorsement.

## Preconditions

- Read `docs/release/RELEASE_PROCESS.md`.
- Confirm that `origin` identifies `xluffy-fork/flux-markdown`.
- Require a clean branch checkout with full Git history.
- Verify feature behavior, renderer tests, native tests, and the actual application surface.
- Record changes and contributor credit under `[Unreleased]` in `CHANGELOG.md`.
- Keep `.version` numeric. Do not assign a build number manually.

## Release

Use `patch` unless the user specifies `minor` or `major`.
Run `make release patch`, or the selected bump type.
The script commits the version and dated changelog, then atomically pushes the branch and fork tag.
The tag-triggered workflow builds and verifies the ad-hoc ARM64 DMG before publication.
Watch that workflow and inspect failures rather than claiming success from the tag push.

A manual `release.yml` workflow run uploads build artifacts without publishing.
Use this path when local full Xcode is unavailable.

## Required release contents

- `FluxMarkdown.dmg`.
- Matching source and installed renderer runtime dependencies.
- Checksums for the binary and source archives.
- Release notes that identify the unofficial fork and credit upstream contributors.
- An explicit statement that the build is ad-hoc signed, not notarized.

Never overwrite a published tag or asset.
For changed source, prepare a new release version.
Do not restore Sparkle or update an appcast.
Do not modify sibling Homebrew repositories.

## Nix installation

Update the fork version, download URL, and DMG hash in `../nix-config/pkgs/flux-markdown.nix`.
Run `just check`, build `.#flux-markdown`, and run `just switch` from `nix-config`.
Verify the installed display version, new feature, and Finder QuickLook.
Report only observed build, release, and installation results.
