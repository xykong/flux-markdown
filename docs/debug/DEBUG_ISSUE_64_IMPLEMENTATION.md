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

## Input-budget checkpoint

Added a pre-engine partition enforcing 64 KiB per mathematical payload, 2 MiB cumulative admitted UTF-8 bytes and 5000 admitted items. Oversized individual expressions retain their original source and do not prevent later in-budget items from rendering; once the cumulative/count budget is exhausted, the remainder stays source-visible. Existing TeX macro/buffer limits remain in force. This bounds admitted input, not a claim of a hard synchronous-CPU timeout.

The real-engine oversized-input test fails before the gate and passes afterward. Four boundary tests cover exact byte limits, CJK UTF-8, total byte exhaustion and count exhaustion. Rejected items use the shared mathematical error path and six-language recovery guidance; existing export error gating rejects them. Input diagnostics do not add document source to bridge payloads.

Full Jest: **54 suites / 478 tests**; typecheck/build pass. Native limit recovery/report activation, parser pre-allocation limits, memory and stress acceptance remain to be completed.

## Non-destructive mathematical search checkpoint

Source text is now registered against rendered mathematical wrappers in a WeakMap, not DOM attributes or feedback payloads. Search treats each formula as a source-based match unit, excludes SVG/assistive text and feedback controls from ordinary text traversal, and adds an external outline rather than modifying mathematical children. Formula/prose matches retain document order. Clearing search preserves the exact mathematical innerHTML; export removes transient prose and formula highlights.

Two new tests fail before implementation and pass afterward, covering source commands, duplicate variable occurrences, untouched SVG/MathML, mixed prose navigation and export. Full Jest: **55 suites / 480 tests** and production build pass; a final source-order comparator refinement also passes focused search tests and typecheck. Native search keyboard/visual acceptance and source-copy functionality remain outstanding.

## Mathematical source-copy checkpoint

Extended the shared block-copy controller to registered math wrappers. Inline and display formulas copy their exact stored source, and blockquote copying reads mathematical source once instead of duplicated visual/assistive text. Math copy controls use the existing trusted-event requirement, native acknowledgement, byte cap, retry and contextual failure behavior. Inline controls use phrasing containers; exports remove their shared wrapper/tools as before.

On copy failure a readonly source textarea remains available for manual selection, rather than selecting SVG paths that cannot reproduce TeX. The source stays in memory and clipboard requests; it is not added to diagnostic payloads.

Two red-before/green-after tests verify exact inline/fence source, quote behavior, shared clipboard request content and source recovery. Full Jest: **56 suites / 482 tests** and production build pass; final inline failure-container adjustment passes focused tests/typecheck. Actual native clipboard/key activation, copy-control geometry at narrow widths and enabled/disabled/Finder behavior remain in end-to-end acceptance.

## Syntax protection and heading checkpoint

Added negative cases for an unmatched double-dollar opener and raw inline code containers, plus a production test for math-only heading anchors. All three defects reproduced before the change. The tokenizer now avoids interpreting a suffix of `$$` as a single-dollar opening and respects raw code/pre/script/style/textarea boundaries. Mathematical inline tokens carry their source content, and heading slug generation includes those tokens without depending on rendered SVG text.

Also verified that an ordinary preceding code span does not suppress later valid math, and a footnote definition moved to the rendered document tail retains original source registration order and line numbers. Full Jest: **56 suites / 487 tests**; production build/typecheck pass. Additional container/table/CRLF source mapping and parser performance remain in the acceptance work.

## Native integration and baseline API checkpoint

The full real-WebKit suite currently stops at the existing `block copy delayed visibility and focus` case with `Idle copy button is visible`. This remains unresolved and is not counted as a passing full integration run. Added an opt-in `FLUX_WEBKIT_CASE_FILTER` for diagnostic subsets; zero matches fail, and default execution still runs every case.

Added a narrowly scoped Object.hasOwn compatibility initializer before MathJax modules (Safari 14 lacks the API). A native case explicitly removes that API before the first math import and verifies rendering, the constructor label, immediate export, standard target links and script-free output. Both math cases pass, and the separately selected export-ready case passes. Updated that older case from a KaTeX class assertion to SVG plus semantic mfrac. This is API-removal simulation on current WebKit, not proof of minimum-OS acceptance.

