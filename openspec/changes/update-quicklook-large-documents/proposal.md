# Change: Preview large Markdown files in Quick Look through a 2 MiB window

The first version of this change raised the size limit in steps to 32 MiB.
This version keeps the limit at 2 MiB and makes Follow show the end of the file.

## Why

Finder's Space-bar preview showed only the first 500 KiB of a Markdown file.
Agent transcripts and logs routinely pass that size, and can pass 10 MB. For
these stream files readers need the last pages, and wants to Follow the file
as it grows. Raising the limit does not serve that need: memory grew to about
1 GB at 16 MiB in earlier measurements, and a larger prefix still does
not show the end.

## What Changes

- **Bounded window.** A Quick Look preview loads at most 2 MiB of a Markdown
  file: the beginning when Follow is off, the end when Follow is on. TSV and
  app limits are unchanged.
- **Limit notice and Follow button.** When Follow is off and the file is over
  the limit, the incomplete-preview notice says only the first 2 MB is shown
  and that Follow Changes shows the end. The notice hides while Follow is on
  and returns when it is turned off. The Follow button stays enabled.
- **Follow shows the end.** Follow on a file over the limit shows its last
  2 MiB, starting at a line outside any fenced code block, with the file's own
  line numbers. A followed file that grows past the limit keeps being followed;
  today Follow stops.
- **Sliding window.** While following, the preview holds at most 2.5 MiB and
  re-forms the window at the end of the file. The window does not move while
  Follow is paused or text is selected; it then holds at most 4 MiB.
- **Nearest pages first.** A full render shows the first pages (Follow off) or
  the last pages (Follow on) first, and adds the rest in slices that yield to
  input.
- **Incremental Follow**: read only appended bytes, parse
  only the affected tail, and fall back to a full render when earlier meaning
  can change.
- Copy, search, source view and export keep working; inside a window they
  cover the window only.

## Removed from this change

- Text before math, and viewport-driven deferred decoration of diagrams and
  math. They help documents dense in diagrams and math, not stream files. They
  need their own change if they become a priority.
- `content-visibility` and long-line layout work, and the decoded-image pixel
  bound.
- Raising the limit to 8 MiB and then 32 MiB. The window replaces it.
- The native Swift/TextKit 2 large-document mode stays out of scope.

## Impact

- New capability: `quicklook-large-documents`.
- Supersedes one requirement of `add-quicklook-follow-file`: "Bounded lifecycle
  and recoverable limits" says Follow stops when the document exceeds the
  preview limit. Task 5.6 updates it.
- Limits accepted inside a window: link definitions, footnotes and front
  matter before the window do not apply; search, contents, copy and export
  cover the window; heading ids are unique within the window.
- With line numbers on, large pages lay out every block: skipping distant
  blocks would clip the numbers in the gutter.
- Code: `Sources/Shared/BoundedFileReader.swift`, `QuickLookFollowState.swift`,
  `Sources/MarkdownPreview/PreviewViewController.swift`; notices in six
  localizations of both bundles; `web-renderer/src/index.ts`, `follow-file.ts`,
  `segments.ts`.

## Stop Following on a file over the limit

The preview returns to the beginning of the file and shows the limit notice, so
there are two states only. The alternative, staying on the end with updates
stopped, would need a third state and a "Show beginning" control.
