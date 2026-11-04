# Issue 64 implementation log

## Authorization and baseline

The user activated the goal to implement the detailed design and complete end-to-end verification. Product implementation is authorized; the design review gate is satisfied. Starting commit: `02f0189`; initial worktree clean.

The full requirements remain in `docs/design/ISSUE_64_IMPLEMENTATION_DESIGN.md` and `openspec/changes/add-complete-math-rendering/`. No runtime, platform, export or accessibility acceptance gate is waived.

## First red baseline

Added 20 production-entry regression cases in `web-renderer/test/math-compatibility.test.ts` covering dollar/parenthesis/bracket forms, math fences, AMS equations, nested math blocks, protected source regions, real reference targets and local error recovery.

Command: `cd web-renderer && npm test -- --runInBand --silent test/math-compatibility.test.ts`.

Observed: **10 failed, 10 passed** before implementation. Failures are rendering/behavior assertions, not a test loader or compilation failure. This is an intentional red TDD checkpoint, not feature completion. Further original-corpus, identity, lifecycle, sanitizer and export tests remain required.

Next: implement source-preserving math token recognition and the document-level engine adapter, retaining these failing acceptance contracts until the behavior is implemented.

## Token layer checkpoint

Added `math-syntax.ts` with dollar/parenthesis inline rules, dollar/bracket block rules, math-fence recognition, source-item collection and escaped source placeholders. It is intentionally not connected to the production renderer until the document engine is ready. Sixteen dedicated syntax/protection tests pass; TypeScript validation passes.

The first production-entry baseline included an overstrict code-fence newline expectation: existing line-number presentation removes its final newline. Corrected that assertion without relaxing preservation of the actual code content. This leaves nine genuine production compatibility failures.

Still required in this layer: explicit AMS blocks and standalone refs, original line mapping through frontmatter/footnotes, table escaping, robust boundary/limit cases, opaque placeholder binding, and MathML collection. Do not mark task 3.2 complete from this checkpoint.

## Identity adapter checkpoint

Pinned production dependencies `@mathjax/src` and `@mathjax/mathjax-newcm-font` to 4.1.3. Added a single registered AMS identity adapter with per-document state, null-prototype label dictionaries, injective UTF-8 label encoding, separate unnamed-row identities and a 256-byte label limit. Kept upstream numbering, forward recompilation and duplicate-label errors.

Eight real-engine tests pass. A controlled replacement of the adapter with the upstream AMS tag implementation makes five identity tests fail; the adapter was restored immediately afterward. This establishes that the tests detect the documented upstream identity defects.

Typecheck passed. Jest's CommonJS test type resolution now maps MathJax's exported js paths to the package's CJS declarations. The other renderer suites plus the new syntax/identity suites pass: **49 suites, 440 tests**. This command explicitly excluded the still-red `math-compatibility.test.ts`; it is not a full feature acceptance result.

Next: browser SVG/MathML document rendering, local dynamic font data, output sanitization, unresolved-reference detection and integration with the production entry. The new identity module is not yet connected to that entry.

## Mathematical output sanitization checkpoint

Added the math-specific profile to the existing shared `safe-html.ts`. The prior document profile fails the new glyph/container preservation test (one failure, three passing safety cases). The new profile passes all four cases while retaining exact allowed MathJax containers, auxiliary MathML and local glyph references. It rejects active content, external/ambiguous/missing glyph definitions and unsafe links; document-level reference validity remains the engine/session's responsibility.

Seventeen math-output/existing-sanitizer tests and typecheck pass. The actual research-engine output also retains all 13 containers, 152 glyph uses, 102 paths and one reference through the new profile. The prior document and diagram profiles remain unchanged. Runtime-generated stylesheet handling and native visual verification still require integration; these structure checks alone are not visual acceptance.

## Browser document engine checkpoint

Added `math-engine.ts`: a fresh document-scoped TeX engine processes a staged set of math sources, generates SVG plus assistive MathML, checks reference targets against the same staged document, returns sanitized per-source output/diagnostics, and disposes its staging tree. Added an explicit Vite dynamic-font module allowlist, with no arbitrary network/package loader.

