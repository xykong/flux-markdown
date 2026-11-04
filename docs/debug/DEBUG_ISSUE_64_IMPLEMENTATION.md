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

## Production warm benchmark

Ran the actual production bundle in current-system WKWebView at 960×900 with QuickLook render options, copy controls/line numbers disabled. For each 100/1000-item fixed fraction/root corpus: five warmups followed by 30 measured renders, awaiting export readiness and checking the exact formula count plus zero math errors every time.

Observed 100 items p50/p95 **94/101 ms**, DOM 615,017 bytes; 1000 items **1714/1988 ms**, DOM 6,705,445 bytes. These meet the frozen reference-machine p95/DOM limits, with little time margin at 1000. This is the integrated renderer, not the actual QuickLook process or a minimum-system benchmark.

One late WebContent RSS sample was 2,774,704 KiB (about 2.65 GiB) during repeated large-document rendering. It does not establish peak or retained memory, but warrants explicit cleanup/recovery measurement before acceptance. No memory gate is marked passed from this run.

Raw samples/environment are saved in `production-benchmark.json`. The same source workload is now in `scripts/research/issue64-math/benchmark-production.js` with a bounded native runner script; shell syntax checked. Remaining work includes memory recovery, cold/no-math baseline and per-host/platform budgets.

## Session stylesheet ownership

Repeated native rendering of a small mathematical document shows stable DOM counts and zero remaining measurement trees, followed by zero mathematical outputs after switching to plain text. It nevertheless exposed a duplicate engine-owned `MJX-SVG-styles` element in the shared head in addition to the generation-controlled application stylesheet.

Added a failing real-engine test and removed only the exact session-owned stylesheet during cleanup, retaining returned CSS for publication by the current generation. This avoids an obsolete engine session leaving or publishing its global CSS. It does not remove another session's replacement node.

After rebuilding, five actual WebKit rerenders each report 203 nodes, two styles and zero engine-owned SVG styles/stages; plain-text switching leaves no math. Full Jest **58 suites / 494 tests**, typecheck/build pass. This verifies DOM/style cleanup, not recovery of the previously observed large-workload RSS; that memory investigation remains open.

## Large-workload recovery observation

Ran three cycles in one identified fresh WebContent process: ten renders of 1000 formulas, plain-text replacement, then ten seconds idle. Every loaded phase had 1000 formulas and zero staging roots; after clearing, final DOM count stabilized at 193 and math/staging counts at zero. No output loss occurred.

Process RSS during each post-clear idle interval remained about **2361 / 2452 / 2631 MiB**, with no significant recovery in those ten-second intervals. This is **not a passing memory result**. RSS is not a retained JavaScript heap measurement and WebKit may retain allocator pages, but the rising residual process footprint still requires investigation; it cannot be dismissed based on DOM counts.

Saved raw one-second RSS samples, phase events and environment in `memory-cycle.json`, and the workload/monitor scripts under `scripts/research/issue64-math/`. The phase field is the last logged marker (therefore an `idle` marker can also precede the next workload); analyze explicit cleared intervals for recovery rather than treating every marker-group sample as idle. Monitor syntax checked; the executed source workload and equivalent temporary monitor produced exit 0.

Next required work: attribute retained state/caches and test cleanup or bounded reuse, then repeat this same recovery workload without relaxing the scope or declaring completion from short-run timing alone.

## Font-sharing hypothesis rejected

Tested a single shared SVG font-data instance while retaining document-local input/output objects. All 494 unit tests passed, but the identical three-cycle workload retained roughly **2455 / 2513 / 2636 MiB** after clearing, comparable to the original implementation. This is not evidence of a useful memory fix, so the production source experiment was reverted; observations are retained in `memory-font-experiment.json`.

A vmmap sample during the experiment attributes about 1.7 GiB allocated / 2.3 GiB resident to WebKit Malloc, with about 13.7 million allocations. This directs the next experiment toward DOM/tree allocation and cleanup rather than assuming font tables alone explain the footprint. Sampling occurred during the workload and is not a retained-heap proof. The goal remains incomplete; memory acceptance is still open.

## Batch-sanitization hypothesis rejected

Tested sanitizing the entire stage in one DOMPurify pass, then redistributing sanitized children by source order, keeping the same allowlist and glyph checks. All 495 tests passed, including a new multi-formula local-glyph integrity test. However, the identical recovery workload retained roughly **3100 / 3102 / 3104 MiB**, worse than the per-formula implementation. The batch implementation was reverted and the normal build restored; raw evidence is in `memory-batch-experiment.json`.

Retained the independent multi-formula test, which also passes with the original implementation. The experiment suggests reducing the number of parser calls alone does not resolve the native-memory footprint and can increase simultaneous tree allocation. No production performance claim or memory completion is made; further heap/allocator attribution is required.

## Window attachment and view-release control

Extended the research probe with opt-in native-window attachment and post-completion release observation. Ran the same three-cycle workload with a WKWebView attached to an NSWindow ordered behind existing windows. Post-clear RSS was approximately **2471 / 2548 / 2623 MiB**, similar to the windowless experiment; DOM cleanup stayed stable.

After removing the script handler/delegate, detaching and releasing the probe-owned view/window, observed another 15 seconds. The same WebContent process stayed near 2623 MiB; it disappeared after the probe process exited. This is evidence against a solely windowless-test cause, not proof of specific framework cache or object retention. No private GC/memory-pressure API was used and no production lifecycle behavior was changed.

Raw data and scope are saved in `memory-window-experiment.json`. The monitor now records process disappearance explicitly rather than silently skipping absent samples. Probe source compiles and monitor syntax checks pass; the release log's literal newline in this experimental binary was corrected in the saved script. Memory acceptance remains unresolved; next work must distinguish render-call lifetime, framework process cache and actual retained DOM/JS objects.

## Separate native calls and heap attribution

Repeated the large workload through 30 distinct native `callAsyncJavaScript` invocations (each completion returned before the next call), then cleared to plain text and idled for ten seconds. This did not eliminate high process memory, ruling out one long JavaScript promise as a sufficient explanation.

Used `heap -s --noContent` on the identified test WebContent process during rendering and after clearing. During sample: physical footprint 856.4 MiB, peak 1.1 GiB; post-clear sample: footprint 678.5 MiB. RSS is therefore not the same as the system's physical-footprint metric and must not be described as exclusively retained application memory.

Nevertheless, the cleared heap still reports approximately 156k SVGGElement, 103k SVGUseElement, 53k SVGPathElement and 68k MathMLTokenElement objects while the live document is plain text. These are specific native-tree objects warranting further attribution, not merely empty reserved address space. Heap inspection can perturb execution; this run is not used as a timing benchmark.

Saved samples/selected content-free heap summaries in `memory-separate-calls.json`, plus the separate-call probe/workload source. The probe source is compiled as `main.swift` with the shared bundle handler, and the workload is passed as the JS argument. Next hypothesis: SVG use shadow-tree allocation versus direct glyph paths, with output/size validation retained. No unverified optimization adopted.

## Direct glyph paths

