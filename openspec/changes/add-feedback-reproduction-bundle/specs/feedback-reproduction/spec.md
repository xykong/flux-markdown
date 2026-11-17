## ADDED Requirements

### Requirement: Optional reproduction material from the error
The product SHALL retain the existing one-action diagnostic-only feedback path and offer an optional reproduction-material action at the same error. Users SHALL be able to choose no content, a reviewable editable failed fragment, or a complete document, with separately selectable referenced local assets. The product SHALL explain that selected content will be sent to GitHub and may become public before any transfer. It SHALL NOT claim that filenames or content have been automatically anonymized.

#### Scenario: Share a complete public document
- **WHEN** the user selects the complete document and confirms the displayed material selection
- **THEN** the product prepares that document with the selected resources and diagnostics, without forcing a reduced fragment

#### Scenario: Decline content sharing
- **WHEN** the user selects no content or cancels material selection
- **THEN** diagnostic-only reporting and document recovery remain usable without content transfer

### Requirement: Incident-bound useful evidence
The product SHALL bind reproduction material to the selected incident and document generation, preserve formula delimiters and available reference context, and capture mathematical failure classifications using validated fixed codes. It SHALL identify unavailable error-time snapshots and distinguish later selected document versions. Content SHALL remain separate from automatic diagnostic history and the generic diagnostic URL.

#### Scenario: Document changes after failure
- **WHEN** the original snapshot is unavailable and the user chooses the current document
- **THEN** the bundle labels it as a later version and does not silently substitute it as the original failing input

### Requirement: Reviewable bounded reproduction package
The product SHALL produce a ZIP with selected source, safe diagnostics and a manifest; show included files, sizes and missing resources; enforce at most 100 files, 20 MB total input and a ZIP smaller than 25 MB; and provide actionable alternatives on failure. It SHALL NOT scan surrounding folders, follow escaping symlinks, fetch remote resources, or modify the original document. Quick Look handoff SHALL preserve existing sandbox and authenticated-peer boundaries without transporting bulk content inside the 16 KiB incident payload.

#### Scenario: Resource is unavailable or exceeds the budget
- **WHEN** a referenced resource cannot be read or the selected input exceeds a limit
- **THEN** the user sees the affected selection and can remove it or choose a fragment while retaining the original report

### Requirement: GitHub attachment handoff and truthful status
The product SHALL provide the prepared ZIP for inspection, saving and attachment to the prefilled GitHub page, explain the required browser attachment and publish steps, and distinguish prepared, browser opened, uploaded and submitted states. Browser acceptance SHALL NOT imply upload or submission. Upload failure or cancellation SHALL preserve the report and exported package without duplicate automatic uploads.

#### Scenario: User attaches the package in GitHub
- **WHEN** the product has prepared a ZIP and opened the form
- **THEN** it provides a draggable or selectable package and instructions to attach it in GitHub, explains that attachment upload transfers it immediately, and leaves final publication to the user

#### Scenario: Browser navigation fails
- **WHEN** GitHub cannot be opened
- **THEN** the same draft and ZIP remain available for save, copy and explicit retry with no false success claim
