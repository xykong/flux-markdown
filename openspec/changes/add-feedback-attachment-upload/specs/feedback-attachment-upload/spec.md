## ADDED Requirements

### Requirement: Upload selected attachments before GitHub navigation
When a document is selected, continuing feedback SHALL upload its prepared ZIP to the disclosed fixed FluxMarkdown attachment service and receive confirmation of durable storage before opening GitHub. The product SHALL automatically include the validated download URL in the prefilled Issue body. Local ZIP preparation or opening Finder SHALL NOT count as upload. The attachment URL and incident identity SHALL survive prefill truncation.

#### Scenario: User continues with the default document selection
- **WHEN** a valid ZIP is selected and the user activates upload and continue
- **THEN** the file is uploaded and checked for download availability before GitHub opens with its download link already included

#### Scenario: Upload or verification fails
- **WHEN** the upload times out, storage rejects it or its download cannot be verified
- **THEN** the report and local document are preserved, the user can retry or exclude the attachment, and no attachment-free GitHub navigation occurs while selection remains enabled

### Requirement: Idempotent bounded attachment storage
The attachment service SHALL enforce file-size, global capacity and request-rate limits, validate ZIP input, calculate its own content digest, and atomically persist content and metadata before acknowledgement. Upload retries SHALL reuse a stable identity and reconcile uncertain results before sending another body. It SHALL use dedicated storage and SHALL NOT write documents into telemetry records or embed server credentials in the client.

#### Scenario: Upload succeeded but the response was lost
- **WHEN** the user retries the same incident and content
- **THEN** the client reconciles its prior upload and obtains the same verified object rather than producing another public file

### Requirement: Disclosed public sharing and retention
The dialog SHALL disclose the attachment service destination before transmission and allow users to exclude or change the file. Download links SHALL be unguessable and shareable with the public Issue, with no directory listing. Unclaimed uploads SHALL expire after seven days; claimed Issue attachments SHALL remain available until an explicit retention/deletion action. Deletion credentials SHALL never appear in public Issue text.

#### Scenario: User excludes the document
- **WHEN** the user deselects the document before continuing
- **THEN** no document upload is initiated and diagnostic-only feedback remains usable

### Requirement: Real attachment acceptance
Completion SHALL require a real upload through the configured HTTPS service, an independent full download matching the input digest and document, and inspection of the actual GitHub prefill containing a working link. A local fixture, mock receipt, health response or browser-open success SHALL NOT substitute for this acceptance.

#### Scenario: Service or publication verification is absent
- **WHEN** only client or isolated server tests have passed
- **THEN** implementation and real deployment/upload acceptance are reported separately and the feature is not described as fully delivered
