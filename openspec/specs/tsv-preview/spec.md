# tsv-preview Specification

## Purpose
Provide safe, bounded, read-only TSV table viewing in Finder QuickLook and the host application.
## Requirements
### Requirement: Native TSV opening
The system SHALL register TSV for QuickLook and allow read-only TSV viewing through the host application's file opening and handoff paths without claiming default editor ownership.

#### Scenario: Finder and host application
- **WHEN** the user previews a .tsv file or opens it in FluxMarkdown
- **THEN** the system selects TSV rendering, including uppercase .TSV filenames
- **AND** existing Markdown formats retain their behavior

### Requirement: Literal TSV semantics
The renderer SHALL display UTF-8 TSV with optional BOM as literal text cells, using Tab field separators and LF, CRLF or CR record separators, without interpreting quotes, Markdown, HTML or formulas. It SHALL preserve empty fields, whitespace and interior blank records and treat the first record as data.

#### Scenario: Empty and uneven fields
- **WHEN** input includes consecutive or trailing Tabs and rows of differing widths
- **THEN** fields remain in their original columns, shorter rows are padded and generated column headings do not consume the first record

#### Scenario: Unsafe-looking data
- **WHEN** cells contain scripts, image markup, Markdown, formulas or quote characters
- **THEN** the contents appear as text without execution or resource loading

#### Scenario: Empty document and final newline
- **WHEN** the file is empty or contains only a BOM
- **THEN** a localized empty state is shown
- **AND** a terminating newline in a nonempty file does not create an extra record

### Requirement: Bounded and honest preview
The system SHALL bound explicit TSV file reads to 500 KiB plus one probe byte and decode only a 500 KiB prefix of system-provided FileDocument data and display no more than 1,000 rows, 100 columns and 20,000 cells including padding. It SHALL identify truncated previews without inventing full-file counts or presenting byte-truncated records as complete.

#### Scenario: Byte limit interrupts a record
- **WHEN** the input exceeds the byte budget
- **THEN** only complete records within the budget are displayed and a localized truncation notice is shown
- **AND** if no record fits, an explicit record-too-large explanation is shown

#### Scenario: Row or column budget reached
- **WHEN** records exceed any display budget
- **THEN** parsing and rendered nodes remain bounded and the displayed range and limit are explained
- **AND** source view and available exports retain preview-limit information

### Requirement: Integrated accessible viewing
TSV viewing SHALL support light/dark themes, font and zoom controls, horizontal scrolling, keyboard-accessible semantic tables and selectable text. Existing source/search/reload/export controls SHALL behave consistently with previewed data, and TSV SHALL not create Markdown headings or leak state to subsequent documents.

#### Scenario: Format and theme changes
- **WHEN** a reused view switches between TSV and Markdown or changes theme/source mode
- **THEN** the current format displays correctly without stale tables, headings or truncation notices

### Requirement: Recoverable failures
TSV read and render failures SHALL use shared ErrorIncident / ErrorFeedback with executable recovery and contextual reporting, without including document contents or private paths in diagnostics.

#### Scenario: Unsupported encoding or read failure
- **WHEN** a TSV file cannot be decoded as UTF-8 or read
- **THEN** the user sees a localized explanation, an actionable recovery and contextual report action
- **AND** reporting and dismissal preserve the source file

