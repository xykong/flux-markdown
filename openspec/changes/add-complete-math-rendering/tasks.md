## 1. Investigation and design
- [x] 1.1 Re-read issue and comments; preserve the original attachment, assets and hashes.
- [x] 1.2 Inventory all sections and define the 13 mathematical items with expected validity.
- [x] 1.3 Evaluate the suggested page's pinned source and current engine alternatives.
- [x] 1.4 Run isolated real MathJax Node and local-scheme WKWebView probes; record limitations.
- [x] 1.5 Write implementation design, independent verification strategy and rewritten task.
- [ ] 1.6 Review and approve the proposal before product implementation.

## 2. Freeze acceptance and engine integration
- [ ] 2.1 Hand-review semantic/label/negative expectations and create an independent LuaLaTeX/amsmath reference.
- [ ] 2.2 Compare SVG/CHTML and explicit accessibility components on minimum/current supported WebKit with local assets.
- [ ] 2.3 Measure cold/warm/large-document baselines; freeze time, memory and package-size budgets before implementation.
- [ ] 2.4 Select and lock runtime packages/fonts, allowed extensions and Worker/CSP policy; verify zero remote dependencies.

## 3. Parsing and document semantics
- [ ] 3.1 Add failing tests for all delimiters/math fences and protected source regions.
- [ ] 3.2 Implement source-preserving math tokens and lazy module activation, including MathML and selected AMS environments.
- [ ] 3.3 Add failing tests for tags, references, forward/duplicate/missing targets, macros and render-generation isolation.
- [ ] 3.4 Implement one document-scoped engine session, reference validation, unique IDs and stale-work disposal.

## 4. Product integration
- [ ] 4.1 Verify and integrate output sanitization, local SVG definitions and standard accessible reference links.
- [ ] 4.2 Implement math styling, RTL isolation, narrow/zoom behavior, source copy and search/outline integration.
- [ ] 4.3 Preserve the stored math toggle; update supported language labels and shared contextual error feedback inventory.
- [ ] 4.4 Await math and resources for App/CLI export; produce offline standalone HTML and verify PDF/print behavior.

## 5. Independent acceptance
- [ ] 5.1 Run semantic/LaTeX-reference checks and sanitizer tests with real dependencies.
- [ ] 5.2 Validate native App, QuickLook and Finder, minimum/current systems, themes, widths and repeated document lifecycle.
- [ ] 5.3 Review screenshots, geometry, real keyboard and VoiceOver behavior; inspect exported HTML/PDF independently.
- [ ] 5.4 Run metamorphic/property/fault-injection tests and demonstrate that broken labels/assets/awaits are detected.
- [ ] 5.5 Run full original-document regression, existing Typst/diagram checks and frozen performance gates.
- [ ] 5.6 Record final evidence, supported boundaries, rollback and release notes; commit verified work items.
