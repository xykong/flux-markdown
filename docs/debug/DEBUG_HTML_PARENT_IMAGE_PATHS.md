# HTML Images Referencing Parent Directories

## Symptom

On 2026-07-20, previewing
`/Users/xykong/workspace/xykong/animal-workers/docs/requirements/bot-avatar-source-assets.md`
showed its local PNG images as yellow boxes. The document uses raw HTML to control image width:

```html
<img src="../assets/bot-avatars/source-pack/animal-chief/primary.png" width="160">
```

All 20 referenced files exist and are valid RGBA PNGs. The source pack is about 6.9 MB.

## Reproduction

1. Open the document above in Flux Markdown or Finder Quick Look.
2. Scroll to the `原图图鉴` table.
3. Observe yellow image placeholders instead of transparent character artwork.

## Root Cause

Three existing behaviors combine:

1. `MarkdownImageDataCollector` extracts only Markdown `![](...)` syntax, so raw HTML
   `<img src>` references are not inlined for Quick Look.
2. The TypeScript renderer rewrites only markdown-it image tokens. Raw HTML images keep their
   `../` source and bypass the `local-md://` handler.
3. `image-fallback.css` applies the yellow missing-image appearance to every local-looking
   source path before an actual load failure is observed.

The local scheme handler also correctly rejects an unapproved path outside the Markdown file's
directory. Parent references therefore need explicit, file-level authorization rather than a
broader directory exception.

## Acceptance Criteria

- Raw HTML `<img src>` references use supplied inline image data when available.
- Otherwise, local raw HTML image sources are rewritten to `local-md://` URLs while preserving
  attributes such as `width` and `alt`.
- A normalized parent-directory image is readable only when it was explicitly referenced by the
  current Markdown document.
- Unreferenced traversal and symlink escape requests remain rejected.
- Yellow fallback styling is applied only after the image emits a real `error` event.
- The reported Animal Workers document resolves all 20 image references.

## Verification Record

Completed on 2026-07-20:

- Renderer unit tests: 28 suites and 306 tests passed, including raw HTML inlining, parent-path
  normalization, attribute preservation, and failure-state styling.
- Swift regression tests: 20 focused collector/scheme-handler tests passed.
- Remaining Swift unit tests: 207 tests passed with `RenderBenchmarkTests` skipped. The complete
  command reached the existing WebKit cold-start benchmark but did not complete its first sample
  under the test sandbox, so it was interrupted after 165 seconds.
- Production renderer bundle built successfully with Vite.
- All 20 image references in the reported Animal Workers document resolve to existing PNG files.
- Flux Markdown CLI rendered the real document to a 7-page PDF containing 20 image objects and
  their 20 transparency masks. Visual inspection of pages 2-4 confirmed every character and atlas
  image rendered without a yellow placeholder.
