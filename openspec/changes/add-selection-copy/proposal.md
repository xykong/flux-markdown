# Change: Copy selected Quick Look content as plain text or Markdown

## Why

Existing copy controls target whole blocks. Users need to copy arbitrary selected
content in Finder's Space-bar Quick Look preview and choose between unformatted
text and Markdown syntax. Some hosts that embed Quick Look previews, such as
third-party file managers, never pass a right-click to the preview, so a menu
alone is not enough. FluxMarkdown's own document window is outside this change.

## What Changes

- Keep WebKit's own selection menu and Command-C; add Copy as Markdown to that
  menu, directly after Copy.
- Show a small toolbar beside a finished selection, with one button that copies
  plain text and one that copies Markdown. Both work with a click.
- Reuse validated native clipboard transport, with shared request ordering and
  selection authorization independent of block-button visibility.
- Preserve selected formatting semantically in Markdown; do not promise exact
  reconstruction of the original source.
- Enable the feature only in full Quick Look via an explicit extension capability
  and extension-only native authorization, including Quick Look source view.
- In the Quick Look extension, show Speech's Start Speaking and Stop Speaking
  directly in the selection menu: after any submenu of that menu opens, Quick Look
  stops passing the pointer to the preview until it is closed.
- Preserve the app's existing copying behavior and compact-preview policy.

## Impact

- Affected specs: new `selection-copy`; existing `block-copy` remains applicable.
- Affected code: new renderer selection module/styles/tests; shared block-copy
  transport; renderer lifecycle/export integration; the Quick Look extension's
  WebView context menu; extension-only selection-copy authorization; localization.
  Shared helpers must preserve app behavior.
- Host eligibility: the current size heuristic does not reliably tell a resized
  Space-bar preview from a Finder pane (task 1.4). Double Commander's Quick View
  panel (824×483) counts as compact, so it gets neither the toolbar nor the menu
  item; this is accepted. Its larger F3 viewer gets both.
- Status: implemented; copying both formats checked in Finder and in Double
  Commander's F3 viewer. Open: host classification, request ordering tests, wider
  Finder checks, large-document cost and math rules.
