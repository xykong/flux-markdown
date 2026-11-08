# Remaining issue work — 2026-11-06

Baseline 293ba0f; user requested continuing remaining issues. Live open reports are
#58, #61, #63, #64 and #65. No new reporter evidence is present. None meets the
one-calendar-month inactivity threshold. #61/#65 have published fixes; #58 has
locally completed diagnostics awaiting distribution. Do not invent new fixes for
those reports or claim reporter acceptance.

## #63 acceptance before investigation

Found the reporter's public zhengcan/dbx-notebook repository with the exact
plugin/assets/plugin.svg path and SQL Notebook aria-label. Current blob is
`d3043c119bfacf4a688c71831694f82110a53556` (861 bytes). Public history first records
it on October 22, one day after the report; identity with the original affected
asset/environment is not proven. Read only the image; never execute repository
code. Validate all three reported references in real WebKit, with and without
native inlining, and record any remaining actual-host limitations. Keep the
external asset in ignored build evidence rather than importing it into production.

## #23 follow-up acceptance before implementation

The closed issue's last reporter request asks for RTL contents. Current TOC link
indent/active marker follow interface direction only, while document headings
may be Arabic/Hebrew in an English UI. Require independent per-heading direction,
logical indentation/active edge, mixed-direction siblings and unchanged physical
left/right sidebar selection. Use semantic dir=auto; preserve title/close controls
in the interface language. First reproduce with tests, then verify actual WebKit
computed styles and navigation in both interface directions.

A related navigation defect is visible in both production heading slug functions:
they remove all Arabic/Hebrew letters, producing an empty first anchor. Add a
nonempty Unicode fallback only when the existing slug is empty, preserving existing
nonempty anchors. Verify duplicate headings remain unique and TOC targets exist.


## #23 corrective result

Both new regressions failed before the fix. TOC links now use browser-resolved
`dir=auto` independently of interface direction. Direction reads are batched after
insertion, then applied to physical padding/active-edge fallbacks. This deliberately
avoids `padding-inline`/`inset-inline-start`, whose Safari support starts at 14.1;
product support includes earlier Safari 14 WebKit. Sidebar side and localized header
controls remain independent. Shared headingSlug keeps every existing nonempty slug
and provides Unicode/section fallbacks for formerly empty anchors; markdown-it-anchor
continues to deduplicate them.

Verification: 32 focused TOC/RTL/outline tests pass. Real WebKit verifies mixed
Arabic/Hebrew/English heading directions, indentation, active marker edge, duplicate
heading targets, navigation activation and both physical sidebar sides under
English and Arabic interfaces. Production typecheck/build passes. No claim of a
physical macOS 11/Intel run is made. The fix is local/unreleased; no issue reply or
GitHub state change was made for this previously closed report.


## #64 lightweight batch acceptance before implementation

Use original corpus sections 12.2/12.3 and ++inserted text++, including nested
strong emphasis. Require semantic dl/dt/dd, abbr titles and ins; code/fences and
C++ literals must remain intact. Abbreviation definitions must not leak across
renders; malicious-looking tooltip text must stay inert. Verify source view,
searchable rendered text, HTML export and actual WebKit layout. Use upstream
markdown-it plugins instead of a custom parser; pin exact versions. Other dialects
remain outside this batch as recorded in the OpenSpec proposal.

## Dependency audit baseline before patch updates

Adding the lightweight plugins exposed newly published advisories in existing
runtime dependencies: DOMPurify 3.4.16 and markdown-it 14.3.2 (npm reports one
critical and one high affected package). This is an affected-dependency finding,
not proof that all advisory modes are reachable in this app. Acceptance is zero
runtime audit findings plus the full sanitizer/rendering/WebKit regression suite.
Use compatible patches DOMPurify 3.4.17 and markdown-it 14.3.3; do not migrate to
markdown-it 15. Primary evidence: upstream DOMPurify 3.4.17 release and advisories
GHSA-cg2g-xh64-v4q7, GHSA-mrv2-3pqr-j5jr, GHSA-c6gr-qvv4-5v3f,
GHSA-vfgh-jcmw-g37q and GHSA-gfr2-rv44-r23c.


## #64 result and remaining queue

Six new production-entry tests failed before plugin integration and pass after it.
Exact pins: markdown-it-deflist 4.0.0, markdown-it-abbr 2.0.0, markdown-it-ins 4.0.0.
Local declarations use PluginSimple without adding type-suppression directives.
Original corpus definition/abbreviation excerpts render semantically; insertion
supports nested emphasis. Code, per-document isolation, inert tooltip text, source
view and exported semantic elements are covered. A literal-code assertion disables
existing line-number decoration to compare its original trailing newline accurately.

Final verification: 572 renderer tests / 63 suites pass; production typecheck/build
and all 32 real WebKit cases pass. WebKit covers each new syntax in app/quicklook/
finder contexts, light/dark themes, visible geometry, export semantics and search.
Runtime npm audit reports zero findings after the two compatible security patches.
Release native build passes with the explicit local macOS 12 override. Actual
candidate-app CLI PDF export produces one page; PDFKit confirms definition,
abbreviation and inserted text without the unrendered Markdown markers. This is
content/export-path acceptance, not an exhaustive printed-layout or VoiceOver audit.

Current issue dispositions (all checked online November 6):

| Issue | Action / next evidence |
| --- | --- |
| #63 | Matching public SVG passes all three forms across four renderer context/routes. Actual original file/system still unconfirmed; last reporter message October 21, so no inactivity closure yet. |
| #64 | Mathematics shipped; this first non-math batch implemented locally. Containers/attributes/TOC placeholders and other dialects remain outside this batch. No whole-corpus or released-fix claim. |
| #61 | Sparkle fix already released in 1.44.761. Await affected-machine check and a subsequent real update installation; do not manufacture another speculative updater change. |
| #65 | Copy controls shipped in 1.42.645 with opt-out and hover behavior; no new regression reported. Keep awaiting reporter confirmation. |
| #58 | Single-session diagnostics completed locally in the preceding work; a public instrumented build/tool distribution is still needed before requesting another reporter run. |

No remaining open report currently meets the one-calendar-month inactivity rule.
No further issue comments, labels or closures were performed. User-facing examples
and supported/deferred scope are in `docs/user/LIGHTWEIGHT_MARKDOWN_EXTENSIONS.md`.

## Installed batch acceptance

Installed and retained `1.44.761-dev-20261106-184443` using the existing Release
acceptance preparer and vendor installer. No FluxMarkdown document windows were
open before installation. Default editor snapshots match, deep signatures and
Release entitlements pass, and the installed app's actual Quick Look self-test
returns rendered. The installed-app PDF export also passes the same one-page text
checks. Backup and installation evidence are under
`build/remaining-issues-validation/install-essclhyf/`; the staged app copy was
removed after installation. This is a local development build, not a GitHub release.
