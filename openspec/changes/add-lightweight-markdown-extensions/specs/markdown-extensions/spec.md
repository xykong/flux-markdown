## ADDED Requirements
### Requirement: Lightweight extended syntax
The shared renderer SHALL support markdown-it definition lists, abbreviation definitions and ++inserted text++ in rendered Markdown.
#### Scenario: Corpus excerpts
- **WHEN** a document contains the definition-list, abbreviation and insertion examples from issue #64
- **THEN** it renders semantic dl/dt/dd, abbr with a plain-text title, and ins content respectively.
### Requirement: Literal and document boundaries
The renderer SHALL preserve code literals and keep abbreviation definitions scoped to the current document.
#### Scenario: New document
- **WHEN** a defined abbreviation is used in a later document without its definition
- **THEN** it remains ordinary text and does not reuse the earlier tooltip.
#### Scenario: Code and unsafe definitions
- **WHEN** extension syntax occurs inside code or an abbreviation definition contains HTML-looking text
- **THEN** code stays literal and the tooltip cannot introduce executable HTML.
### Requirement: Existing reading and export behavior
The renderer SHALL preserve extended content in source view, readable search text and sanitized exports without introducing UI controls into exported content.
#### Scenario: Export
- **WHEN** supported extended content is exported
- **THEN** semantic elements and their visible content remain in HTML/PDF rendering paths.
