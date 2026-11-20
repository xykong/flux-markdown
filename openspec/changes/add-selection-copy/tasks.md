## 1. Establish host behavior

- [x] 1.1 Investigate selection, Command-C, host Copy commands, the context menu and pasteboard behavior in Finder Space-bar Quick Look.
- [x] 1.2 Use the public native context-menu hook (`willOpenMenu`) in the Quick Look extension; keep WebKit's Copy and Command-C.
- [x] 1.3 Pin an HTML-to-Markdown converter (turndown 7.2.5 with the GFM plugin) and test it against partial selections, including tables.
- [ ] 1.4 Tell a resized Space-bar preview from a Finder pane; the current 700×500 size heuristic cannot.
- [x] 1.5 Investigate input loss in Quick Look after Speech and with the Ask Siri selection button (cause: any submenu of the selection menu, also in Apple's Mail preview; the Ask Siri button is not involved); confirm in Double Commander's Quick View that right-clicks never reach the preview.

## 2. Implement clipboard and conversion

- [x] 2.1 Tests for exact range extraction, ancestor formatting, cross-root and empty selections, hidden content and source-view gutters.
- [x] 2.2 Extract shared acknowledged clipboard transport with one ordered request-ID sequence; retain origin, generation and size validation.
- [x] 2.3 Separate selection-copy authorization from block-button visibility, retaining compact-preview restrictions.
- [x] 2.4 Implement plain-text and semantic Markdown selection conversion, including Quick Look source-view behavior and unsupported partial-content fallback.
- [x] 2.5 Leave Command-C and WebKit's Copy unchanged; route the menu's Copy as Markdown to the shared Markdown action.
- [x] 2.6 Require explicit expanded Quick Look capability in preview/source render paths; default off for app, compact and missing-context renders, and dispose on context exit.
- [x] 2.7 Register and authorize selection-copy requests only in the expanded Quick Look extension, sharing transport/write primitives without extending app block-copy authorization.
- [x] 2.8 Capture original-node metadata before cloning partial ranges; preserve ancestor formatting and exclude source-mode deleted diff lines.
- [x] 2.9 Explicitly gate this initial feature to Markdown; preserve current TSV and diagram-only mode behavior.
- [ ] 2.10 Tests for mixed block and selection request order, timeouts and late acknowledgements.

## 3. Add selection controls

- [x] 3.1 Add "Copy as Markdown" after WebKit's Copy in the Quick Look context menu in six languages; keep native hooks out of the app's WebView.
- [x] 3.6 Show Speech's items directly in the Quick Look extension's selection menu instead of its submenu.
- [x] 3.2 Add an accessible floating toolbar after selection completion, with plain-text and Markdown buttons; preserve the selection on activation and on right-click.
- [x] 3.3 Hide or reposition the toolbar on Escape, a new selection, pointer down, scrolling and resizing; dispose it with the render.
- [x] 3.4 Honor button visibility preferences; exclude controls from export and print output.
- [x] 3.5 Add acknowledged success and shared contextual error recovery/reporting; update the error-feedback coverage inventory.

## 4. Verify

- [x] 4.1 Run selection and existing block-copy renderer tests, typecheck and production build.
- [x] 4.2 Run native bridge/routing tests and build app and extension targets.
- [x] 4.3 Paste the text copied by the toolbar buttons and Copy as Markdown in real Finder Space-bar Quick Look and in Double Commander's F3 viewer.
- [x] 4.4 Real WebKit: the toolbar appears only in Quick Look, stays out of exports, and source view gets its own controller.
- [ ] 4.5 Finder checks for compact-preview exclusion, keyboard access, themes and RTL, and toolbar placement.
- [ ] 4.6 Measure selection cost on large documents and listener growth over 100 render and dispose cycles.
- [ ] 4.7 Define and test Markdown conversion rules for selected math.
