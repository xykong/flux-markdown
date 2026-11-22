## ADDED Requirements
### Requirement: Discoverable zoom feedback
The reader SHALL show transient localized document or diagram zoom feedback without changing layout and SHALL document scoped pinch and smart-magnify reset gestures.
#### Scenario: Change document zoom
- **WHEN** the user changes document zoom
- **THEN** a transient accessible label identifies the document and percentage, while outline and controls retain their size

### Requirement: Focused diagram viewing
The reader SHALL offer a focused diagram view with fit-to-window, local 100%, zoom, pan and explicit close, preserving the original reading context.
#### Scenario: Inspect a large diagram
- **WHEN** the user opens and closes a large diagram
- **THEN** the same diagram remains interactive and the original reading position and focus return

### Requirement: Reading navigation history
The App SHALL provide bounded backward/forward navigation for in-document jumps and local document links, restoring the corresponding document zoom and reading anchor without recording normal scroll gestures as jumps.
#### Scenario: Follow a local document link and go back
- **WHEN** the reader opens a linked Markdown file then chooses Back
- **THEN** the original document and its previous reading location are restored, and Forward reopens the linked location

### Requirement: Semantic reading restoration
The reader SHALL save bounded per-file semantic anchors and document zoom locally without storing document text, falling back to the old scroll position when an anchor no longer exists.
#### Scenario: Content inserted before a saved paragraph
- **WHEN** a document is reopened or refreshed after content is inserted earlier
- **THEN** the same available paragraph is restored with its previous viewport offset

### Requirement: Diagram copy and export
The App SHALL copy diagram PNGs and save standalone PNG/SVG files with validated payloads and acknowledged outcomes, preserving the document on cancellation or failure.
#### Scenario: Export a diagram
- **WHEN** the reader confirms a PNG or SVG destination
- **THEN** a complete standalone artifact is written and can be independently read, while errors offer executable recovery and contextual feedback
