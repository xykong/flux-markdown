# Document history, path copying and Mermaid sizing

Baseline: 2026-11-08, clean master. User reports history lost during development/updates and oversized Mermaid diagrams in fullscreen.

## Evidence and hypotheses (before implementation)
- `DocumentGroup` delegates recent documents entirely to `NSDocumentController`; no app-owned recent history exists.
- `scripts/install.sh` replaces the app and signs with `--sign -`. The installed app's designated requirement consists of build-specific CDHashes.
- The local system recent archive `com.xykong.markdown.sfl4` contains `com.apple.LSSharedFileList.DesignatedRequirement` with the installed binary's CDHash. Thus a stable bundle identifier alone does not give history a stable signing identity. Verify independently with disposable signed app builds; do not edit the user's system archive.
- Developer-ID to ad-hoc transitions also change identity. No evidence yet that same-identity production Sparkle updates erase history; do not claim that.
- Mermaid output is inserted without any app sizing policy. Different diagram types supply different width/max-width/font rules. Inspect rendered SVG and measured text, not screenshots alone.

## Acceptance metrics
1. History survives fresh process/build identity changes, preserves MRU order, deduplicates, caps length, migrates existing system entries, and respects explicit Clear Menu across restart. Missing/removable files are not silently deleted. Private paths never enter logs or diagnostics.
2. File menu and keyboard path copying target only the active saved document; clipboard receives a plain absolute path with Unicode/spaces intact, no URL encoding or shell quoting. Unsaved/no document is disabled.
3. Default Mermaid rendered label font does not exceed body font at narrow/wide widths. Small diagrams never stretch to document width; large diagrams fit available width with scrolling for manual zoom. Each diagram has independent bounded zoom and reset. Keyboard focus reveals controls; localization, export and copy exclude control text.
4. Run native persistence tests, renderer Jest/typecheck/build and real WKWebView integration; distinguish verified local runtime from untested macOS 11/released upgrade paths.

## Confirmed history cause and regression
A disposable app with a unique bundle identifier recorded one document. Restart under the same ad-hoc signature returned one document; changing only the bundle version and re-signing returned zero. The system archive's designated requirement contains the original CDHash. This reproduces development-build identity changes without touching user history.

`scripts/test-recent-document-history.sh` now proves the old system-only failure and the corrected path: migrate a populated system list, change signing identity, restart with history intact, remove the file without deleting its history, explicitly clear, change identity again, and observe an empty history. Three native XCTest cases also pass for MRU/deduplication/cap/clear and literal clipboard contents.

The fix stores a bounded host-only list in the stable preferences domain and creates a custom NSDocumentController before SwiftUI startup. It restores the system menu from that list; explicit clear writes an empty tombstone. It cannot recover entries already erased before the app-owned record exists. Migration uses the supported system document API while its history is still available; it does not parse or rewrite Apple's private archive format. Same-identity production Sparkle update loss is not reproduced or claimed.