Tested MathJax SVG `fontCache: none`, replacing glyph use references/shadow trees with direct paths. Same 3-cycle workload post-clear RSS: **2039 / 2309 / 2332 MiB**, versus original **2361 / 2452 / 2631 MiB**. This is a modest reduction, not a resolved memory gate. The early size probe overlapped only startup, not the post-clear comparison intervals.

1000-item output has exactly 1000 formulas, 13,780 paths, zero uses and 8,808,288 serialized bytes (within the frozen 10 MiB limit). Live DOM count drops from roughly 67k to 59k. All **495 tests** and production build pass; strengthened the multi-formula test to require actual paths so an empty use loop cannot pass vacuously.

Retained direct paths and updated the design's output-cache decision with this measured tradeoff. Raw samples/output counts are in `memory-direct-path-experiment.json`. Final PDF/HTML visual and timing checks must be repeated on the finalized implementation; physical-footprint/heap recovery and actual hosts remain outstanding.

## Output-error and initialization fault injection

Injected an SVG typesetting failure and an initialization failure. Before the correction, output-error nodes were not classified as failed mathematics and initialization after attaching the measurement root could leak that root (also contaminating a later layout test). The tests produced three failures including the downstream contamination.

The engine now attaches the measurement root only after initialization succeeds, recognizes MathJax output-error nodes, retains failed output's original source, and rejects references to failed targets while continuing later valid formulas. Failure diagnostics return through the same production mathematical-error path, so export gating remains effective.

All ten engine tests pass, including the injected failures and cleanup check. Full Jest **58 suites / 497 tests**, typecheck and production build pass. This resolves concrete fault paths but does not claim that the large-workload memory or native interaction gates are complete.

## Original block source preservation

Added CRLF/frontmatter source-navigation and copy tests. Navigation already retained the correct original 7–9 line range, but the copied math fence normalized CRLF to LF. Capture original source lines before markdown-it normalization and recover display-math/fence raw blocks from token source ranges, preserving exact newline sequences and container prefixes. Mathematical payload parsing remains normalized as before.

The original failing CRLF copy case now passes, along with a quoted CRLF formula that verifies the original `>` prefixes are retained. Full Jest **58 suites / 500 tests**, typecheck and production build pass. Multiline inline math's exact line-ending preservation, nested-link semantics and remaining broad acceptance items are not inferred from these block-source tests.

## Reference interaction red checkpoint

Actual WebKit inspection of `[See $\eqref{x}$](https://example.com)` confirms an SVG fragment anchor nested inside the ordinary HTML link. The fragment anchor has tabindex 0 but no accessible name and sits under the SVG's aria-hidden=true visual subtree. A valid target alone therefore did not prove keyboard/assistive usability.

Added two production-entry regression tests that fail on these exact behaviors: require a named keyboard link outside hidden output (also in exported HTML), and require preserving both external/link-reference destinations without nested anchors. These are intentional red acceptance tests; fixing the reference interaction layer is the next work item. No reference-accessibility completion is claimed from the earlier structural checks.

## HTML reference navigation layer

Moved mathematical navigation out of aria-hidden SVG. A standalone ref/eqref wraps its complete output in a named HTML fragment link; complex formulas expose distinct reference links next to the mathematical output. Visual SVG anchors become groups, retaining their glyphs without a hidden tab stop. Link labels come from the semantic reference text.

When the formula lies inside a normal Markdown link, split the outer link around the formula to avoid nested anchors. If that outer link contained only the formula, keep its external destination as a separate visible URL link rather than dropping it. Preserve any explicit outer anchor identity once.

The two prior red tests now pass, plus tests for multiple references and formula-only external links. Real production WebKit inspection confirms separate external and fragment links, no parent-link nesting, and the reference's accessible name `(A)`. Full Jest **59 suites / 504 tests**, typecheck/build pass. Actual trusted keyboard activation and VoiceOver speech remain to be exercised; valid DOM is not claimed as a screen-reader result.

## Trusted native keyboard and clipboard

Added a real-window WKWebView integration case that focuses the formula copy button and delivers native NSEvent space keyDown/keyUp through NSWindow, rather than calling JavaScript click. The existing trusted-event gate accepts the activation; the actual BlockCopyBridge validates the request, writes to an isolated named NSPasteboard and acknowledges the result. The test asserts exact original TeX on that pasteboard. The bridge accepts an optional pasteboard for this test; production callers retain `.general` by default, and the user's clipboard is not touched.

The same native case focuses the named HTML formula-reference link, sends Return, and verifies the below-viewport target moves into view. This proves native activation reaches the real navigation code, not merely target existence. The isolated pasteboard is released afterward and the prior foreground application restored.

The selected case passes, followed by the complete `scripts/test-renderer-webkit.sh` run: **all 29 real WebKit cases pass**. This validates shared native renderer/bridge behavior; full App/QuickLook/Finder UI and VoiceOver speech/platform coverage remain explicit outstanding gates.

## Actual App document window observation

Rebuilt Debug with the documented local target override and opened the derived valid corpus in the actual application. Used the computer-use skill's version-matched Orca guide/capabilities and targeted the exact new process/window. The native tree exposes the mathematical semantic containers, copy controls and named `(1)` reference. After TOC M08 activation, a fresh settled observation shows breadcrumb M08, position 72%, and the screenshot displays the complete matrix and both cases rows.

Saved the test-document-only tree, screenshot and scope in `docs/research/issue64/app-window/`. These are actual App observations, unlike the earlier standalone WKWebView probes. They do not prove VoiceOver speech.

Background AXPress and one coordinate retry on the numbered reference did not establish navigation to the equation. A foreground observation attempt found the test window gone; fresh window inventory showed an unrelated document. No contents or controls of that unrelated window were accessed. Actual App reference activation therefore remains unverified; do not replace it with the passing native test-harness result.

## Real QuickLook provider selection

Launched qlmanage preview for the test corpus and inspected the actual extension process executable: the system selected `/Applications/FluxMarkdown.app` (the existing installation), not the current Debug bundle. Refreshed the already-known Debug extension with pluginkit -a and repeated; default match and launched process still selected the installed bundle. Closed only the qlmanage preview processes launched for these tests. This is not a new-feature QuickLook pass.

Prepared `build/issue64-host-validation/candidate.app` and `installed-backup.app` with ditto; both pass deep strict code-sign verification. Executable hashes and pending state are recorded in `quicklook-host-validation.json`. No installed app, file association or user election was replaced. Asked asynchronously for a maintenance window/authorization to temporarily replace the user's active installation and restore it after actual QuickLook/Finder validation. This affects the app the user is actively using, so dependent replacement waits for their response; other implementation/verification work is still possible.

## Independent numbering and metamorphic checks

While host replacement authorization remains pending, added a direct comparison between the actual TeX input engine's label table and the previously independently compiled Tectonic/amsmath oracle manifest. Covers explicit tag 1, forward tag A, automatic 1, align row 2 with notag, starred environment and tag-star B. The expected values come from the independent artifact, not from the current engine output.

Added label-renaming variants including spaces, underscores, inherited-looking names and supplementary Unicode; equation/reference reordering and unrelated-prose insertion preserve explicit values. Real output tests confirm references to unnumbered or failed declarations remain unresolved and do not leave href targets.

