## 1. Behavior Baseline

- [ ] 1.1 Record current standalone preview/source behavior and relevant test
  results.
- [ ] 1.2 Convert issue #29 scenarios into BDD-style XCTest names and fixtures.
- [ ] 1.3 Run the new tests before implementation and record the expected red
  failures.

## 2. Document and Editor State

- [ ] 2.1 Add per-document preview/edit mode state.
- [ ] 2.2 Expose a safe binding from `DocumentGroup` to
  `MarkdownDocument.text`.
- [ ] 2.3 Add tests proving two document windows do not share mode or text
  state.

## 3. Native Editor

- [ ] 3.1 Implement a plain-text `NSTextView` wrapper with undo enabled and
  smart substitutions disabled.
- [ ] 3.2 Preserve selection and focus across SwiftUI updates.
- [ ] 3.3 Apply the selected FluxMarkdown appearance and base font size.
- [ ] 3.4 Route standard find, undo, redo, copy, paste, and select-all commands
  to the focused editor.

## 4. Preview and Persistence

- [ ] 4.1 Render current in-memory edits when switching to preview.
- [ ] 4.2 Verify native dirty-state tracking and `Cmd+S` persistence.
- [ ] 4.3 Verify Save As and reopen preserve exact UTF-8 Markdown content.
- [ ] 4.4 Prevent manual/external reload from silently discarding unsaved
  edits.

## 5. Refactor and Regression

- [ ] 5.1 Remove obsolete standalone read-only source-mode plumbing while
  preserving QuickLook source mode.
- [ ] 5.2 Keep the existing toolbar appearance, zoom, reload, help, export,
  and external-editor workflows green.
- [ ] 5.3 Run complete Jest and targeted/full XCTest suites.
- [ ] 5.4 Build both Debug and Release configurations.

## 6. End-to-End Verification

- [ ] 6.1 Install a development build and open a disposable Markdown file.
- [ ] 6.2 Enter edit mode, type Markdown, undo/redo, save, and switch back to
  rendered preview.
- [ ] 6.3 Close and reopen the file and verify exact persisted content.
- [ ] 6.4 Open the same file in Finder QuickLook and verify it remains
  read-only and renders the saved content.
- [ ] 6.5 Verify independent behavior in two simultaneous document windows.

## 7. Delivery

- [ ] 7.1 Update user help and localized toolbar/menu labels.
- [ ] 7.2 Update CHANGELOG with issue #29 attribution.
- [ ] 7.3 Complete self-review, release verification, and issue response
  without closing the issue.

