# Tasks

## 1. Diff engine

- [x] 1.1 Write tests for block matching. Match current blocks to baseline blocks with `diffArrays`.
- [x] 1.2 Implement `collectBlocks` for rendered DOM elements that have `data-source-line`.
- [x] 1.3 Implement `diffBlocks` that pairs a removed block and an added block as one modified block.
- [x] 1.4 Write tests for inline word marks. Keep links and bold text.
- [x] 1.5 Implement inline word marks with `diffWordsWithSpace` and text-node ranges.
- [x] 1.6 Write tests for large rewrites. Select the "before" disclosure above a threshold.

## 2. Review state

- [x] 2.1 Write tests for the reviewed store. Persist state in `localStorage`.
- [x] 2.2 Implement `ReviewStore` with a text hash as the identity key.
- [x] 2.3 Write tests for block reopening. A changed block is not reviewed.
- [x] 2.4 Implement block reopening with the text hash.

## 3. Review UI

- [x] 3.1 Write tests for the toolbar. Show the remaining count and the navigation controls.
- [x] 3.2 Implement the toolbar and the per-block control.
- [x] 3.3 Write tests for previous and next navigation.
- [x] 3.4 Implement previous and next navigation.
- [x] 3.5 Write tests for the "before" disclosure.
- [x] 3.6 Implement the "before" disclosure.

## 4. Integration

- [x] 4.1 Add `reviewMode` and `baselineContent` to `RenderOptions`.
- [x] 4.2 Call the review controller after the DOM update.
- [x] 4.3 Add `window.setReviewMode`, `window.exitReview`, and `window.reviewSummary`.
- [x] 4.4 Hide review annotations in print and in HTML export.
- [x] 4.5 Run `npm test` and `npm run build` in `web-renderer`.