All 28 focused identity/engine tests pass; full Jest **59 suites / 514 tests** and OpenSpec strict validation pass. These strengthen semantic evidence, but do not replace the pending human reviewer, minimum-platform, VoiceOver, memory and actual QuickLook/Finder gates.

## Current output performance and DOM publication

Re-ran the production benchmark after switching to direct SVG paths: 100-item p50/p95 **81/93 ms**, 1000-item **1273/1416 ms**, 1000-item DOM 8,809,288 bytes. All output counts/error checks passed. Saved samples in `production-direct-path-benchmark.json`; these meet the frozen current-reference-machine warm thresholds but not cold/no-math/minimum-host acceptance.

Removed an additional full serialization/reparse when publishing the already-sanitized staged DOM. Nodes now move through a DocumentFragment into the preview; generation checks and sanitization remain before publication. This avoids constructing a duplicate live SVG tree from the same HTML. Full 514 tests and three native math keyboard/reference/option cases pass; build/typecheck pass.

Repeated the same memory recovery workload after this change; raw data is in `memory-dom-move-experiment.json`. The process remained correctly identified throughout, and DOM/math/staging cleanup checks stayed stable. This is another bounded reduction in allocation work, not a declaration that high native RSS or the final memory gate is solved. Host-install authorization remains pending and no installation was replaced.

## Cooperative stale-session cancellation

Passed the existing render-generation predicate into the mathematical engine. It now checks before allocating a stage, before compilation, before typesetting (including asynchronous retry passes), and after the render promise. Superseded work rejects internally and cleans up; the existing current-generation catch prevents publishing an old error into the new document.

Added tests for an already-invalid session and supersession during metrics/compilation. Both assert no SVG typesetting call and no residual measurement root. This is cooperative phase cancellation, not an interrupt for synchronous TeX work already executing; input/expansion limits remain necessary.

Full Jest **59 suites / 516 tests**, typecheck/build pass. This improves stale-work behavior without treating it as a fix for the separate repeated-document memory observations. Native installation authorization and external/platform acceptance remain pending.

## Cold mathematical and no-math baseline comparison

Built the unmodified `v1.42.645` renderer in an isolated ignored build directory using its lockfile. Compared the same 100-section plain Markdown workload on baseline/current bundles: five warmups and 30 samples each, identical native viewport/options. Both p50/p95 are **9/10 ms**. Every sample retains 100 headings, zero math outputs; current asset tracing shows no math-engine or glyph/font chunk requests. This meets the no-math regression gate on the current reference machine.

Ran the current valid derived 12-item mathematical corpus in 20 fresh native WebKit processes/nonpersistent data stores: first-math p50/p95 **126/130 ms**, all 12 items and zero errors each time. The initial math-engine chunk is **1,390,922 bytes**, below the 3 MiB runtime asset gate. The OS disk cache was not flushed, so this is process-cold evidence, not reboot-cold disk performance.

Raw samples, asset traces, source commits and scope are in `cold-and-plain-benchmark.json`; reusable JS workloads are in `scripts/research/issue64-math/`. Current reference-machine cold/warm/no-math gates now have production evidence. Actual extension/older-platform performance, memory limits/recovery and the remaining interaction/reviewer gates are still not complete.

## Explicit temporary-tree disconnection

Added a real-engine test retaining a temporary typeset-root handle: before cleanup it still owned SVG descendants after the engine returned independent sanitized strings. The engine now empties temporary output roots/source wrappers/stage in finally before dropping the MathJax list. It does not mutate the independent sanitized output published by the caller. This breaks native descendant graphs even when a wrapper's garbage collection is delayed.

The new test fails before and passes after; full Jest **59 suites / 517 tests** and build/typecheck pass. Same three-cycle memory experiment yields roughly **2035 / 2072 / 2074 MiB** post-clear, versus **2042 / 2096 / 2160 MiB** for DOM-move alone. The late cycles are flatter, but the residual footprint remains high and no hard memory-success claim is made.

Raw data is in `memory-tree-cleanup-experiment.json`. Retained the explicit lifecycle cleanup for its directly tested ownership guarantee. Next comparison should render identical dollar-delimited formula payloads on the release baseline and current engine; the original bracket-only stress input cannot serve as a fair old-engine memory baseline.

## Same-corpus release memory comparison

Changed the diagnostic workload to dollar display delimiters supported by both versions, preserving the identical 1000 fraction/root payloads, three rounds of ten renders, count verification, plain-text clearing and ten-second idle intervals. Ran release `v1.42.645` and current builds sequentially in fresh native processes.

Post-clear RSS in MiB: release **1361 / 1516 / 1520**, current **2022 / 2031 / 2131**. Third-cycle difference is **612 MiB** (about 40%). The existing version also retains substantial process memory, but that does not erase the added cost of the new implementation. This remains an unresolved memory regression/tradeoff for acceptance, not a pass.

Saved raw samples and method in `memory-release-comparison.json`; added `memory-common-corpus.js` and optional bundle/workload arguments to the monitor so the comparison is reproducible. Both native runs exit 0 with all 1000 formulas each render. These are RSS observations, not identical physical-footprint/retained-heap measurements; final older-platform and resource-budget decisions still require evidence.

## Detached in-place sanitization hypothesis rejected

Tested DOMPurify IN_PLACE on detached generated math wrappers using the same allowlist/reference validation, instead of serializing each wrapper into an additional sanitizer document. Safety-equivalence tests and the full 518-test experimental suite passed. The same common-corpus memory workload worsened post-clear RSS to approximately **2440 / 2607 / 2799 MiB**, compared with **2022 / 2031 / 2131 MiB** on the retained implementation.

Reverted the experimental implementation and its specific API test, and rebuilt the retained source. The experiment is preserved only as `memory-inplace-experiment.json`; no safety bypass or unproven optimization is adopted. This is another concrete negative result against equating fewer parser calls with lower retained WebKit memory. The accepted source test count remains 517 (the extra experimental test was removed).

## Inline source newline and external acceptance audit

The remaining-source audit found multiline inline mathematics still normalized CRLF when copied. A regression test failed; inline raw source now restores each original newline sequence from its source-line mapping while keeping the normalized mathematical payload for parsing. Full Jest **59 suites / 518 tests**, typecheck/build pass.

Rechecked the available platform: macOS 27.0.1 arm64; repository CI targets macOS 15, not the minimum macOS 11/Intel runtime. Asked for an available older-system/Intel machine or an execution contact rather than treating syntax transpilation/current-machine tests as minimum-platform evidence. The earlier temporary QuickLook-install maintenance authorization also remains pending. Neither request is treated as answered by automatic goal continuations.

The goal remains incomplete: actual new-extension QuickLook/Finder selection, actual VoiceOver reading, independent human review, minimum-platform validation, and the measured native-memory cost are not proven complete. Existing local test/benchmark/PDF/HTML evidence must not be expanded to claim those gates.

## Post-sanitization integrity audit

