## ADDED Requirements

### Requirement: Bounded preview window
The system SHALL load at most 2 MiB of a Markdown file into a Quick Look
preview when it opens or re-forms the preview: the beginning of the file when
Follow is off, and the end of the file when Follow is on. This limit SHALL be
independent of the TSV and app limits. When Follow is off and the file exceeds
the limit, the system SHALL show a notice that says how much is shown and that
Follow shows the end, and SHALL keep the Follow control enabled.

#### Scenario: File above the limit with Follow off
- **WHEN** the user previews a Markdown file larger than 2 MiB and Follow is off
- **THEN** the preview shows a valid UTF-8 prefix of the first 2 MiB
- **AND** the incomplete-preview notice reads "Only the first 2 MB is shown. Click Follow Changes to see the end, or open the document in FluxMarkdown to read all of it."
- **AND** the Follow control is enabled

#### Scenario: Follow on hides the notice
- **WHEN** the user turns Follow on for that file
- **THEN** the notice disappears and a status line reads "Showing the last 2 MB of 10.6 MB."
- **AND** turning Follow off shows the beginning and the notice again

#### Scenario: Follow on hides the missing-image warning
- **WHEN** the followed part of a file references local images that cannot be read
- **THEN** no missing-image warning is shown while Follow is on
- **AND** the warning returns when Follow is turned off and the shown part still has such images

#### Scenario: File within the limit
- **WHEN** the user previews a Markdown file of 2 MiB or less
- **THEN** the whole file is shown and no limit notice appears

#### Scenario: File above the app limit
- **WHEN** the file is also larger than the app's 32 MiB document limit
- **THEN** the notice does not suggest opening the document in the app and offers Follow Changes instead

### Requirement: Follow shows the end of a large file
When Follow is turned on for a Markdown file larger than the preview limit,
the system SHALL show the last part of the file, at most 2 MiB, starting at a
line that is outside any fenced code block, and SHALL scroll to the end. Line
numbers shown and used for navigation SHALL be the file's own line numbers. A
followed file that grows past the limit SHALL continue to be followed. Turning
Follow off SHALL return to the beginning of the file.

#### Scenario: Follow turned on for a large file
- **WHEN** the user turns on Follow for a 10 MiB Markdown file
- **THEN** the preview shows the last 2 MiB or less of the file with its last line visible
- **AND** a status line states that the end of the file is shown and gives the file's size
- **AND** no limit notice is shown

#### Scenario: Window cut falls inside a code block
- **WHEN** the position 2 MiB before the end of the file is inside a fenced code block
- **THEN** the window starts at the first line after that position that is outside a fenced code block
- **AND** code and text in the window render as they do in the complete document

#### Scenario: Window starts with a rule
- **WHEN** the first line of the window is `---`
- **THEN** it is rendered as a rule, not read as front matter

#### Scenario: Followed file grows past the limit
- **WHEN** a followed file of less than 2 MiB grows beyond 2 MiB
- **THEN** Follow continues and the preview shows the end of the file

#### Scenario: Follow turned off on a large file
- **WHEN** the user stops following a file larger than the limit
- **THEN** the preview shows the beginning of the file and the limit notice

### Requirement: Sliding window while following
While following, the system SHALL keep at most 2.5 MiB of the file in the
preview by re-forming the window at the end of the file. It SHALL NOT move the
window while Follow is paused or text is selected; in that state it SHALL keep
at most 4 MiB and then hold further updates until Follow resumes.

#### Scenario: Long stream of appends
- **WHEN** another program appends 3 MiB to a followed file in small writes
- **THEN** the preview never holds more than 2.5 MiB
- **AND** the view stays at the end of the file
- **AND** the final content equals a fresh read of the end of the file

#### Scenario: Reading while the file grows
- **WHEN** the user has scrolled up, pausing Follow, and the file keeps growing
- **THEN** the content being read stays in place
- **AND** updates stop once the preview holds 4 MiB

#### Scenario: Follow resumes
- **WHEN** the user resumes Follow after updates were held
- **THEN** the preview shows the current end of the file

### Requirement: Nearest pages first
On a full render the system SHALL display the pages nearest the reading
position first — the first pages when Follow is off, the last pages when Follow
is on — and SHALL add the remaining content in slices that yield to scrolling
and input. Search, export, print, restoring a saved position and navigating to
a line SHALL wait for, or force, the remaining content. A newer render SHALL
cancel pending slices. A document that contains math MAY be displayed in a
single step.

#### Scenario: Opening a 2 MiB file
- **WHEN** the user previews a 2 MiB Markdown file with Follow off
- **THEN** the first pages are visible before the rest of the file is displayed
- **AND** the completed preview equals one displayed in a single step

#### Scenario: Follow on a large file
- **WHEN** Follow shows the end of a large file
- **THEN** the last pages are visible first and the end stays in view while earlier content is added above

#### Scenario: Export while content is still being added
- **WHEN** the user exports or prints before all content is displayed
- **THEN** the output contains the complete preview window

### Requirement: Incremental Follow updates
The system SHALL, while following, read only bytes appended since the last
verified snapshot and re-render only the affected trailing blocks. It SHALL
perform a full reload and render when the file is rewritten, shrinks or is
replaced, or when appended input can change earlier rendered meaning.

#### Scenario: Append to a large file
- **WHEN** another program appends paragraphs to a followed multi-megabyte file
- **THEN** only the appended bytes are read and earlier rendered blocks keep their DOM identity
- **AND** the result equals a fresh full render of the same preview window

#### Scenario: Appended reference definition
- **WHEN** the appended text defines a link reference used earlier in the preview window
- **THEN** the earlier link is updated by a full render

#### Scenario: Selection during an update
- **WHEN** the user has an active selection while new content arrives
- **THEN** the update waits until the selection ends, as Follow does today
