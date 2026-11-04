## ADDED Requirements

### Requirement: Traceable mathematical corpus
The renderer SHALL satisfy the valid mathematics in the unmodified issue #64 attachment using a versioned, independently reviewed expectation manifest. It SHALL distinguish valid formulas, intentional errors and protected non-mathematical source.

#### Scenario: Original attachment mathematics
- **WHEN** the original attachment is rendered with math enabled
- **THEN** its 11 valid TeX items and one valid MathML item render with the specified mathematical structure
- **AND** the intentionally unknown command produces one local mathematical failure without preventing subsequent content
- **AND** the currency and code samples are not counted as mathematical success cases

### Requirement: Source-preserving math recognition
The renderer SHALL recognize dollar and parenthesis inline math, double-dollar and bracket display math, and math fences within Markdown syntax boundaries. Selected AMS environments and standalone ref/eqref commands SHALL have explicit recognition rules and source locations.

#### Scenario: Mixed and nested mathematical input
- **WHEN** valid mathematics appears in paragraphs, lists, quotes, footnotes, headings or GFM table cells using valid Markdown escaping
- **THEN** the renderer preserves TeX content and renders the correct inline or display form
- **AND** it retains source positions for navigation and error recovery

#### Scenario: Protected or incomplete source
- **WHEN** mathematical-looking text occurs in ordinary code spans/fences, indented code, YAML, comments, URLs, HTML attributes, escaped currency or incomplete delimiters
- **THEN** it remains readable under the documented Markdown rules
- **AND** mathematical processing does not consume unrelated later content

### Requirement: Document-level equation identity and references
The renderer SHALL provide document-scoped AMS numbering, explicit tag/tag-star, label, ref and eqref semantics with forward and backward references. It SHALL validate target existence and validity, prevent ambiguous duplicate targets and preserve correct standard fragment links.

#### Scenario: Explicit tagged equation
- **WHEN** the source declares tag 1 with label eq:pythagoras and references it before or after the declaration
- **THEN** eqref displays (1) and points to the same valid equation
- **AND** pointer and keyboard activation reach that equation without colliding with headings or footnotes

#### Scenario: AMS numbering policy
- **WHEN** ordinary display delimiters, numbered AMS environments, starred environments and notag/nonumber occur in one document
- **THEN** AMS numbering and explicit overrides are applied consistently
- **AND** ordinary untagged display equations do not acquire automatic numbers merely by enabling this feature

#### Scenario: Invalid reference graph
- **WHEN** a label is duplicated, absent, unnumbered or belongs to a failed equation
- **THEN** a contextual local diagnostic identifies the unresolved condition
- **AND** duplicate declarations do not silently overwrite the first valid target
- **AND** a placeholder or link to the document top is not presented as a successful resolved reference

### Requirement: Render-session state isolation
The renderer SHALL isolate mutable TeX macros, counters, labels and DOM work by document render session and discard obsolete asynchronous results.

#### Scenario: Reused view and late completion
- **WHEN** a view renders A, switches to B, and an A task finishes late
- **THEN** B retains only B's content, labels and macros
- **AND** reopening A yields the same valid semantics as a fresh view

#### Scenario: Rerender and mode changes
- **WHEN** a document is rerendered, source mode is entered, math is disabled or the view is disposed
- **THEN** obsolete state is released and no duplicate labels or retained math items affect the next render

### Requirement: Offline bounded and sanitized output
The renderer SHALL load all selected mathematics components, glyph data, fonts and accessibility resources locally through approved bundle mechanisms. It SHALL enforce explicit package and resource limits and preserve required safe mathematical structure through shared sanitization.

#### Scenario: Cold offline valid rendering
- **WHEN** mathematical rendering starts with empty caches and external network requests denied
- **THEN** every valid corpus item completes using bundled assets
- **AND** SVG glyph references, labels, links and accessible semantics survive sanitization

#### Scenario: Unsupported active content or resource failure
- **WHEN** source attempts an unapproved extension, active content, external glyph load or resource budget violation
- **THEN** processing fails within a bounded operation while retaining the document
- **AND** executable content is not admitted through the mathematical output

### Requirement: Readable and accessible mathematics across hosts
The renderer SHALL preserve mathematical meaning and usable navigation across App, QuickLook and Finder, supported themes and systems, narrow/wide layouts, zoom and RTL content.

#### Scenario: Layout and assistive access
- **WHEN** the corpus is viewed at the specified widths and zoom levels in Chinese, English or RTL text
- **THEN** symbols, CJK text, equation numbers and matrix/cases structures are neither clipped nor obscured
- **AND** mathematics has correct direction, accessible semantics and keyboard-operable references
- **AND** assistive content does not introduce duplicate spoken or searchable text

### Requirement: Contextual mathematical failure recovery
The renderer SHALL use the shared ErrorIncident/ErrorFeedback flow for mathematical syntax, reference, module and resource failures, with preserved source, an executable recovery and contextual reporting in supported interface languages.

#### Scenario: Invalid command with valid following content
- **WHEN** an unsupported command fails in a mixed document
- **THEN** source and subsequent valid mathematics remain available
- **AND** the user can open the relevant editor or host and prepare contextual feedback from the failure
- **AND** default diagnostic payloads exclude mathematical content and private paths

### Requirement: Complete standalone export
The renderer SHALL include mathematical processing, reference resolution and resource readiness in export completion. HTML SHALL remain readable and internally navigable without the app or a math runtime. PDF/print SHALL preserve formulas, tags and pagination with verified and documented link behavior.

#### Scenario: Valid offline export
- **WHEN** a valid math document is exported and opened outside the app with networking disabled
- **THEN** formulas, glyph definitions, styles and equation tags are complete
- **AND** HTML references resolve using standard fragment links without runtime handlers

#### Scenario: Pending or failed mathematical output
- **WHEN** export is requested while math is pending or an equation/reference has failed
- **THEN** export waits for bounded completion or returns an actionable failure
- **AND** it does not report complete success for missing mathematical output

### Requirement: Independent acceptance and performance gates
Completion SHALL require source-based expectations, an independent semantic/numbering reference, actual native host and export checks, visual/accessibility review, and measured performance gates frozen before implementation. Mock success or nonempty output alone SHALL NOT satisfy acceptance.

#### Scenario: Detection of deliberately damaged output
- **WHEN** a reference target, number, glyph definition, required asset or asynchronous completion dependency is deliberately removed
- **THEN** the relevant acceptance check fails
- **AND** expected results are not regenerated from that damaged implementation to make the check pass

#### Scenario: No-math and large-document workloads
- **WHEN** fixed cold/warm and 100/1000-formula workloads are measured on the declared environment
- **THEN** time, memory and asset budgets meet the frozen thresholds
- **AND** no-math documents do not load math modules or fonts unnecessarily
