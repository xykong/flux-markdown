## Context

The standalone app uses `DocumentGroup` with `MarkdownDocument: FileDocument`.
`DocumentPreviewScene` currently receives an immutable document value and
renders either preview or source through `MarkdownWebView`. Its view mode is
owned by `MarkdownApp`, so multiple document windows can share mode state.

An older local `feature/markdown-editor` worktree proves that a native
`NSTextView` can provide plain-text editing and undo, but it predates the
current toolbar, window restoration, renderer loading, Typst, line-number, and
release-entitlement changes. It is a reference, not a merge candidate.

## Goals / Non-Goals

Goals:

- Edit raw Markdown in the standalone app without leaving FluxMarkdown.
- Preserve the existing preview-first workflow and renderer.
- Use native document saving, dirty-state tracking, undo, redo, and find.
- Keep document windows independent.
- Verify the user workflow through an installed build.

Non-goals:

- Editing inside QuickLook.
- A side-by-side split view in the first release.
- Markdown language-server features, completion, or formatting.
- Replacing `markdown-it` or embedding a web editor such as CodeMirror.

## Decisions

### Native editor backed by the document binding

`DocumentPreviewScene` will receive a binding to `MarkdownDocument` or its
`text` property. A small `NSViewRepresentable` will host a plain-text
`NSTextView` configured with native undo support and smart substitutions
disabled.

This keeps persistence under `DocumentGroup` instead of introducing a second
save pipeline.

### Preview and edit modes, owned per window

Each `DocumentPreviewScene` will own its own mode state. Preview remains the
default. The current source toolbar/menu command switches to the native editor;
switching back renders the current binding value.

The first release intentionally avoids split mode. It solves the reported
workflow with less layout and renderer lifecycle risk.

### Native editing commands

When edit mode is active, focus remains in `NSTextView`, allowing standard
undo, redo, selection, copy/paste, and find behavior. Preview-only commands
must not swallow native editor commands.

### QuickLook stays read-only

No editable control or write entitlement is added to the QuickLook extension.
The existing source display in QuickLook remains a read-only renderer mode.

## Risks / Trade-offs

- The native editor does not initially provide syntax highlighting.
  This is acceptable for the requested lightweight editing workflow.
- Replacing the standalone read-only source renderer changes its visual
  presentation. BDD and E2E coverage will protect content fidelity, theme
  behavior, saving, and preview transitions.
- External file changes can race with unsaved edits. The implementation must
  not silently reload over an edited document; existing manual reload behavior
  will be tested before release.

## Migration Plan

There is no stored-data migration. Existing Markdown files and preferences
remain unchanged. The edit mode is additive to the standalone app and can be
rolled back without changing file formats.

## Open Questions

- None for the initial scope. Split editing can be proposed separately after
  the preview/edit workflow is released and validated.