The engine previously validated reference targets before sanitization only. Added mathematical sanitizer metadata (IDs, links, glyph-path count and formula count) gathered from its already-created fragment, avoiding another parse for validation. Lost paths/formula containers now classify as output failures with preserved source; cleaned reference targets are revalidated, and invalid target status propagates through forward reference chains before publication.

Fault-injection tests delete an output path or a target ID from the sanitizer result and verify the affected formula/reference cannot report success or retain a broken href. A chain test verifies an earlier reference cannot survive when its later target is itself unresolved and falls back to source. These checks address the design's explicit damaged-output detection requirement.

All **59 suites / 521 tests**, typecheck and production build pass. Independent host, minimum-system, VoiceOver and native-memory gates remain outstanding; no installed app or pending permission state changed.

## Markdown container coverage

Added production-entry cases for GFM escaped vertical bars, strong/emphasis math and footnote formula references after footnote relocation. These render valid mathematical semantics without breaking table column count or the reference target.

A separate source-position case exposed table inline tokens lacking their own map: formulas incorrectly inherited line 1. The math collector now tracks enclosing block ranges and uses the row range for such tokens. The red test now reports rows 3 and 4 correctly. This changes position metadata, not GFM's delimiter/escaping rules.

Full Jest **59 suites / 525 tests**, typecheck/build pass. Exact raw table-cell escape reconstruction and broader external/interaction/memory gates remain distinct from these semantic/line-range checks.

## Original table-cell escapes

The copy test for `$a\|b$` in a GFM cell failed because markdown-it's table parser removes the escape before the inline math rule receives its input. Added a per-row normalization-to-original offset map matching that table transformation. Mathematical parsing continues to use the GFM-decoded payload, while copying/fallback uses the original source slice.

Verified multiple cells, repeated identical formulas, a literal code cell and a formula inside emphasis, including tables without outer pipes. Mapping is built once per row, not repeatedly per cell. Full Jest **59 suites / 527 tests** passes; a subsequent mapping-cache refinement passes focused source tests/typecheck and the production build. External platform/host and memory acceptance states are unchanged.

## Current-revision native verification

On source `e457b87`, reran the complete production-bundle WebKit integration suite: **all 29 cases pass**. Ran Xcode's native BlockCopyBridgeTests and SharedPreferenceStoreTests with the documented local macOS 12 deployment override. Queried the resulting xcresult summary: **22 passed, 0 failed, 0 skipped**, on macOS 27.0.1 arm64. The pasteboard tests use isolated named boards and preferences use temporary stores.

Saved the allowlisted result summary in `current-native-validation.json` (omitting machine identifiers). These fresh results cover current code and the changed bridge/preference boundaries; they do not establish minimum-system execution, VoiceOver speech, actual new-extension QuickLook/Finder loading or resolution of the measured memory cost. The corresponding user requests remain pending.

## Resumed implementation: virtual-layout and actual VoiceOver probes

The user explicitly resumed work and requested continued improvement. The goal is active; unavailable external gates are tracked separately rather than stopping local work.

Prototyped MathJax LiteAdaptor construction with native postprocessing: the valid mathematical corpus had no engine errors, but three-cycle residual RSS remained about **1936 / 2001 / 2009 MiB**. The modest benefit did not justify shipping uncalibrated CJK/host-width measurement. Restored the accepted browser-adaptor implementation and rebuilt it. Results are preserved in `memory-virtual-layout-experiment.json`; the prototype is not production behavior.

Attempted actual VoiceOver in a dedicated native test window containing only public mathematical samples. The native AX tree exposes the fraction, powers and named reference. VoiceOver started after its welcome dialog, but read-only last-phrase AppleScript calls timed out. The utility reported AppleScript control disabled; a semantic activation was a no-op and one coordinate attempt timed out. No speech correctness is inferred.

Closed VoiceOver and the dedicated probe, reopened the utility to verify the AppleScript-control setting was still its original 0, then closed the utility. Process checks confirm no test VoiceOver/utility/probe remains. `voiceover-attempt.json` records exact limitations and restoration. The initial probe compile error was corrected before the actual reading attempt; no unrelated document content was read. Actual speech exploration remains an open validation item, but this does not stop other goal work.

## Foreground VoiceOver control attempt and restoration

A bounded foreground retry successfully changed the utility's AppleScript-control checkbox to 1 (verified by fresh AX readback), allowing the VoiceOver scripting interface to respond. However, the VoiceOver cursor did not reliably remain in the dedicated mathematical test window, so no returned global phrase was accepted as formula-speech evidence and no unrelated phrase was retained in repository artifacts. A scoped foreground-control attempt through System Events was explicitly denied by macOS automation permissions (-1743); no alternative route was used to bypass that denial.

Stopped VoiceOver and the owned test probe, restored the scripting checkbox to 0 and verified the value in a fresh utility observation, then closed the utility. Final process checks show none of these test processes remains. Actual VoiceOver mathematical reading is still unverified. The resumed goal remains active; this tooling limitation does not halt independent code work.

## Unmatched explicit display-boundary recovery

Added a document with an unmatched bracket display opener followed by a heading and a separate valid bracket formula. It reproduced an unwanted match to the later formula's closing delimiter, consuming the heading into failed mathematics. The block rule now rejects nesting a fresh explicit opener before its matching close, allowing normal Markdown recovery and later independent mathematics. Dollar-delimiter behavior is unchanged because the same delimiter is both opener and closer.

Also covered an unmatched opener inside a quote followed by a top-level closer; the existing container boundary remains intact. Full Jest **59 suites / 529 tests**, typecheck/build pass. Production WebKit independently reports heading `Following`, exactly one valid mathematical output and the final text marker, confirming the original swallowing behavior is fixed in the built renderer.

## Reproducible production end-to-end runner

Added `scripts/test-issue64-math.sh` and its documented production/offline checks. One execution validates all attachment hashes, runs all renderer tests/build and the full native WebKit suite, renders the unmodified original corpus with real diagram engines, checks matrix/cases semantic rows and Chinese text, verifies valid export and intentional-error rejection/recovery, then reopens exported HTML in a fresh process with scripts/network/fonts blocked.

The complete run passes: **529 tests, 29 native cases**, original 14 mathematical items/one intentional error, eight Mermaid + one Graphviz + one Vega, final text marker, 12 valid dedicated mathematical items, and script-free offline HTML with all semantic trees and a valid accessible reference target. The report explicitly lists what it does not cover. Saved `production-e2e-report.json` and script hashes; logs/export artifacts remain in the printed evidence directory.

Marked implementation-level parsing/session/sanitizer tasks complete based on their source/tests and current production run. Final host/platform/VoiceOver/memory and refreshed PDF acceptance remain open; this does not mark the overall goal complete.

## Refreshed original-syntax product PDF

Rebuilt the actual app and exported the original valid mathematical section, retaining its dollar/parenthesis/bracket delimiters and math fence, plus original MathML. Only the intentional invalid-command line was excluded; that command was tested separately through the actual CLI and again rejected with nonzero exit and no created output.

The first refreshed PDF exposed a short explanatory paragraph ending at a page boundary before its display formula. Extended reversible print grouping to short colon-ended introductions (ordinary prose/inline math excluded), with a red-before/green-after test. Rebuilt/exported and visually inspected both resulting pages: all 12 valid items, Chinese text, full matrix/cases, tag/reference, currency/code and introductions are intact with no clipping/gutter.

