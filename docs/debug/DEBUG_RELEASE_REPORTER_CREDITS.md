# Release reporter attribution repair

## Baseline and acceptance

Baseline: `41b5123`. Historical release credits were inconsistent across GitHub,
CHANGELOG and Sparkle. Perl interpolation in `generate-appcast.sh` erased handles
such as `@Ctrl-Alb` and `@angedell`; Markdown profile links were not rendered.

Acceptance criteria (before implementation):
- Run the actual generator with a stub signer; preserve handles, Unicode, literal
  `$`/backslashes/pipes, and escaped HTML while rendering valid profile links.
- Replacing an older release must preserve every other item; decline must leave
  the feed byte-identical. Keep the complete selected changelog section.
- Historical backfill uses verified issue authors and release associations,
  distinguishes reporter credit from implementation credit, and does not imply
  unresolved reports were fixed. Preserve existing contributors and notes.
- Only appcast descriptions may change during backfill: versions, dates,
  downloads, signatures, asset sizes and item order must remain identical.
- Snapshot remote notes and assets before editing; compare before each write,
  read back each result, and verify assets remain unchanged. Preserve artwork.
- Direct commits/pushes only; no PR and no new release/artifact rebuild.

## Results

Generator repaired: Markdown is rendered by the existing locked markdown-it;
item content is passed via stdin to a validating Python writer. No release prose
is evaluated as Perl/Shell. Complete sections are retained and replacement is
limited to the exact version item. Four generator integration cases pass
(three failed against the old script), as do five publication tests. CI now
runs the generator regression after installing the existing renderer dependencies.
Historical reconciliation and remote verification are in progress.
