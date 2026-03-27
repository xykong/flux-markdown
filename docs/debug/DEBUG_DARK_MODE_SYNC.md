# How Dark Mode Sync Works (File-Based Preference Sharing)

> **Note:** As of the macOS 26 (Tahoe) fix, App Groups are no longer used.
> See [#13](https://github.com/xykong/flux-markdown/issues/13) for background.

To make the **Main App**'s appearance setting apply to the **QuickLook Extension**, we use a shared plist file at `~/Library/Application Support/FluxMarkdown/shared-preferences.plist`.

## How It Works

1. `Sources/Shared/SharedPreferenceStore.swift`: File-based preference store that both processes can access.
2. The **main app** (unsandboxed) writes shared settings (theme, font, rendering toggles) to the plist.
3. The **QuickLook extension** (sandboxed) reads from that plist via its `temporary-exception.files.absolute-path.read-only` entitlement for `$HOME/`.
4. Both processes resolve the real home directory via `getpwuid(getuid())` to bypass sandbox container redirection.

## Settings Split

| Settings | Store | Shared? |
|----------|-------|---------|
| Theme, font size, code highlight, Mermaid/KaTeX/emoji, language | `SharedPreferenceStore` (plist file) | Yes — main app → extension |
| Zoom level, scroll positions, window sizes | `UserDefaults.standard` | No — per-process |

## Troubleshooting

- **Setting doesn't sync?**
  - Check that `~/Library/Application Support/FluxMarkdown/shared-preferences.plist` exists and contains your settings.
  - Open a new QuickLook preview (close and re-press Space) — the extension reads settings on launch.
  - Clean Build Folder (`Cmd+Shift+K`) and rebuild.

- **Plist file missing?**
  - Open FluxMarkdown.app and change any setting. The file is created on first write.
  - Check permissions: the directory must be writable by the main app.

## Previous Approach (Pre-Tahoe)

Previously, this used App Groups (`UserDefaults(suiteName: "group.com.xykong.Markdown")`).
This stopped working on macOS 26 because `containermanagerd` now requires a valid Apple Developer
Team ID prefix for App Group containers, and the app is ad-hoc signed.

On first launch after upgrading, existing preferences are automatically migrated from
the App Group UserDefaults to the new file-based store.
