## 1. Investigation and design
- [x] 1.1 Re-read issue and comments; preserve the original attachment, assets and hashes.
- [x] 1.2 Inventory all sections and define the 13 mathematical items with expected validity.
- [x] 1.3 Evaluate the suggested page's pinned source and current engine alternatives.
- [x] 1.4 Run isolated real MathJax Node and local-scheme WKWebView probes; record limitations.
- [x] 1.5 Write implementation design, independent verification strategy and rewritten task.
- [x] 1.6 Confirm the design requirements and proceed with detailed design (user instruction, 2026-11-04).
- [x] 1.7 Specify module interfaces, parser/label/session contracts, output policy and implementation batches.
- [x] 1.8 Review the detailed design before product implementation (user authorized implementation and end-to-end verification as the active goal).

## 2. Freeze acceptance and engine integration
- [x] 2.1 Author source-based expectations and create/visually inspect an independent Tectonic/XeTeX + amsmath reference, including an offline two-pass rebuild.
- [x] 2.2 Compare SVG/CHTML with the same assistive-MathML profile on current native WebKit and local assets.
- [x] 2.3 Measure 20 fresh-process and 30 warm samples; freeze reference-hardware time, asset and DOM budgets.
- [x] 2.4 Select exact engine/font versions, package profile, SVG output, assistive MathML and no-Worker policy in the design.
- [x] 2.5 Obtain independent human review of the original-case expectations/reference: user explicitly confirmed M01–M13 as consistent in the three-column packet. Scope and exact page hash are recorded in output/pdf/issue64-review/human-review.json; no separate human approval of supplemental contracts is implied.
- [ ] 2.6 Validate actual VoiceOver and WebContent memory; freeze environment-specific limits. Minimum-system/physical Intel validation explicitly waived by user on 2026-11-05; compatibility remains unverified.
- [x] 2.7 Verify the production modular build and full runtime asset closure: current WebKit loads all 40 SVG glyph modules; Vite manifest/resource/license checks and missing-glyph fault injection pass. Minimum-platform compatibility remains in 2.6.

## 3. Parsing and document semantics
- [x] 3.1 Add failing tests for all delimiters/math fences and protected source regions.
- [x] 3.2 Implement source-preserving math tokens and lazy module activation, including MathML and selected AMS environments.
- [x] 3.3 Add failing tests for tags, references, forward/duplicate/missing targets, macros and render-generation isolation.
- [x] 3.4 Implement one document-scoped engine session, reference validation, unique IDs and stale-work disposal (native-memory acceptance remains in 2.6/5.5).

## 4. Product integration
- [x] 4.1 Verify and integrate output sanitization, self-contained SVG glyph paths and standard accessible reference links (actual VoiceOver remains in 5.3).
- [x] 4.2 Implement math styling, RTL isolation, narrow/native-zoom behavior, source copy and search/outline integration; current native geometry and trusted keyboard scrolling verified. Host/platform/VoiceOver acceptance remains in 5.2/5.3.
- [x] 4.3 Preserve the stored math toggle; update supported language labels and shared contextual error feedback inventory (native activation acceptance remains in 5.2/5.3).
- [x] 4.4 Await math and resources for App/CLI export; verify standalone HTML offline and actual CLI PDF structure/rasters. Remaining host/viewer/VoiceOver acceptance is tracked in 5.2/5.3.

## 5. Independent acceptance
- [x] 5.1 Run semantic/LaTeX-reference checks and sanitizer tests with real dependencies; clean cached-only two-pass TeX rebuild matches archived labels and reviewed rasters.
- [ ] 5.2 Validate native App, QuickLook and Finder on the current system, themes, widths and repeated document lifecycle (old-system/physical Intel runtime waived by user).
- [ ] 5.3 Review screenshots, geometry, real keyboard and VoiceOver behavior; inspect exported HTML/PDF independently.
- [x] 5.4 Run seeded Unicode-label/permutation properties and fault injection. Wrong reference numbers, deleted glyph assets, removed export waits and forbidden mathematical image requests are detected; production mutations restored.
- [ ] 5.5 Run full original-document regression, existing Typst/diagram checks and frozen performance gates.
- [ ] 5.6 Record final evidence, supported boundaries, rollback and release notes; commit verified work items.