PDFKit now finds one internal GoTo annotation from the `(1)` reference to the numbered equation on page 2. Its destination coordinate agrees with the inspected formula-number position. This supersedes the earlier no-PDF-links observation after the reference layer moved to HTML. It is annotation evidence, not a claim of tested mouse/VoiceOver navigation in every PDF viewer.

Saved `output/pdf/issue64-valid-original-syntax.pdf`, the exact derived source, hashes and `current-product-pdf-validation.json`. Full Jest **59 suites / 530 tests**, current renderer/native build and actual CLI export pass. Minimum-platform, actual extension/Finder, VoiceOver and memory acceptance remain separate ongoing items.

## Linear reference-target lookup

Added an 80-reference forward-link integrity case and measured a production workload with 200 references plus 200 target equations before changing lookup. Replaced each reference's full-stage ID scan/failed-container scan with one document target index; semantic labels are indexed once per source, repeated href deduplication uses a Set, and fallback-source lookup avoids repeated error-array scans. Duplicate/failed-target behavior is preserved.

Same native workload after five warmups/ten samples: p50/p95 **218/228 ms before**, **201/205 ms after**, with exact item/link counts and zero math errors in each sample. Saved raw samples and reusable workload in `reference-index-benchmark.json` and `benchmark-references.js`. This is a targeted comparison, not a new substitute acceptance threshold.

Full Jest **59 suites / 531 tests**, typecheck/build pass. Overall memory/platform/actual host acceptance remains open; the measured lookup improvement does not claim to fix those independent gates.

## Directed QuickLook attempt and bundled attribution

Tried the documented qlmanage `-g`/`-c` path with the exact current appex and its declared Markdown UTI. The tool reports it cannot obtain a generator at that extension path and again launches the installed old extension. Closed only the owned qlmanage process. This is concrete evidence that this legacy directed-generator path does not validate the current extension; no installed bundle was replaced.

Completed the newly added dependency attribution resources. Copied the runtime's exact Apache-2.0 license and preserved the MathJax Consortium copyright from its source header. Inspected the pinned NewCM package metadata and WOFF2 copyright table: its packaging declares Apache-2.0, while the underlying font retains MathJax, Inc./Antonis Tsolomitis and GUST attribution. Included those distinctions in the bundled notice and third-party documentation, reusing the existing full GUST text rather than conflating the separate Typst font provenance.

Production build passes; byte comparison confirms the exact runtime license and notice are present in dist/licenses. The npm font repository URL returned 404 during provenance checking; attribution above comes from the installed pinned package/embedded metadata and official MathJax font documentation, not an assumed repository layout. This is asset provenance work, not a claim of a comprehensive legal audit.

### Executable production glyph closure and negative control

The production Vite build now emits a manifest for validation. `scripts/issue64/asset-closure.py` verifies all 165 manifest entries, declared imports/assets/CSS, each upstream SVG dynamic module, and packaged license bytes. A fresh native WKWebView loaded all 40 dynamic glyph modules through `RendererBundleSchemeHandler` and then rendered double-struck lowercase mathematics successfully. This checks executable module closure, not the visual appearance of every codepoint.

The end-to-end runner makes a disposable 47 MiB bundle copy and deletes its double-struck chunk. Static verification rejects the missing file; native import rejects with `TypeError: Importing a module script failed.` The check requires that error, rather than accepting an arbitrary process failure or timeout. No installed application or original fixture is modified.

Complete current-machine run: 59 Jest suites / 531 tests, 29 real WebKit cases, original 14 mathematical items (one intentional error and the documented parenthesis ambiguity), 8 Mermaid / 1 Graphviz / 1 Vega, valid 12-item export, invalid-export rejection/recovery, and fresh offline HTML reopening all pass. Evidence: `docs/research/issue64/production-e2e-report.json`; raw logs under `/var/folders/31/2k2kp17n2f7blhy25xr06r9h0000gn/T/flux-issue64-e2e.ZVtke8`. The report records the base revision and dirty-worktree validation hashes. Metadata recording was added after this run, without changing runtime assertions.

OpenSpec 2.7 is now checked for production resource closure on this machine. Actual selected QuickLook, minimum macOS/Intel, VoiceOver, memory acceptance and independent review remain open. Corrected stale design wording that said implementation had not started and clarified that planned math-model/math-document responsibilities live in the implemented syntax/engine/index modules. The prior blocking audit is historical, not an instruction to stop resumed work.

### Repeated resource-failure behavior and feedback transport

Extended the missing-double-struck production bundle probe beyond import rejection. The renderer preserves exact formula source and the following heading, removes measurement roots, refuses complete-success export, and successfully renders/exports the next ordinary formula. The same sequence passes in all six supported languages with app/quicklook/finder renderer context options (18 combinations).

The probe supplies the feedback generation that actual native hosts provide. Its opt-in Swift `errorFeedback` receiver validates the five-field string payload and records delivery back to JavaScript. Recovery/report/inspection actions share the captured mathematical moduleUnavailable incident; no document source or path enters the payload, and detached controls cannot report the previous incident. The receiver intentionally does not perform actual recovery or open/send feedback. These are renderer/transport checks, not actual host UI, trusted keyboard, localization review or VoiceOver acceptance.

Initial repeated probes timed out after the second document had already rendered, while waiting on unconditional background setTimeout polling. Replacing polling with ordered Swift receiver acknowledgements made the entire matrix complete in approximately half a second. This was a probe synchronization issue; no rendering change was made to mask it. The first attempt also omitted the native generation setup and therefore correctly lacked feedback controls; the final fixture includes that required host contract.

The integrated runner passed with the final localized-label assertions: 531 Jest tests, 29 native cases, 18 resource-failure cases and existing production/offline-export checks. Latest machine-readable evidence replaces `production-e2e-report.json`; raw run directory is `/var/folders/31/2k2kp17n2f7blhy25xr06r9h0000gn/T/flux-issue64-e2e.sVe82q`. Production rendering logic was unchanged in this work item.

### Rejected explicit sanitizer-fragment teardown experiment

Revisited the open memory gate using the unchanged common 1000-formula corpus and fresh sequential WebKit processes. Source inspection found no global MathJax document registry holding past sessions; this is a limited code observation, not a heap reachability proof. Tested one hypothesis: explicitly clear each sanitizer serialization container and its identity map before returning, to break transient native SVG descendant graphs earlier.

Both runs completed all 30 renders and three clear/idle periods with zero remaining math/measurement roots. Control post-clear RSS: 2030.3 / 2069.0 / 2164.2 MiB. Experimental teardown: 2056.0 / 2113.8 / 2175.1 MiB. The related 23 tests passed, but the change improved none of the three memory observations, so it was reverted. The control production bundle was not overwritten during its run; the experiment used a separate output directory. Evidence/protocol/workload hash: `docs/research/issue64/sanitizer-cleanup-memory-experiment.json`.

This rejects an unhelpful production change; it does not resolve the memory gate or establish that RSS equals retained live heap. Further work needs a stronger reachability/physical-footprint explanation or a justified architectural change, rather than additional cosmetic cleanup calls.

