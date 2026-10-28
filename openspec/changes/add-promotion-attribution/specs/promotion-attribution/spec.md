## ADDED Requirements

### Requirement: Stable first effective use
The client SHALL persist one lifecycle event per installation generation only after positive visible reading activity. Existing persisted states SHALL be marked upgraded rather than assigned a fabricated new first-use time.

#### Scenario: Concurrent app and Quick Look first use
- **WHEN** both sources record positive activity through the shared locked state
- **THEN** they share one stable event ID and the first successful writer's time/source

#### Scenario: Existing persisted state upgrades
- **WHEN** an older state without lifecycle fields is decoded
- **THEN** usage survives and the origin is upgraded_state without a new acquisition event

### Requirement: Independent lifecycle delivery
The client SHALL support v4 cumulative snapshots with independently acknowledged lifecycle metadata, and SHALL preserve the hourly automatic lease and v3 compatibility fallback.

#### Scenario: Usage accepted while lifecycle is retryable
- **WHEN** the server acknowledges counters but not lifecycle
- **THEN** counters are not recounted and a later eligible flush retries the same lifecycle event

### Requirement: Explicit source association
The host SHALL treat attribution URLs as untrusted input, require explicit confirmation, and exchange only a well-formed one-time code at the fixed promotion endpoint when usage statistics are enabled.

#### Scenario: Statistics disabled
- **WHEN** an attribution URL is received with usage statistics disabled
- **THEN** no claim request is sent and statistics are not enabled implicitly

#### Scenario: Untrusted target parameter
- **WHEN** the URL contains a callback, file path or arbitrary destination
- **THEN** it is rejected without opening files or making requests to the supplied destination
