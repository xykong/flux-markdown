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

The fix stores a bounded host-only list in the stable preferences domain and supplies the File menu’s recent-document entries from that list. SwiftUI retains ownership of NSDocumentController. Explicit clear empties both app and system history and writes an empty tombstone. It cannot recover entries already erased before the app-owned record exists. Migration uses the supported system document API while its history is still available; it does not parse or rewrite Apple's private archive format. Same-identity production Sparkle update loss is not reproduced or claimed.

A real isolated SwiftUI app launch rejected the initial custom-controller approach: SwiftUI document registration looped before showing a window. Both disposable processes were terminated and the approach removed. The final design uses Commands plus observed history, leaving the system controller untouched. This is why testing a standalone AppKit controller alone was insufficient.

## Final verification
- Signed-process regression: system-only recent count changes from 1 to 0 after identity change; app-owned history preserves the entry, missing-file retention and explicit clear across fresh processes.
- Native `xcodebuild test`: 4 tests pass (history migration/restart/MRU/cap/deduplication, clipboard Unicode/punctuation, native window selection including settings and unsaved documents). Complete host/extension compilation succeeds. Local Xcode 27 uses the explicit macOS 12 build override; the project deployment target remains macOS 11.
- Renderer: 65 suites / 594 tests pass; TypeScript and production Vite build pass.
- Real WKWebView: full 34-case run passes. New checks cover flowchart, sequence, Gantt and class diagrams at 360/1600 CSS-pixel widths, measured label size, independent zoom/reset, keyboard focus visibility and HTML export. Foreground-only focus checks use the existing secondary-display window policy.
- Isolated copy of the actual SwiftUI app, with a separate bundle identifier and no embedded QuickLook plugin: both fixture documents open, app-owned history records both, and native accessibility menu activation copies each selected document's correct absolute path. The OS canonicalizes `/tmp` to `/private/tmp`; assertions compare the canonical fixture path. Previous clipboard data was held only in memory and restored after checks. Test apps were stopped; the installed app was not replaced.
- Actual window screenshot inspected: flowchart labels are smaller than body text and the small chart does not stretch across the document. Diagram labels and controls are accessible in the native WebView accessibility tree.

The path command observes native document-window selection rather than SwiftUI FocusedValue, which did not reliably enable the menu for an AppKit-backed view. Control labels are excluded from copied block text, search and exported HTML; print hides controls and constrains the SVG to the page width.

## Limits
No release was published and no installed app was replaced. Production Developer ID/Sparkle upgrade and macOS 11 runtime acceptance were not exercised. Very large diagrams still require document scrolling: automatic sizing prioritizes the body-font cap and available width rather than making every large graph unreadably small to fit one screen. Manual diagram zoom resets when the document is rerendered (for example on a theme change).
