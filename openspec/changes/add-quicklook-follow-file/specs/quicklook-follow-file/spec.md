## ADDED Requirements

### Requirement: Explicit Quick Look Follow control
The system SHALL provide a session-local Follow Changes control in its expanded
Markdown Quick Look toolbar, defaulting to off and exposing accessible localized
active, paused, resume and off states. It SHALL NOT enable this capability in app
document windows, source view, compact preview or other document formats.

#### Scenario: Activate and leave a preview
- **WHEN** the user enables Follow for an eligible document
- **THEN** the current content refreshes and the viewport moves to its end
- **AND** changing file, closing/hiding the preview or leaving the eligible mode resets Follow and cancels pending work

### Requirement: Correct affected-content updates
The system SHALL detect readable file changes, validate append status against
previous content, and preserve semantically unchanged leading DOM nodes when safe.
It SHALL render Markdown correctly when appended input changes previous blocks,
using a full-render fallback when safe partial replacement is not possible.

#### Scenario: Append independent blocks
- **WHEN** new paragraphs are appended without changing earlier rendered meaning
- **THEN** earlier unchanged nodes retain identity and only the affected suffix is replaced
- **AND** their copy controls and interactive state remain functional

#### Scenario: Appending changes earlier meaning
- **WHEN** new input extends a fence, table or list, or resolves an earlier reference
- **THEN** every affected block is updated and the final content agrees with a fresh full render

#### Scenario: File rewritten or replaced
- **WHEN** the new snapshot does not extend the previous snapshot or the file is replaced
- **THEN** the system refreshes safely without assuming size growth proves an append

### Requirement: Respect reading and copying
The system SHALL follow the bottom only while actively following. User scrolling,
navigation or selection SHALL pause bottom tracking. Updates SHALL NOT destroy
an active selection before it can be copied. Paused previews SHALL hold their
last window until Resume reads the latest snapshot.

#### Scenario: Read earlier content and resume
- **WHEN** the user scrolls upward while new content arrives
- **THEN** the reading anchor is preserved without forcing a jump to the bottom
- **AND** Resume Following applies current content and returns to the end

#### Scenario: Pause, resume or stop Follow from its button
- **WHEN** Follow is paused after the user scrolled or selected text
- **THEN** the Follow button shows the paused state as an orange icon instead of the blue filled circle
- **AND** one click resumes Follow and moves the preview to the end of the file
- **AND** a double click turns Follow off, and later file changes no longer move the view
- **AND** Resume Following and Stop Following stay available from the button's menu

#### Scenario: New lines while paused
- **WHEN** Follow is paused and the file changes
- **THEN** the view stays where the reader is
- **AND** the reading status shows "Document updated" until Follow resumes or stops

#### Scenario: Turn Follow on with text selected
- **WHEN** text is selected and the user turns Follow on
- **THEN** the selection is cleared and the preview moves to the end of the file

#### Scenario: Copy during updates
- **WHEN** the user selects content or clicks a code copy button as the file grows
- **THEN** copy behavior and native acknowledgement remain correct
- **AND** a code copy button requires only one click

### Requirement: Bounded lifecycle and recoverable limits
The system SHALL use bounded short-lived file reads, bounded coalescing and
document-generation checks. It SHALL NOT hold a file descriptor for the lifetime
of a Quick Look preview. It SHALL preserve the last good view on read failure.
A document larger than the preview limit SHALL be followed through a window at
the end of the file, as specified by `update-quicklook-large-documents`.

#### Scenario: Rapid writes and stale callbacks
- **WHEN** writes arrive faster than updates complete or the preview switches files
- **THEN** updates coalesce without an unbounded queue
- **AND** the final readable snapshot is eventually displayed only in its matching active document

#### Scenario: Unavailable file
- **WHEN** the file cannot be read
- **THEN** Follow pauses or stops with a clear reason and appropriate executable recovery
- **AND** shared contextual error feedback is available without discarding the last good view

#### Scenario: File larger than the preview limit
- **WHEN** the followed file is larger than the preview limit
- **THEN** Follow continues and shows the end of the file
