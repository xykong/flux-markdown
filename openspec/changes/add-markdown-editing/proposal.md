# Change: Add Lightweight Markdown Editing

## Why

FluxMarkdown is registered as the default app for Markdown files, but the
standalone app currently exposes only a read-only rendered preview and a
read-only source view. Opening another editor for a small correction adds
avoidable friction. Issue #29 asks for a simple raw-text editing mode that can
switch back to the existing preview.

## What Changes

- Keep rendered preview as the default standalone-app experience.
- Replace the standalone app's read-only source mode with an editable,
  plain-text Markdown mode backed by a native `NSTextView`.
- Bind editor changes directly to the SwiftUI `FileDocument` so native dirty
  state, Save, Save As, undo, and redo continue to work.
- Render the current in-memory text when switching back to preview, including
  unsaved edits.
- Keep view mode and editor state isolated per document window.
- Keep QuickLook read-only and retain the existing Open in External Editor
  command.
- Add BDD-style XCTest coverage and a real installed-app edit/save/reopen E2E
  workflow.

The first release does not add a side-by-side split editor, syntax-aware code
completion, formatting commands, or a new JavaScript editor dependency.

## Impact

- Affected specs: `markdown-editing` (new)
- Affected code:
  - `Sources/Markdown/MarkdownApp.swift`
  - `Sources/Markdown/MarkdownDocument.swift`
  - New native editor view/state under `Sources/Markdown/`
  - `Sources/Shared/NotificationNames.swift`
  - `Tests/MarkdownTests/`
  - `project.yml`
- User-facing behavior: the standalone app source toggle becomes an edit
  action; Finder QuickLook behavior is unchanged.