### Physical footprint distinguishes retained RSS from live allocation cost

Used `/usr/bin/vmmap -summary` and `/usr/bin/leaks --noContent --nostacks` on the task-owned WebContent process after ten identical 1000-formula renders and document clearing, while a 60-second idle kept the process alive. Repeated with the isolated release renderer. Its package, lockfile and index.ts bytes were rechecked against tag `v1.42.645` (commit `4844b1505e7116cc7b16e2a0cbe891c600d00180`). Process identity was checked against the monitor's final selected PID; both workloads finished successfully. The monitor now writes its selected new-process identity immediately so diagnostic tools can target it without guessing.

Current: physical footprint **58.0 MiB**, rounded peak **1.6 GiB**; release: **77.7 MiB**, rounded peak **1.1 GiB**. Both report four leaks totaling 1664 bytes, with an NSMutableDictionary root; no product attribution is established. Current vmmap shows WebKit Malloc resident ~1.8 GiB but dirty only 45.0 MiB, providing stronger evidence that RSS is not a count of retained live formula objects. The inspected heap allocation total is about 30.9 MiB. This is a diagnostic snapshot, not proof that all paths are leak-free or that the peak is acceptable.

Evidence: `physical-footprint-comparison.json`; reproducible input: `scripts/research/issue64-math/memory-footprint.js`. The current snapshot was approximately 12 seconds after clear, baseline approximately 10 seconds; these are not exactly synchronized snapshots. Original RSS comparisons remain valid as RSS observations, but cannot support a multi-GiB live-leak conclusion. Remaining memory work should concentrate on repeated physical peak/recovery measurements and reducing transient peak cost, not adding ineffective DOM cleanup calls. No production renderer code changed.

### Incremental engine-tree teardown does not demonstrate a peak improvement

Tested clearing each MathJax output node immediately after sanitizer metadata collection, instead of waiting for the final cleanup block. Fifty engine/compatibility tests passed. The identical 10×1000-formula workload completed in both fresh processes, with automatic physical-footprint capture ten seconds after the clear marker. Experiment: 198.9 MiB current / 1.6 GiB rounded peak; control: 235.1 MiB / 1.6 GiB. The control later remained 234.7 MiB. The earlier current snapshot had been 58.0 MiB: post-clear snapshots vary enough that a single pair cannot establish a stable budget or justify the production change. Reverted the experiment because the intended peak improvement was not demonstrated.

Retained `profile-footprint.py` as reproducible diagnostic tooling. It selects only the monitor-recorded new WebContent process, waits for the actual clear marker, captures vmmap and content-free leaks results, preserves leak exit status, and requires workload completion and consistent PID. Usage: `python3 scripts/research/issue64-math/profile-footprint.py PROBE_EXECUTABLE NEW_OUTPUT_DIRECTORY BUNDLE`. Evidence: `incremental-teardown-footprint.json`. The experiment's idle tail overlapped the control process startup, but their rendering phases did not overlap; this limitation is recorded rather than calling them wholly sequential runs.

No production rendering code changed. Peak acceptance and stable repeated physical-memory recovery remain open; neither high RSS alone nor one low physical snapshot closes those requirements.

### Rejected task-yield experiment: lower memory peak, failed latency gate

Upstream source inspection confirms `MathDocument.compile()` compiles the whole list and then recompiles items with forward references; independent `convert()` calls would not preserve this contract. Before rewriting that lifecycle, compared a single fresh thousand-formula render with ten renders separated by MessageChannel task boundaries. The single render's physical peak was 783.8 MiB; ten caller-yielded renders peaked at 949.2 MiB, versus the original uninterrupted ten-render control's rounded 1.6 GiB. Caller-yield experiments are additional diagnostics, not replacements for the original stress workload.

Experimentally added `math-scheduler.ts` and one task yield in `renderMathSources` when the accepted list has at least 100 items, before allocating the measurement tree. MessageChannel avoids native hidden-window timer throttling; both ports close on delivery, with a timer fallback where unavailable. A generation check after the yield prevents superseded large documents from starting allocation. This gives WebKit an event-processing/reclamation opportunity without promising forced garbage collection or interruption of synchronous compilation. Small documents retain the existing path.

The new cancellation test first failed because the old engine had already allocated its stage; it now passes. Full Jest: 60 suites / 533 tests. Native integration adds a real MessageChannel/supersession case; all 30 native cases pass. The complete original-corpus/offline-export/resource-failure runner also passes. Crucially, the **unchanged original ten-render workload** against the production scheduler peaked at 991.3 MiB, with 214.4 MiB at the sampled clear point. Raw workload/snapshot evidence and limits are in `task-yield-footprint.json`. Physical-memory variability and actual host/minimum-platform acceptance remain open.

The warm benchmark subsequently failed the frozen latency requirement: 100 items p50/p95 80/86 ms; 1000 items 1395/6067 ms, against a 2000 ms p95 limit. Slow samples appear late in the run (up to 6198 ms). This result does not establish whether the delay is GC, background scheduling or a combination; no speculative cause is claimed. The scheduler, its unit/native tests and design adoption statement were therefore reverted, along with the experimental report replacing the current accepted regression report. The full experimental patch and samples are retained for reproducibility, not as accepted product code. The lower-memory result does not override latency acceptance.

### Index mathematical placeholders and source registration once per document

Found two per-source DOM queries in index.ts: placeholder discovery scans the staged document once per mathematical source, and source registration scans the full rendered document once per source. For 1000 formulas, the latter repeatedly walks the approximately 59,000-node SVG/assistive tree. Replaced these with `uniqueMathTargets`, which performs one attribute query per phase and matches literal requested identities in a Map. It continues to reject all duplicate identities, including third and later matches, and missing identities; unrequested user HTML is never registered. Empty source lists skip the DOM query entirely.

Tests were authored first and failed on the missing index API. Added ambiguity/literal-identity checks and a strict scan-count bound independent of source count; existing source copy/search/engine tests remain in the full suite. Full Jest: 60 suites / 534 tests; typecheck and production build pass. Native regression and frozen timing measurements are recorded below after completion.

Frozen warm benchmark passes: 100 formulas p50/p95 **73/80 ms**; 1000 formulas **763/793 ms**, with 8,808,288 DOM bytes. The full 534-test / 29-native-case production E2E runner passes, including original diagrams, offline HTML and 18 resource-failure transport scenarios. Plain-document benchmark also retains zero math and all 100 headings. Evidence: `source-target-index-benchmark.json`, refreshed `production-e2e-report.json`; raw E2E directory `/var/folders/31/2k2kp17n2f7blhy25xr06r9h0000gn/T/flux-issue64-e2e.s5XUP3`. No new memory acceptance is inferred from lower rendering time.

### Refresh actual application export after source-target indexing

Built the current Debug application with `make app LOCAL_DEPLOYMENT_TARGET=12.0 CONFIGURATION=Debug`; the temporary local override accommodates the installed Xcode toolchain and does not change the product's minimum deployment declaration. Native application build succeeded. The actual executable exported the unchanged valid original-syntax fixture and rejected the intentional unknown command with exit 1 and no output file.

