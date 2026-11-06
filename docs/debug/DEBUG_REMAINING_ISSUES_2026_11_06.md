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
