# Issue 64 final acceptance

Date: 2026-11-05. **Implementation and the agreed current-system acceptance are complete.** Production sources remain byte-for-byte equivalent to implementation commit `868237a`; experimental memory changes were not retained. The user approved M01–M13 and explicitly accepted the measured approximately 1.7G stress cost, instructing that optimization stop.

## Evidence and scope

| Requirement | Evidence | Result |
| --- | --- | --- |
| Original source, attachment and suggested solution | manifest.json, math-cases.json, design documents | Original fixtures/hashes preserved; suggested page and engine alternatives analyzed. |
| Original formulas and tags | acceptance-expectations.json; output/pdf/issue64-review/human-review.json | User marked M01–M13 consistent. Eleven valid TeX items and one MathML item render; M12 is intentionally invalid. |
| Delimiters, protected regions, source and document isolation | 557 renderer tests; final-e2e.json | Delimiters/fences, code/currency protection, CRLF/container source, scoped macros, stale work, labels and source-copy/search checks pass. |
| Independent semantics and references | Independent Tectonic reference, auxiliary files, semantic revalidation and seeded properties | Numbering/forward references/tag-star/duplicate/missing labels/Unicode cases have independent oracle and automated evidence. User sign-off is limited to the thirteen displayed review rows. |
| Safety and offline assets | final-e2e.json | All 40 SVG glyph modules load locally. Missing-asset, unsafe-resource and sanitizer fault checks pass, including zero mathematical HTTP image requests with a working positive control. |
| Actual native hosts | authorized-native-host-validation.json; finder-and-review-session.json; reference-toolbar-clearance.json | Candidate App, system-selected QuickLook extension and actual Finder compact preview exercised. Numbered links reach visible targets; the toolbar-overlap defect was fixed. |
| Geometry, themes and zoom | final-e2e.json | 72 native WebKit layout combinations cover three widths, two zooms, two native appearances, LTR/RTL and App/QuickLook/Finder renderer contexts. This is layered evidence alongside actual-host smoke checks, not a claim of every possible hardware combination. |
| Keyboard, source copy and recovery controls | Final 29-case native suite; 30 targeted native unit tests; DEBUG_ERROR_FEEDBACK.md | Trusted keyboard/copy/navigation, narrow recovery controls, context transport and stale-action rejection pass. Actual App export notice and translated controls are externally accessible. No issue report was submitted. |
| VoiceOver | voiceover-verified.json and caption PNGs | Actual VoiceOver generated mathematical speech text and supported structural exploration for valid original cases, matrices/cases and labelled link activation. Captions were inspected; physical speaker playback was not recorded. |
| HTML/PDF export | final-e2e.json; final-product-export.json | Offline HTML reopens without blocked resources; actual App valid PDF has two pages and an internal GoTo link. Invalid input produces no successful PDF. Both final PDF rasters equal the user-reviewed pages. |
| Timing/assets/DOM | current-performance-gates.json; final-e2e.json | Cold p95 141ms; warm 100/1000 p95 83/870ms; 1000-item DOM 8,809,288 bytes. Plain p95 12ms versus original 11ms, with zero math-module requests. Frozen gates pass. |
| WebContent memory | owned-process-memory-comparison.json; memory-acceptance.json | Three complete pairs show rounded peaks 1.7G current/1.0G original and lower current post-clear footprint. User explicitly accepts this measured stress cost. It is not a universal maximum-memory guarantee. Both versions report one 32-byte leak without product-specific attribution; no leak-free claim is made. |
| Regression | final-e2e.json | 557 tests and 29 native cases pass. Full original document retains 8 Mermaid, 1 Graphviz, 1 Vega and its end marker; one intentional math error is isolated. Existing Typst/diagram tests remain included. |
| Cleanup and rollback | current-validation-candidate.json; finder-and-review-session.json; final-product-export.json | Original installed App and installed-path registration restored; hashes/signature match backup. Test VoiceOver and owned probes stopped. Candidate remains staged separately. |

## Agreed boundaries

- macOS 11/physical Intel execution was explicitly waived by the user. No compatibility pass or platform-support change is inferred.
- The math dialect treats parenthesis/bracket delimiters as mathematics; the original attachment's escaped-parenthesis ambiguity is documented in the design. MathML is collected from sanitized presentation DOM.
- SVG remains the production output. The CHTML prototype comparison and all rejected memory experiments are research evidence, not shipped alternatives or per-formula fallbacks.
- Release, publication, an issue reply and the `done` label were not requested and were not performed.

## Delivery

Candidate: `build/issue64-host-validation/candidate-868237a.app`. Review packet: `output/pdf/issue64-review/index.html`. Final reproducible run: `build/issue64-validation/run.GFsKzW`. Development rollback/build profiles are documented in backend-build-profiles.json. Original backup remains `build/issue64-host-validation/installed-backup.app`.