Added `scripts/test-issue64-product-export.sh APP NEW_EVIDENCE_DIRECTORY` to reproduce that product path. It verifies strict code signing, exact equality of all manifest-declared packaged assets against current dist, mathematical glyph/license closure, real CLI valid/invalid behavior, and PDFKit equation-link structure via `inspect-product-pdf.swift`. It does not install or select a QuickLook provider and does not claim visual review from machine structure alone.

Inspected both new Poppler page rasters: complete matrix/cases, Chinese text, original delimiters/math fence, numbered equation and reference, and unbroken formula introductions. The final runner's two raster images match those inspected images byte-for-byte. PDFKit reports one internal GoTo from page 2 to page 2 at approximately (514.874, 401.624), matching the numbered equation. Refreshed `current-product-pdf-validation.json`, `product-export-runner-report.json` and the output PDF. Raw evidence: `/tmp/flux-issue64-product-export-verified`. The PDF remains untagged; viewer keyboard/VoiceOver, minimum macOS/Intel, actual selected QuickLook and memory-budget acceptance remain open.

### Native zoom exposes narrow inline formula overflow

Rechecked memory after source-target indexing: the unchanged ten-render workload completed, but physical peak remained high (rounded 1.7 GiB; clear snapshot 57.8 MiB). Lower CPU time is not a memory acceptance result. See `indexed-renderer-footprint.json`.

The existing native layout suite mostly exercises prose/tables/code. Added actual 12-item original mathematical content plus a deliberately wide display formula, checked at 320/960-point view widths, native WKWebView pageZoom 1/2, light/dark and LTR/RTL surrounding layout. The first probe incorrectly used the old JS `setZoomLevel` API, whose CSS variable is not consumed. Inspection confirmed real App/QuickLook use native `pageZoom`; the revised probe uses that actual contract. No unrelated JS zoom behavior was changed.

At 320 points and 200% native zoom, the prior renderer expanded the 160-CSS-pixel document to 177 pixels: source gutters/padding leave a narrow text column, and inline formulas overflow it. A blanket inline scrolling style would change the baseline of all normal equations, so the implementation identifies only trusted inline formulas wider than their containing text block. Geometry reads precede class writes; a root ResizeObserver and resize listener update the classification and are disposed on replacement/source view. Oversized formulas get local scrolling and keyboard focus; ordinary formulas retain their previous style and baseline. Print resets the overflow-specific inline presentation.

The native keyboard case now verifies that an actual Right Arrow key scrolls a wide inline formula locally, in addition to existing trusted copy/reference checks. The layout matrix also checks visible outputs, reference targets, local display scrolling and all 13 copy controls staying inside the viewport. The LTR/RTL parent direction is deliberately set by the geometry probe, not claimed as automatic content-direction detection or actual Finder host coverage.

Final verification for this change (2026-11-05): 61 Jest suites / 535 tests, all 29 native cases including trusted local Right Arrow scrolling, and 16 width/native-zoom/native-appearance/direction combinations pass. Native Aqua/Dark Aqua is set explicitly in the probe; merely passing a renderer theme option does not emulate the host's media-query appearance. Mathematical colors inherit document color, or the link color for equation references. Normal-width and narrow dark snapshots are recorded under `docs/research/issue64/layout/`; normal inline baselines and the matrix/cases were visually inspected. The narrow snapshot intentionally shows a locally scrollable clipped formula, not the whole corpus.

Two intermediate UI-suite runs failed (one keyboard case without detailed diagnostics; one existing copy fade-out case while another native probe was running). The isolated keyboard case and subsequent serial full suites passed; no unsupported root-cause claim is made for the first transient failure. The expanded keyboard diagnostics remain in the test, and native UI runs are documented as serial work.

Warm performance remains within frozen gates: 100 formulas p50/p95 74/81 ms, 1000 formulas 770/833 ms, 8,806,288 DOM bytes. Rebuilt the actual Debug app and passed the product export runner; both PDF page PNGs exactly match the previously visually reviewed output, so print layout and link destination remain unchanged. Latest raw E2E evidence is `/var/folders/31/2k2kp17n2f7blhy25xr06r9h0000gn/T/flux-issue64-e2e.GgkT16`; product export evidence is `/tmp/flux-issue64-layout-product-export`. OpenSpec implementation task 4.2 is checked; actual host/minimum-platform/VoiceOver/memory acceptance is still open.

### Preserve usable mathematical copy recovery at narrow native zoom

Extended the trusted native keyboard case to inject a negative copy acknowledgement, without writing the clipboard, at a 320-point window and 2x WK page zoom. The original implementation failed immediately: its inline error panel and source textarea expanded the document horizontally. Added an authoritative `math-copy-host` class for registered mathematical wrappers, bounded/wrapped their error controls, and removed the textarea's conflicting 10em minimum width. Ordinary copy controls and non-mathematical block styling are unchanged.

Six recovery scenarios (inline/display × English/German/Arabic) now preserve exact original source in a readonly textarea, keep the page and recovery controls horizontally bounded, and use actual Enter activation to select the complete source. Valid mathematical export after copy failure excludes the entire recovery/feedback UI. The unique test pasteboard retains the earlier successful formula; injected failures do not replace it. Native window size/zoom and renderer language are restored before subsequent cases.

The initial selection assertion was also corrected to wait for focus plus both selection endpoints: assigning textarea.value can initially leave the caret at the end, so checking selectionEnd alone could race the queued native key. That was a test synchronization correction, not a claimed product selection fix.

Full production E2E passed (535 Jest tests, 29 native cases, 16 mathematical layout combinations, original corpus, resource-failure and offline export checks). The final focused native case additionally verifies each recovery control's bounds and clean export after failure. Evidence: `copy-failure-recovery.json`; raw full run `/var/folders/31/2k2kp17n2f7blhy25xr06r9h0000gn/T/flux-issue64-e2e.CO1Xwn`, final focused log `/tmp/flux-issue64-copy-recovery-final.log`. Actual native feedback/editor activation and VoiceOver remain outside these injected-copy-failure checks.

The actual Debug app was rebuilt for this recovery change and passed the product-export runner. Both PDF page rasters exactly match the prior inspected layout; internal equation navigation and invalid-input rejection remain intact. Current raw product evidence: `/tmp/flux-issue64-copy-recovery-product-export`. This is not a claim that actual VoiceOver failure announcements have been verified.

### Keep copy-failure text in the existing live status

Found a semantic accessibility gap: on a failed copy, the persistent `role=status` / `aria-live=polite` node was cleared, while instructions appeared only in a newly inserted ordinary span. Updated the same status node with the existing localized failure/recovery message and removed that separate span, preserving one visible instruction. Error-state status text wraps within the control width. Success and subsequent retries continue updating the same live region; source text remains readonly and unchanged.

Six new language tests first failed on the empty failure status. They now verify the expected localized failure prefix, persistent node identity, no duplicate message, preserved formula source and successful retry state. Full production runner passed: 61 suites / 541 tests, 29 native cases, 16 mathematical layout combinations, original corpus, offline HTML and resource failures. Focused native verification also checks the actual failed-copy response produces a nonempty polite status exactly once, with trusted keyboard selection and clean export still passing. The latest Debug application build succeeds.

