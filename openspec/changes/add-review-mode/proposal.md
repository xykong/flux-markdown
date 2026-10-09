# Change: Add persistent review mode

## Why

FluxMarkdown shows a transient diff animation when a Markdown file changes. The animation fades. A reviewer cannot track which changed blocks are already reviewed. A reviewer also cannot see removed content after the animation ends.

This change adds a persistent review workflow. The reviewer marks each changed block as reviewed. The marks survive reloads. No second column is necessary.

## What Changes

- Add a review mode to the web renderer. Review mode shows changed blocks against a baseline.
- Keep the diff inside one document column. Do not add a second column.
- Mark each changed block with an inline word-level diff. Preserve links and bold text.
- Add a control to each changed block. The control records "reviewed".
- Persist reviewed state in `localStorage`. Use the block text as the identity key. Block movement does not lose state.
- Reopen a block when its text changes again.
- Show removed blocks and large rewrites in a "before" disclosure in the same column.
- Add a review toolbar with the remaining count, previous and next navigation, and an exit control.
- Keep the existing transient animation.
- Hide review annotations in print and in HTML export.

## Impact

- Affected specs: `review-mode` (new)
- Affected code:
  - `web-renderer/src/review-mode.ts` (new module)
  - `web-renderer/src/styles/review-mode.css` (new styles)
  - `web-renderer/src/index.ts` (render pipeline hook and JS API)
  - `web-renderer/test/review-mode.test.ts` (new tests)