Two new tests exercise the actual browser-adaptor engine in JSDOM (only Vite's font-loader hook is stubbed), including forward targets and unresolved-reference isolation. Fourteen engine/identity/output tests and typecheck pass. Jest now resolves the font package's internal references to its CommonJS files rather than mixing ESM and CommonJS module instances.

Remaining before publication: replace fixed staging width with actual document metrics, preserve generation and opaque source binding, collect raw MathML, install/export all required styles, exercise dynamic glyph chunks in the real built WebKit renderer, apply limits and translate errors through the shared feedback flow. The production entry still uses the previous engine until this integration is complete.

## Production-entry integration checkpoint

The main Markdown entry now uses the token layer and dynamically loads the document engine when enabled and needed. Per-render random source tickets bind output only to uniquely matched placeholders; generation checks guard all asynchronous publication. Added standalone AMS equation/align/gather block recognition and paragraph ref/eqref recognition. Math errors join the existing feedback selector and keep recovery controls outside inline mathematical content.

All 20 original production-entry compatibility checks pass, along with the 16 syntax checks. Production Vite build succeeds. A real WKWebView using the production bundle and bundle-scheme handler renders the original section 10: **12 math items, 12 assistive MathML trees, one intentional unknown-command error, zero unprocessed placeholders, and a valid reference target**. This checks the 11 valid TeX items plus the invalid control; raw section-9 MathML is not yet part of this acceptance.

Full Jest run: **52 suites, 466 tests passed**. Updated the KaTeX-specific audit assertion to require SVG plus a semantic fraction; the active-HTML test still checks document content and additionally ensures malicious style text was never installed in the head. Engine-owned styles are allowed there.

Remaining: full MathML input, parser edge cases/source ordering, resource and input limits, metric-aware staging, needed-font readiness, export error gating, localized settings/diagnostics, source-copy/search/RTL integration, native full-corpus visual and host/export validation. No release or final completion claimed.

## Original MathML and export-error checkpoint

Added native MathML collection after document sanitization, with protected code/pre regions excluded. The same document engine now accepts TeX and MathML input. Disabling enhanced mathematics leaves native MathML presentation and literal TeX intact.

The exact original math section plus its section-9 MathML now yields **13 mathematical outputs and assistive trees, exactly one intentional error, and one valid equation reference target** both through the production-entry tests and through the built bundle in real WKWebView. Currency/code protection is asserted separately. The new raw-MathML acceptance test failed before the implementation and passes afterward.

Export readiness now rejects mathematical failures and unresolved references; a red-before/green-after test verifies rejection and subsequent recovery on a valid document. This does not yet cover waiting for in-flight mathematics or all post-layout font behavior.

Full Jest: **52 suites, 470 tests passed**; typecheck and production build pass. Remaining acceptance includes parser edge/source ordering, limits, actual layout metrics, comprehensive export readiness/standalone output, localization, search/copy/RTL, real host visuals and minimum-platform checks.

## Export lifecycle checkpoint

Two new production-entry tests failed before the change: an export started immediately could observe the previous document; a document replacement during resource waiting did not reject the stale export. `window.waitForExportReady` now awaits the current render under the same overall deadline, checks the captured render generation, and passes that check through resource readiness.

Font readiness forces layout before awaiting fonts and rechecks after layout; bounded settling avoids assuming an earlier ready promise covers later font requests. The image-event test now waits one event-loop turn for render waiting and listener registration before simulating a load; its completion assertion is unchanged.

Full Jest: **53 suites, 472 tests passed**; typecheck and build pass. A production-bundle WKWebView immediate-export probe returns two mathematical outputs, two assistive trees, a valid fragment target and no runtime script in serialized HTML. This is structural export evidence, not yet an independent offline reopening/PDF visual acceptance.

## Layout metrics checkpoint

The engine now derives staging width from the active preview's content box and inherits its font size/family/weight instead of always measuring at 800px/18px. The isolated measurement root has an explicit marker and is removed after completion. A new test verifies width, font, accessibility exclusion and cleanup.

Added shared math styles for LTR isolation in RTL prose, bounded display-block scrolling, keyboard focus indication and print block preservation. Actual WKWebView with a 280px preview and Arabic interface reports LTR mathematical content, no remaining measurement root, and formula heights of 21.59px at 16px text and 41.67px at 32px text. This is geometry evidence, not a complete visual/accessibility review.

Production build and all **53 suites / 473 tests** pass. Per-container/heading metrics, live resize without re-render, oversized print content and the broader visual matrix still require acceptance.
