# Nix-Managed Updates

This unofficial personal fork uses Nix/Home Manager for updates.
The original FluxMarkdown project remains at [xykong/flux-markdown](https://github.com/xykong/flux-markdown).
Original copyright, license documents, and contributor attribution remain intact.

## Update the application

1. Select a verified release from [the fork](https://github.com/xluffy-fork/flux-markdown/releases).
2. Update the release version and DMG hash in `nix-config/pkgs/flux-markdown.nix`.
3. Run `just check` and build `.#flux-markdown` from `nix-config`.
4. Run `just switch` after all checks pass.
5. Launch the installed application and test Finder QuickLook.

The displayed version includes `-xluffy.1` to identify the fork.
The app and extension retain their original bundle identifiers for this personal replacement.
Avoid another active installation with the same identifiers.

## No in-app update service

The fork does not include Sparkle or an update-check command.
It does not contact the upstream update feed.
No appcast, Sparkle private key, or Sparkle signing step is required.

## Release security

Personal releases use ad-hoc signatures and preserve App Sandbox entitlements.
They are not Developer ID signed or notarized.
macOS can require approval for a downloaded build.
A Nix hash verifies the selected asset's bytes; it is not an Apple notarization ticket.

See the [fork release process](../release/RELEASE_PROCESS.md) for build, verification, and license requirements.
