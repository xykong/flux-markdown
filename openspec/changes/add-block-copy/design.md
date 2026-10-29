## Decisions
Use an isolated renderer module, snapshot code before line-number decoration, and extract quote text by semantic DOM traversal. Keep source text in memory only. Native writing uses NSPasteboard through one shared bridge implementation, with document generation and bounded messages. No browser clipboard fallback or automatic writes. Clipboard success requires native acknowledgement. Use the existing error registry for copy incidents.

Code is the parser-produced text (Markdown line-ending normalization applies), with trailing newline preserved. Quote paragraphs use blank lines; list items use newlines, links retain visible labels, images retain alt text, and alert titles remain readable. Nested bodies occur once. Diagram output is excluded from code targeting. Quotes are copied expanded semantically even when descendants are folded. Buttons remain keyboard discoverable.

App settings update through the existing observed render path. Quick Look reads the setting at each render/open (already-open previews need reload); do not claim live cross-process propagation. HTML export removes controls; print CSS hides them.

## Verification
Handwritten expected text fixtures; JS lifecycle/failure tests; native validation tests and clipboard readback; build both targets; run real WebKit and attempt actual Quick Look GUI verification. Record inaccessible environment checks honestly. Compare large-document installation cost with setting off/on. Never use implementation-generated expected strings.

## Hover refinement (user requested 2026-10-29)
Use CSS hover/focus-within on each code host or quote/alert and opacity transitions (600 ms exit delay, 250 ms fade). Keep layout space to avoid text movement; invisible idle controls ignore pointer events but remain keyboard-focusable. A bounded data-copy-state pins pending/success/error feedback visible. Reduced motion removes animation; non-hover inputs keep controls visible. App and QuickLook share this CSS. The observed missing QuickLook buttons came from the installed older extension while the user ran the newer DerivedData app; update the local installation consistently after validation.
