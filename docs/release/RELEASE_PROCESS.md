# Fork Release Process

This is an unofficial personal maintenance fork of [FluxMarkdown](https://github.com/xykong/flux-markdown).
Credit xykong and all original contributors in every release.
Preserve original copyright, license documents, and commit authorship.
Do not publish fork changes to the upstream repository or its Homebrew tap.

## Develop a change

1. Create a feature branch in `xluffy-fork/flux-markdown`.
2. Implement the change and keep suitable regression coverage.
3. Run renderer tests and native tests through CI.
4. Exercise the actual application and Finder QuickLook.
5. Record the change and contributor credit under `[Unreleased]` in `CHANGELOG.md`.
6. Commit the verified change with a Conventional Commit message.

The existing YAML date fix retains its original authorship and [upstream PR #56](https://github.com/xykong/flux-markdown/pull/56).
A fork release does not mean that upstream accepted this change.

## Build without publishing

Local builds require full Xcode, Node.js 20, XcodeGen, and `create-dmg`.
Run `make dmg` from the repository root.
The output is `build/artifacts/FluxMarkdown.dmg`.
Builds use this checkout's `build/DerivedData` directory.

If full Xcode is unavailable, push the committed source to the fork and run:

```bash
gh workflow run release.yml --repo xluffy-fork/flux-markdown --ref master
```

The manual workflow builds, tests, and uploads artifacts without creating a release.
Download its artifacts with `gh run download` after the run succeeds.

## Publish a release

Start from a clean branch checkout with full Git history.
Verify that `origin` identifies `xluffy-fork/flux-markdown`.
Do not change `.version` manually.

```bash
make release patch
```

Use `minor` or `major` only when the release requires that version change.
The script derives the build number from the release commit count.
It commits `.version` and the dated changelog before it creates the tag.
The tag format is `v<VERSION>-xluffy.1`.
The numeric native version remains in `.version`.
The application displays `<VERSION>-xluffy.1` to identify the fork.

The script pushes the branch and tag atomically to the fork.
GitHub's macOS ARM64 runner builds the tagged source.
It verifies signatures, sandbox entitlements, license resources, and absence of the in-app updater.
Renderer and native tests must pass before publication.

Each release contains:

- `FluxMarkdown.dmg`.
- `FluxMarkdown-source.tar.gz`, with matching source and installed renderer runtime dependencies.
- `SHA256SUMS`, with checksums for both archives.

Release notes identify the unofficial fork and credit upstream.
Do not replace a published tag or asset.
For a failed build, rerun the unchanged workflow or prepare a new version for source changes.

## Signing and updates

These personal ARM64 builds use ad-hoc signatures.
They are not Developer ID signed or notarized.
Do not use upstream signing identities or claim upstream endorsement.
Public notarized distribution requires your own Apple signing setup.

Nix/Home Manager is the only update mechanism.
The application does not contain Sparkle, an update feed, or a manual update command.
Homebrew and MacPorts documents retained from upstream are historical references.
They are not this fork's automated distribution path.

## Install through nix-config

After publication, update `../nix-config/pkgs/flux-markdown.nix`.
Set the fork release version, fork download URL, and published DMG hash.
Keep the bundle name `FluxMarkdown.app`.
No extra Home Manager package wiring is required.

From `nix-config`, run:

```bash
just check
nix build .#flux-markdown
just switch
```

Launch the installed app once, then verify the feature in Finder QuickLook.
Do not leave another installation with the same bundle identifiers active.
Use `make install` only for deliberate development installs outside Home Manager.