Compatibility unit test, full Jest (**57 suites / 488 tests**), typecheck and production build pass. Native full-suite failure, actual minimum OS/Intel, VoiceOver and broader host/export acceptance remain outstanding.

## Full native renderer suite checkpoint

Investigated the copy visibility failure: the same unchanged test both passed and failed on final fade completion across runs. Kept its early-hide/reentry assertions, but changed final opacity settling from fixed sleeps to bounded 4-second polling and included focus/hover/state diagnostics for idle failure. No production visibility behavior was weakened.

The next full run reached the new API-removal case after previous math tests had already cached the engine. The compatibility initializer only ran on module import, so that explicit API removal failed. Each mathematical session now ensures the required API before using the cached engine.

After rebuilding, `scripts/test-renderer-webkit.sh` passes **all 28 real WebKit cases**, including copy visibility/focus, source-generation cancellation, reference export, native Typst offline, Mermaid/Graphviz/Vega, slow export resources, search, outline, wide/narrow and RTL geometry. Focused engine/compatibility unit tests (5 cases) also pass. This supersedes the earlier full-suite failure, but does not substitute for actual host UI, native clipboard, VoiceOver, minimum-system or PDF visual acceptance.

## Native settings and application build checkpoint

Renamed the visible rendering option from KaTeX Math to Mathematical Formulas across en/zh-Hans/de/fr/es/ar, retaining the unchanged `enableKatex` persisted key, bindings and renderer option for preference compatibility. All six strings files pass plutil validation; checked that the new key appears exactly once in each locale and the persisted key remains unchanged.

`make app LOCAL_DEPLOYMENT_TARGET=12.0 CONFIGURATION=Debug` completed successfully with the current Xcode toolchain, including a clean dependency install, renderer build, generated Xcode project and native application/embedded extension compilation. This is the documented temporary local target override, not a change to the macOS 11 product requirement or proof of its runtime compatibility. No installation, release or file-association change occurred.

Prepared `/tmp/flux-issue64-valid-export.md` from the fixed source cases (12 valid items, M12 intentionally excluded and still covered by error tests) for the actual App CLI/PDF acceptance next.

## Actual CLI reference-base fix

Running the built application's `--export-pdf` on that valid corpus initially failed after rendering: export readiness found a mathematical reference error. The same bundle succeeded in the independent scheme probe, demonstrating why the real host path was necessary. Native diagnostic capture isolated the failing readiness check; temporary verbose error instrumentation was removed.

The CLI sets a resource base URL, which affected MathJax's default reference URL construction. Explicitly setting TeX `baseURL: ''` keeps formula references as same-document fragments. The rebuilt real application now reports successful PDF export to `/tmp/flux-issue64-product-pdf/valid.pdf`. Five focused real-engine tests and the renderer/native rebuild pass. Added a base-element unit case, although JSDOM did not reproduce the native default-URL difference; the native failing-then-successful CLI run is the actual regression evidence.

PDF visual inspection, metadata/link inspection and invalid-input export rejection remain pending; file creation alone is not final PDF acceptance.

## Product PDF visual failure evidence

Rendered all three pages of the actual CLI PDF with Poppler and inspected each. The M08 matrix is present, but its neighboring cases expression does not visibly show the second row in the PDF, while the live semantic tree contains both rows. Source-line gutters also remain in print. Therefore this PDF **fails visual acceptance**; it is not delivered as a successful artifact. Source heading M05 also ends on the preceding page from its formula, requiring pagination review.

The independent native probe confirmed that both cases rows exist in semantic output and SVG DOM. The next investigation must distinguish SVG clipping/print overflow from mathematical parsing; simply increasing semantic item counts will not address this failure.

Separately ran the actual app CLI on the intentional unknown-command control. It exits nonzero with actionable export feedback and does not create the requested invalid.pdf. Evidence summary and valid-PDF hash are in `docs/research/issue64/product-pdf-checkpoint.json`. PDF links/tagging and full corrected visual output remain unverified.

