## 1. Proposal
- [x] 1.1 Locate the size barriers in the reader, the renderer and Follow.
- [x] 1.2 Compare other Markdown preview pipelines; assess a native renderer (out of scope).
- [x] 1.3 Approve the proposal, then the 2 MiB window revision.

## 2. Metrics
- [x] 2.1 Measure time to first text and the longest task after it.
- [x] 2.2 Generate transcript-shaped and diagrams-at-the-end fixtures (no real content).
- [ ] 2.3 Re-measure the integration candidate for 2 MiB head and tail renders and a whole-file line scan at 10 MiB, 100 MiB and 1 GiB.

## 3. Preview policy
- [x] 3.1 Add a Markdown preview policy with separate initial and Follow limits; keep the TSV and app limits.
- [x] 3.2 Replace the fixed 500 KiB notice and its localizations with the real limit; test limit −1, limit and limit +1, and UTF-8 cuts.

## 4. Incremental Follow
- [x] 4.1 Tests: incremental results equal a fresh full render for appends, open fences, lists, tables, references, footnotes and front matter.
- [x] 4.2 Native: skip unchanged files by revision and refresh bounded snapshots when changed; test an in-place edit followed by an append.
- [x] 4.3 Renderer: re-parse from the last stable top-level block and replace the DOM from there.
- [ ] 4.4 Measure update latency and memory during 30 minutes of appends with the 2 MiB window.

## 5. Follow shows the end
- [x] 5.1 Tests: window starts outside a top-level fenced code block when possible; window size −1, at and +1; every UTF-8 cut at the window start; line numbers equal the file's.
- [x] 5.2 Native: `readTail` with a chunked whole-file fence and line scan.
- [x] 5.3 Controller: Follow is enabled on files over the limit; Follow on reads the end, Follow off reads the beginning.
- [x] 5.4 Renderer: a tail option that skips front-matter detection and offsets source lines.
- [x] 5.5 Notices: limit wording that points to Follow, in six languages of both bundles.
- [x] 5.6 Update the `add-quicklook-follow-file` requirement "Bounded lifecycle and recoverable limits".

## 6. Sliding window
- [ ] 6.1 Test: 3 MiB appended in small writes; the shown window stays within 2 MiB and final content equals a fresh tail read.
- [x] 6.2 Refresh the tail on disk changes and hold the current window while Follow is paused or text is selected.

## 7. Nearest pages first
- [x] 7.1 Tests: the first commit holds only the nearest pages; the completed preview equals a single-commit render; search, export, print, position restore and line navigation see the whole window; a newer render cancels pending slices.
- [x] 7.2 Commit in slices in both directions; documents with math keep a single commit.
- [ ] 7.3 Real WebKit performance target: first text ≤ 300 ms and no task over 200 ms for a 2 MiB window.

## 8. Acceptance
- [ ] 8.1 Repeat Finder checks on this candidate with 2 MiB, 10 MiB and 100 MiB stream files: open, Follow, pause and resume, copy, search, source view, several previews at once, and the line-number gutter (numbers above 99,999 stay on one line).
- [x] 8.2 Update CHANGELOG with the behavior shipped by the candidate and contributor credit.
