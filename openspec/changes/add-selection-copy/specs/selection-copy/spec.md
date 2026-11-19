## ADDED Requirements

### Requirement: Compact image Markdown
When converting partly selected rendered content to Markdown, an image whose file
source is a document-relative path SHALL copy as that path, however the preview
displays it. Without such a path, Base64 payloads longer than 200 characters and
the preview's internal `local-md:` addresses SHALL be omitted; web addresses and
shorter payloads SHALL be kept.

#### Scenario: Image-only link left out
- **WHEN** the only content of a selected link is an omitted image
- **THEN** no empty Markdown link remains
- **AND** plain-text alt text, source-view selections, code literals and whole blocks copied as their source are unchanged

#### Scenario: Local image displayed by the preview
- **WHEN** a selected local image was rendered as a Base64 payload of any length or through a `local-md:` address
- **THEN** copied Markdown uses the preserved original relative image URL

#### Scenario: Embedded image without a relative source
- **WHEN** a selected Base64 image exceeds 200 payload characters and has no original relative source
- **THEN** copied Markdown contains neither the image tag nor its Base64 payload
- **AND** surrounding selected text remains readable

### Requirement: Quick Look only scope
The system SHALL enable selection copying only for Markdown in Finder's full
Quick Look, including source view, with explicit capability and native
authorization. App, compact, unsupported-format and missing-context renders SHALL
disable this feature and preserve their existing selection and copy behavior.

#### Scenario: Resize a Space-bar preview
- **WHEN** a full Quick Look window is resized across the existing compact-size threshold
- **THEN** feature eligibility follows verified host policy rather than assuming window dimensions prove the host type
- **AND** any unresolved host distinction is recorded as an acceptance blocker, not a passed compact-preview exclusion test

#### Scenario: Missing context or unsupported format
- **WHEN** render options omit explicit selection capability or identify a non-Markdown format
- **THEN** no selection-copy controller is installed and previous controller state is disposed

#### Scenario: Open the document in FluxMarkdown
- **WHEN** the document is displayed directly in the FluxMarkdown app
- **THEN** this feature installs no selection listeners, context-menu entries or floating toolbar
- **AND** selection-copy bridge requests are rejected without changing existing block-copy behavior

#### Scenario: Full Quick Look preview or source view
- **WHEN** the extension renders an expanded Quick Look document in preview or source view with explicit authorization
- **THEN** selection-copy actions are enabled for that context
- **AND** entering app, compact or missing-context rendering disposes the selection controller and disables its requests

### Requirement: Standard Copy command
Command-C and the Copy item of the selection menu SHALL keep WebKit's standard
copy behavior in full Quick Look. The feature SHALL NOT intercept them.

#### Scenario: Copy a selection with Command-C
- **WHEN** the user selects document text and presses Command-C
- **THEN** WebKit copies the selection as it does without this feature

### Requirement: Selection format choices
The system SHALL keep WebKit's selection menu and add Copy as Markdown directly
after its Copy item, without a keyboard equivalent, only when WebKit offers Copy.
The selection toolbar SHALL offer plain text and Markdown. Markdown output SHALL
preserve selected content and semantic formatting as a string without including
unselected text.

#### Scenario: Partial bold phrase
- **WHEN** only “world” is selected inside the bold phrase “hello world”
- **THEN** copying as plain text produces `world`
- **AND** copying as Markdown produces `**world**`

#### Scenario: Selection menu
- **WHEN** the user right-clicks a selection in full Quick Look
- **THEN** the menu keeps its system items and shows Copy as Markdown directly after Copy
- **AND** without a selection, the menu has no Copy as Markdown item

#### Scenario: Source view
- **WHEN** either format is copied from a Quick Look source-view selection
- **THEN** the selected literal source characters are copied
- **AND** generated diff markers and deleted historical lines are excluded

#### Scenario: Whole blocks
- **WHEN** a selection copied as Markdown contains all the text of a top-level block, such as a heading, list, table, code block, alert, math block or Mermaid diagram
- **THEN** that block is copied as its exact source lines, so Markdown editors render it again
- **AND** a partly selected block, and any block inside it, is converted from the selected part instead
- **AND** a whole Mermaid diagram inside a partly selected block is copied as its fenced `mermaid` source
- **AND** plain-text copies keep the readable text