## Print clipping fix

Overrode overflow for mathematical wrappers, MathJax containers and SVG in print, with explicit page-break-inside avoidance. Suppressed source-line pseudo-elements in print. Rebuilt the real application, exported the same valid corpus, rendered all three pages with Poppler and inspected them: M08 now visibly contains both cases rows, including `−x, x < 0`; line-number text is gone. The original failure and new PDF hashes are retained in the checkpoint record.

Remaining visible defects: M05's heading still separates from its formula across pages, and the source gutter border/spacing remains due to style precedence. These are not hidden by the clipping fix and still require correction. This PDF is therefore not the final validated deliverable.

## Corrected PDF pagination

Added reversible beforeprint/afterprint grouping of adjacent headings with display-math blocks, retaining original nodes and restoring the original DOM afterward. Print grouping has break-inside avoidance; unrelated paragraphs/inline math remain unchanged. Increased the print gutter override specificity so later screen gutter CSS cannot win.

Rebuilt the actual application and exported the same 12-item valid corpus again. All three pages were rendered and visually inspected: M05/M09 headings now remain with their formulas, every mathematical item is complete, both cases rows and Chinese text are visible, and the source gutter/numbers are absent. Saved the product output as `output/pdf/issue64-product-math.pdf` and recorded its hash in the checkpoint. This passes this corpus's current-system CLI visual check, not the entire goal's platform/interaction matrix.

Two reversible-print tests pass; full Jest **58 suites / 491 tests** and native/renderer builds pass. The reference PDF remains separate from this actual product PDF.

PDFKit annotation inspection found no Link annotations in the current Quartz/AppKit print output. Equation reference text is visible, but clickable PDF navigation is not preserved by this path; standalone HTML reference navigation remains a separate requirement. This limitation must remain explicit in the final acceptance report.

## Standalone HTML offline reopening

Exported the actual production renderer's valid 12-item corpus to HTML, then reopened it in a fresh WKWebView under a restrictive test CSP: no scripts, fonts or network; inline styles and data images only. The first reopening retained formulas but revealed unused KaTeX font-face URLs trying to load application-relative files. Added a failing export test and omitted webfont rules when the exported document contains no KaTeX output (Typst's KaTeX path remains separate).

After rebuilding and re-exporting, the fresh offline page loads only its HTML file with zero CSP violations: 12 SVG mathematical outputs, 12 assistive trees, nonzero geometry for every formula, zero missing local glyph targets, one valid equation-link target, no scripts and no copy/feedback controls. Results/hash are stored in `standalone-html-checkpoint.json`. This demonstrates offline structural and geometry readiness; actual link activation/keyboard/VoiceOver and cross-browser visual comparison remain separate checks.

Full Jest **58 suites / 492 tests**, typecheck/build pass. The font-face omission intentionally applies only when no KaTeX output exists; mixed Typst/KaTeX standalone resource handling still needs its own regression acceptance.

## Whole attachment and scoped discovery

Rendered the unmodified original attachment with actual Mermaid/Graphviz/Vega engines in WebKit: eight Mermaid diagrams, one Graphviz, one Vega, document-end marker present, and only the intentional unknown-command mathematical error. Whole-document math count is 14, because line 132's escaped-parenthesis example has exactly the same syntax as enabled parenthesis math. This ambiguity is recorded explicitly in `full-document-checkpoint.json`; it is not added to the original 13-item dedicated math acceptance count. Image loading was not verified in this run.

An additional `mathbb{abcxyz}` native test exercises a dynamically imported local double-struck glyph chunk (41,733 bytes) and yields one formula/six glyph uses without errors. This also exposed an invalid MathJax constructor `elements` option warning. A new test demonstrated unintended processing of unrelated DOM math. Fixed discovery by calling `doc.findMath({elements:[stage]})` before rendering, instead of passing the scope as an unsupported constructor option.

The new isolation test fails before and passes after the correction. Full Jest **58 suites / 493 tests**, typecheck/build pass; the native dynamic-font probe now completes without the invalid-option warning. Remaining full-host/image/interaction/performance gates are unchanged.
