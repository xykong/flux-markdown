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