#### Scenario: Unsupported partial structure
- **WHEN** a selection contains only part of a rendered formula, diagram or table that cannot be meaningfully represented structurally
- **THEN** the unsupported part is copied as selected readable text with appropriate escaping
- **AND** no unselected formula source, diagram source or table cells are invented or included

### Requirement: Contextual selection toolbar
The system SHALL show localized accessible copy buttons near a completed nonempty
document selection when copy buttons are enabled: one copies plain text, one
copies Markdown, each with a single click and without a format chooser, so that
hosts that never pass a right-click to the preview can copy both formats. It SHALL
preserve selection on activation, stay within the visible viewport, and support
keyboard selection and operation. Selecting text alone SHALL NOT write to the clipboard.

#### Scenario: Complete selection and choose format
- **WHEN** a selection gesture finishes and the user clicks the plain-text or the Markdown button
- **THEN** the previously selected range is copied in that format without losing it to button focus
- **AND** the buttons appear next to where the pointer let go of the selection, or by the selected text for a keyboard selection

#### Scenario: Right-click a selection
- **WHEN** the user right-clicks inside a selection
- **THEN** the toolbar stays where it is and the selection is kept for the menu

#### Scenario: Copy report
- **WHEN** a copy from the toolbar or from Copy as Markdown in the menu succeeds
- **THEN** a status beside the selection reports how many lines were copied and in which format for two seconds, also when copy buttons are disabled

#### Scenario: Block copy with a selection
- **WHEN** text is selected and the user clicks a block's copy button
- **THEN** the block is copied, the selection toolbar closes and the selection is cleared

#### Scenario: Dismiss and move
- **WHEN** Escape, an empty selection, outside interaction or document replacement occurs
- **THEN** the popup closes
- **AND** scrolling, resizing or zoom changes reposition it or hide it when the selection leaves the viewport

#### Scenario: Hidden buttons
- **WHEN** the existing copy-button preference is disabled
- **THEN** the selection popup and existing block buttons are hidden
- **AND** Command-C and Copy as Markdown in the selection menu remain available in supported contexts

### Requirement: Shared validated clipboard lifecycle
Selection copying SHALL reuse acknowledged native string writes, main-frame origin
validation, generation checks and the 4 MiB UTF-8 bound. Block and selection
requests SHALL share monotonically increasing request IDs. Copies SHALL require
explicit user activation; document content SHALL NOT enter diagnostics.

#### Scenario: Stale or oversized selection
- **WHEN** a selection belongs to a replaced document or exceeds the payload bound
- **THEN** no truncated or stale clipboard write is made and no success is reported
- **AND** current-document failures retain the selection and provide actionable recovery and contextual feedback

#### Scenario: Alternate block and selection copying
- **WHEN** the user alternates block and selection copy actions
- **THEN** valid requests remain correctly ordered and each success follows an acknowledged clipboard write

#### Scenario: Conversion and acknowledgement races
- **WHEN** a selection changes during conversion or a copy acknowledgement arrives after timeout
- **THEN** invalidated unposted conversion cannot write to the clipboard
- **AND** a late result cannot replace feedback for a newer selection or document
- **AND** timeout is presented as unconfirmed delivery without automatic retry or a claim that the clipboard was untouched

#### Scenario: No eligible selection
- **WHEN** Copy as Markdown is invoked without an eligible document selection
- **THEN** nothing is written to the clipboard and no success is reported

### Requirement: Presentation and host compatibility
Selection controls SHALL be absent from exported HTML and printed/PDF output,
SHALL dispose listeners and pending UI on document changes, and SHALL preserve
existing compact-preview restrictions and block-copy behavior.

#### Scenario: Render and export lifecycle
- **WHEN** a document is rerendered or exported with an active selection toolbar
- **THEN** no stale listeners or controls remain in the new document or exported output
- **AND** the document content and existing block-copy behavior are preserved

### Requirement: Quick Look input stays with the preview
In the Quick Look extension, the selection menu SHALL show Speech's items (Start
Speaking, Stop Speaking) directly instead of in a submenu. After any submenu of
that menu opens, Quick Look delivers later clicks without a position and stops
delivering drags and scrolls until the preview is closed. The app window keeps the
Speech submenu, and the system selection button (Ask Siri) stays available.

#### Scenario: Selection menu in Quick Look
- **WHEN** the user right-clicks a selection in full Quick Look
- **THEN** Start Speaking and Stop Speaking appear where the Speech submenu was
- **AND** Speech has no submenu
