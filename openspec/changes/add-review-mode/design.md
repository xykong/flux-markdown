# Design: Review mode

## Context

The renderer already computes a line diff with `diff-engine.ts`. The renderer also annotates rendered DOM blocks with `data-source-line` and `data-source-line-end`. The existing diff animation uses these attributes. Review mode reuses the same attributes.

## Decisions

### Block identity

The renderer identifies a block by the normalized text of the block. The renderer hashes the text. The hash is the identity key in the review store. Therefore block movement does not change the key. A text change produces a new key. The new key is not reviewed. This behavior reopens a changed block.

### Block diff

The renderer compares the block text list of the current document to the block text list of the baseline document. The renderer uses `diffArrays`. The renderer pairs a removed block and an added block as one modified block.

### Inline word diff

The renderer compares the rendered text of a modified block to the rendered text of the baseline block. The renderer uses `diffWordsWithSpace`. The renderer wraps added text in a span. The renderer inserts removed text as a `del` element. The renderer operates on text nodes only. Therefore links and bold text stay intact.

### Large rewrites

A similarity value below 0.4 marks a large rewrite. A large rewrite shows a "before" disclosure. A large rewrite does not use inline word marks. The "before" disclosure shows the baseline block HTML.

### Persistence

The review store writes to `localStorage` under the key `flux-review:<documentKey>`. The document key is the base URL path of the document. If `localStorage` is not available, the store stays in memory.

### Baseline

The baseline is the previous document text in the current session. Git or snapshots are out of scope for this change.

### Print and export

Review annotations do not appear in print or in HTML export. Print CSS hides the review elements. The export function removes the review elements.
