## ADDED Requirements
### Requirement: Private attachments by default
The system SHALL default each new report to private attachment submission and publish only a non-authorizing reference in the GitHub body. Public download SHALL require explicit per-report consent.
#### Scenario: Private submission
- **WHEN** the user continues without enabling public sharing
- **THEN** the receipt contains no URL, the client makes no attachment download and the Issue body contains only its reference
#### Scenario: Public submission
- **WHEN** the user explicitly enables sharing
- **THEN** the server records public visibility and the client verifies the complete download before adding its link
### Requirement: Enforced private access
The system SHALL deny public GET and HEAD for private blobs regardless of a known reference, upload or deletion key. Only authenticated server maintainers SHALL export private data, with a private audit record.
#### Scenario: Known private reference
- **WHEN** any public client requests its file or an admin download path
- **THEN** no attachment bytes are returned, including to the uploader
#### Scenario: Maintainer export
- **WHEN** an SSH-authenticated maintainer uses the service-account export CLI
- **THEN** a new0600 file and content-free audit entry are produced
### Requirement: Safe migration and retention
The system SHALL preserve existing explicitly public attachments, prevent old server rollback from exposing private rows, bind privacy choice to idempotent uploads, and expire private linked attachments within30days and unlinked within7days.
#### Scenario: Conflicting retry
- **WHEN** the same upload key is retried with a different sharing scope
- **THEN** the server rejects the change without changing visibility
#### Scenario: Old binary rollback
- **WHEN** legacy queries address the compatibility storage view
- **THEN** private rows remain absent from all legacy read paths
