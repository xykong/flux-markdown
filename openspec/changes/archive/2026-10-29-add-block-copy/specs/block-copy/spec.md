## ADDED Requirements
### Requirement: Optional block copy controls
The application SHALL default block copying on, share the preference with Quick Look, and display accessible localized controls only in app and full Quick Look previews.

#### Scenario: Preference and contexts
- **WHEN** copying is enabled
- **THEN** app and full Quick Look display controls on ordinary code, quotes and alerts; Finder compact previews do not
- **AND** disabling removes controls and their focus targets
- **AND** an explicitly saved disabled preference is preserved when the default changes

### Requirement: Accurate plain text
The renderer SHALL copy code text before line-number decoration, including its parsed trailing newline and tabs. Quotes SHALL include paragraphs separated by blank lines, list items on separate lines, nested quote contents once, link labels, image alt text, and alert titles without icons or Markdown quote markers. Rendered diagrams SHALL NOT receive code copy controls.

#### Scenario: Nested content
- **WHEN** a quote containing code and nested quotes is copied
- **THEN** its plain text contains each body once and excludes all controls and diagnostic text

### Requirement: Validated acknowledged copying
The native bridge SHALL validate main-frame origin, request shape, document generation and a 4 MiB UTF-8 limit. Only explicit trusted user activation SHALL initiate requests. Success SHALL follow a successful native write. Document text SHALL NOT enter diagnostics.

#### Scenario: Failure and stale requests
- **WHEN** copying fails, exceeds the limit, or its document is replaced
- **THEN** no success is reported for that request in another document
- **AND** actionable inline recovery and contextual reporting are available for current-document failures

### Requirement: Clean presentation and lifecycle
Controls SHALL support keyboard and assistive technology, avoid covering content, disappear with collapsed quotes, and be absent from exported HTML and printed/PDF output. Repeated rendering SHALL NOT accumulate listeners.

#### Scenario: Export
- **WHEN** a document with enabled copy controls is exported or printed
- **THEN** its content is preserved and copying controls and status messages are absent

### Requirement: Contextual control visibility
Copy controls SHALL appear when the pointer enters their code/quote region or keyboard focus enters their toolbar. On pointer/focus exit, controls SHALL wait 600 ms then fade out over 250 ms without moving document content. Reentry SHALL cancel hiding. Pending copies, brief success feedback and unresolved failures SHALL remain visible. Reduced-motion users SHALL not receive fade animations, and devices without hover SHALL retain visible controls.

#### Scenario: Hover and keyboard access
- **WHEN** the pointer leaves a block with no focused control or active feedback
- **THEN** its copy toolbar fades after the delay, while remaining reachable through keyboard navigation
- **AND** returning to the block or focusing its button reveals it immediately
