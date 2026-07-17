## ADDED Requirements

### Requirement: Preview-first standalone workflow

The standalone app SHALL open Markdown documents in rendered preview mode and SHALL provide a command to switch the current document window into raw Markdown edit mode.

#### Scenario: Open a Markdown document

- **GIVEN** a Markdown document is opened in the standalone app
- **WHEN** its document window appears
- **THEN** the rendered preview is shown by default
- **AND** the document content is not editable until edit mode is selected

#### Scenario: Enter edit mode

- **GIVEN** a Markdown document is open in preview mode
- **WHEN** the user invokes the source/edit toolbar or menu command
- **THEN** the same window shows an editable plain-text representation of the
  complete Markdown source

### Requirement: In-memory preview synchronization

The standalone app SHALL render the current in-memory document text when the user switches from edit mode to preview mode, regardless of whether the document has been saved.

#### Scenario: Preview an unsaved edit

- **GIVEN** the user has changed Markdown text in edit mode without saving
- **WHEN** the user switches to preview mode
- **THEN** the preview renders the changed in-memory text
- **AND** the document remains marked as edited until saved

### Requirement: Native document persistence

The editor SHALL participate in the existing `FileDocument` lifecycle so standard Save and Save As commands persist exact UTF-8 Markdown content.

#### Scenario: Save and reopen an edit

- **GIVEN** the user changes a Markdown document in edit mode
- **WHEN** the user saves, closes, and reopens the file
- **THEN** the reopened editor contains the exact saved Markdown text
- **AND** the rendered preview reflects that saved text

#### Scenario: Preserve unsaved edits during reload

- **GIVEN** a document has unsaved editor changes
- **WHEN** a reload or external file-change event occurs
- **THEN** the app MUST NOT silently replace the unsaved in-memory text

### Requirement: Native editing behavior

The raw Markdown editor SHALL support standard macOS text editing behavior, including selection, copy, paste, undo, redo, and find, and SHALL disable automatic rich-text substitutions that alter Markdown punctuation.

#### Scenario: Undo and redo an edit

- **GIVEN** the editor has keyboard focus
- **WHEN** the user types text and invokes Undo followed by Redo
- **THEN** the text returns to its prior value and then reapplies the edit

#### Scenario: Enter Markdown punctuation

- **GIVEN** the editor has keyboard focus
- **WHEN** the user types quotes, dashes, asterisks, or backticks
- **THEN** the editor preserves the literal characters without smart
  substitution

### Requirement: Per-document isolation

Each standalone document window SHALL own independent edit text, selection, dirty state, and preview/edit mode.

#### Scenario: Edit one of two open documents

- **GIVEN** two Markdown documents are open in separate windows
- **WHEN** the user enters edit mode and changes the first document
- **THEN** the second document text and view mode remain unchanged

### Requirement: Read-only QuickLook boundary

The QuickLook extension SHALL remain read-only and SHALL NOT receive file write entitlements or expose editable controls.

#### Scenario: Preview an edited file in Finder

- **GIVEN** a Markdown file was saved from the standalone editor
- **WHEN** the user opens it with Finder QuickLook
- **THEN** QuickLook renders the saved content
- **AND** no editable text control is available