Evidence: refreshed `production-e2e-report.json`; full raw run `/var/folders/31/2k2kp17n2f7blhy25xr06r9h0000gn/T/flux-issue64-e2e.RqW9tH`, focused semantic tests `/tmp/flux-issue64-copy-status-focused.log`, native status check `/tmp/flux-issue64-copy-status-native.log`. This establishes DOM status semantics and native response behavior, **not** observed VoiceOver speech; actual VoiceOver acceptance remains open. PDF content was not regenerated for this control-only change; the current native export-after-copy-failure check confirms controls/status do not enter exported mathematics.

### Independent semantic revalidation and mathematical image boundary

Recompiled the independent Tectonic reference using the executable matched byte-for-byte to the pinned archive. The final run copied only the two `.tex` sources into a fresh directory (no old `.aux` input), ran cached-only/untrusted mode with one rerun, and verified labels, warning-free final logs and original MathML structure. Both auxiliary outputs match the archived reference; both freshly rasterized reference pages match the previously reviewed images byte-for-byte. A deliberately changed equation number (1 → 99) is rejected. Temporarily removing the export's currentRender wait made the lifecycle regression fail because the previous document remained visible; the production file was restored, and that readiness function is unchanged by the subsequent resource fix.

Added a fixed-seed property over 41 distinct labels (spaces/underscores, composed/decomposed Unicode, BMP/supplementary characters and inherited object names). Bijective renaming and reversal of explicitly tagged equations preserve the complete forward-reference graph. Automatic numbering is checked separately against the independent TeX reference. Evidence: `independent-semantic-revalidation.json`.

Sanitizer review exposed SVG `image` retention and MathML `mglyph` conversion into image output. Removing image nodes only in the engine was insufficient: the native scheme probe observed a request while the intermediate document was being constructed. The renderer now receives a sanitized inert document fragment, extracts MathML into text placeholders before moving nodes into the main document, and rejects image resources in the mathematical profile. This preserves ordinary document/diagram image policy. DOMPurify's forbidden-tag policy enforces removal; removal metadata only identifies incomplete visual content for source-preserving error reporting.

Three native cases cover mglyph, nested SVG image and HTML img. Each preserves source, marks an unsupported-resource failure, renders subsequent valid math, rejects export and recovers on the next document. Six localized hints explain the unsupported-image boundary and offer the existing editor recovery through shared ErrorFeedback; source is excluded from diagnostic payloads. The sentinel bundle request count is zero. A functioning loopback HTTP control receives one ordinary-image request and zero mathematical-image requests, excluding an unavailable-network false pass. The temporary server serves only a fixed SVG and shuts down after the test.

Final run: 61 Jest suites / 552 tests, 29 native cases, 16 layout combinations, original full corpus, offline HTML, modular-resource closure and fault checks pass. Warm p50/p95: 100 formulas 72/81 ms; 1000 formulas 761/790 ms; DOM 8,809,288 bytes. The actual Debug app builds and passes the product PDF runner; both product PDF rasters match the previous review, and an image-backed MathML CLI export is rejected without an output file. Raw E2E evidence: `/var/folders/31/2k2kp17n2f7blhy25xr06r9h0000gn/T/flux-issue64-e2e.cGiiOx`; product evidence: `/tmp/flux-issue64-resource-product-export`.

OpenSpec 4.4, 5.1 and 5.4 now reflect completed scoped checks. Independent human review, actual selected QuickLook/Finder, minimum-system/Intel, VoiceOver, final memory acceptance and final release closure remain unproven. No issue reply, publication or installation replacement was performed.

### Reproducible backend fallback artifacts and refreshed candidate

Repository runner discovery returned zero self-hosted runners. This endpoint does not describe GitHub-hosted capacity; the checked-in macOS 15 workflow still cannot establish macOS 11 runtime compatibility. No workflow dispatch or remote write was performed.

Implemented the design's internal whole-renderer selection as `build-issue64-math-backend.sh current|legacy NEW_OUTPUT_DIRECTORY`. Legacy archives the immutable v1.42.645 renderer/configuration commit and installs from its unchanged lockfile; current builds the working renderer into a separate directory and records dirty state. It does not introduce an in-product selector or per-formula fallback. Native smoke evidence distinguishes the paths: legacy renders one dollar formula with KaTeX and leaves a math fence as code; current renders all three fixture formulas with MathJax. The old profile is not accepted as satisfying the new feature requirements. Invalid profiles, existing outputs and destinations inside renderer sources are rejected. Initial npm prefix-based installation failed to use the intended isolated context; installation now executes from the archived renderer directory and succeeds without changing its lockfile.

Found the prior unversioned candidate stale. Created a fresh `candidate-62ee2ae.app` without overlaying it onto that directory or modifying the installation/backup. Both App and extension contain exactly the same 172 renderer files as current dist, including identical bytes and no extras. Candidate, installed app and backup pass strict signature verification; installed executable/resource signatures still match the preserved backup. Evidence is in `current-validation-candidate.json` and `backend-build-profiles.json`.

Added draft unreleased notes and explicit development/user rollback boundaries. Independent reviewer assignment has been requested against planned task 2.5; assignment is not sign-off. Final closeout and external acceptance remain open. No application replacement, issue reply, release or publication occurred.

### Actual host revalidation and locked-desktop boundary

A new qlmanage process opened only the owned `Issue64-Candidate-Validation.md` fixture. No provider process existed beforehand; the newly started extension executable was under `/Applications/FluxMarkdown.app`, so the current staged candidate still was not exercised by that system request. The owned qlmanage process was terminated normally; no installation replacement or provider election was performed.

Opened a new staged-candidate App process. Startup restored an unrelated window, whose contents were not inspected. A second explicit open produced the named test window; subsequent reads were scoped to that PID/window ID. Both AX attempts returned permission_denied without a screenshot. The permission helper reported grants and opened its setup page, but no permission switches were changed. The owned candidate was asked to quit and its exit was verified.

A read-only, allowlisted CGSession query then confirmed screen lock with login completed. This is a concrete GUI environment blocker; the earlier reauthorization suggestion is superseded by an unlock-first request. Native focus tests also failed because their page never became active. The harness now waits for actual document focus and identifies this as an environment failure instead of attributing it to copy CSS. It does not force activation repeatedly or bypass the lock/AX denial. The full runner explicitly clears any focused-case filter so a subset cannot masquerade as complete acceptance.

Independently expanded the owned WK layout probe to 72 combinations: 320/600/960 points × native 1x/2x zoom × Aqua/Dark Aqua × LTR/RTL × app/quicklook/finder rendering context. All pass; compact Finder correctly has no copy controls, while App/QuickLook retain 13. This does not prove actual host selection or interaction. Latest unit tests remain 552 passed; the latest full interactive retry is blocked by the locked desktop and is not recorded as a new full success. Evidence: `current-host-revalidation.json` and `expanded-math-layout.json`. No VoiceOver activation or unrelated document inspection was attempted.
