## ADDED Requirements

### Requirement: Block-level diff

The renderer SHALL compare the current document to the baseline document at block level. A block is a rendered element that has the `data-source-line` attribute. The renderer SHALL pair a removed block and an added block as one modified block.

#### Scenario: Added block

- **WHEN** the current document has a block that the baseline document does not have
- **THEN** the renderer marks the block as added

#### Scenario: Removed block

- **WHEN** the baseline document has a block that the current document does not have
- **THEN** the renderer marks the block as removed

#### Scenario: Modified block

- **WHEN** a baseline block and a current block pair as modified
- **THEN** the renderer marks the current block as modified

#### Scenario: Equal document

- **WHEN** the current document text equals the baseline document text
- **THEN** the renderer shows no changed block

### Requirement: Inline word marks

For a modified block, the renderer SHALL mark added words and removed words inside the rendered HTML. The renderer SHALL NOT change the Markdown source. The renderer SHALL preserve links and bold text.

#### Scenario: Added word

- **WHEN** a modified block has a new word
- **THEN** the renderer wraps the word in an element with the `review-word-added` class

#### Scenario: Removed word

- **WHEN** a modified block loses a word
- **THEN** the renderer inserts the word as an element with the `review-word-removed` class

#### Scenario: Link text changes

- **WHEN** a modified block contains a link and the link text changes
- **THEN** the link element stays a link and the changed text carries a word mark

### Requirement: Large rewrite disclosure

The renderer SHALL use a similarity value for a modified block. The renderer SHALL show a "before" disclosure when the similarity value is below 0.4.

#### Scenario: Large rewrite

- **WHEN** the similarity value of a modified block is below 0.4
- **THEN** the renderer shows the baseline block in a "before" disclosure

#### Scenario: Removed block disclosure

- **WHEN** the renderer marks a block as removed
- **THEN** the renderer shows the baseline block in a "before" disclosure at the removal position

### Requirement: Reviewed state

The renderer SHALL add a control to each changed block. The control SHALL record the block as reviewed. The renderer SHALL persist the reviewed state. The review store SHALL use the normalized block text as the identity key.

#### Scenario: Mark block as reviewed

- **WHEN** the user uses the control of a changed block
- **THEN** the renderer records the block as reviewed and the remaining count decreases

#### Scenario: Persist after reload

- **WHEN** the user reloads the document and the block text does not change
- **THEN** the block stays reviewed

#### Scenario: Reopen a changed block

- **WHEN** the text of a reviewed block changes
- **THEN** the block is not reviewed

### Requirement: Review toolbar

The renderer SHALL show a toolbar when changed blocks exist. The toolbar SHALL show the remaining count. The toolbar SHALL provide previous, next, mark-all-reviewed, and exit controls.

#### Scenario: Remaining count

- **WHEN** changed blocks exist
- **THEN** the toolbar shows the number of changed blocks that are not reviewed

#### Scenario: Navigation

- **WHEN** the user uses the next control
- **THEN** the renderer scrolls to the next changed block that is not reviewed

#### Scenario: Exit review

- **WHEN** the user uses the exit control
- **THEN** the renderer removes the review annotations and the toolbar

### Requirement: Clean output

The renderer SHALL hide review annotations in print output. The renderer SHALL remove review annotations from HTML export output.

#### Scenario: Print

- **WHEN** the user prints the document
- **THEN** the review toolbar, the review controls, and the word marks do not appear

#### Scenario: HTML export

- **WHEN** the user exports the document to HTML
- **THEN** the review toolbar, the review controls, and the word marks do not appear
