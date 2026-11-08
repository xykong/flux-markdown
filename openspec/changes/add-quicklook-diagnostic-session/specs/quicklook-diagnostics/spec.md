## ADDED Requirements
### Requirement: Correlated diagnostic stages
The system SHALL correlate dedicated self-test and Finder fixtures separately by UUID and expected extension executable, version and build.
#### Scenario: Other copy renders
- **WHEN** another extension copy emits a matching token
- **THEN** the report records a copy mismatch and does not claim expected-copy success.
#### Scenario: Finder invokes multiple previews
- **WHEN** compact and full previews open the same fixture
- **THEN** request UUIDs and preview contexts keep their stages separate, and the report does not infer host identity from a fixture token.
### Requirement: Bounded private collection
The collector SHALL operate without repairs or uploads, bound capture duration and size, and export only allowlisted diagnostics.
#### Scenario: Private raw messages
- **WHEN** logs contain document paths, content or arbitrary error descriptions
- **THEN** those fields remain outside the shareable archive.
#### Scenario: Capture interrupted
- **WHEN** the user interrupts or a collection command fails
- **THEN** partial evidence and capture-health status remain available without claiming the extension failed.
### Requirement: Independent host outcomes
The report SHALL distinguish self-test evidence, Finder evidence and the user's visible outcome.
#### Scenario: Self-test passes but Finder evidence is absent
- **WHEN** only the self-test completes
- **THEN** Finder is unconfirmed and provider-selection or launch failure is not asserted as proven.
