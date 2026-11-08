## ADDED Requirements

### Requirement: One bounded observation session
The system SHALL collect concurrent evidence before one user-triggered update attempt, including host stages, installer/agent observations, targeted job state, relevant system events and baseline/final metadata, without changing update behavior.

#### Scenario: Existing failing installation
- **WHEN** a customer has unmodified 1.38.608 installed
- **THEN** the external collector starts without requiring an application upgrade or third-party runtime, signals readiness, and finalizes a local diagnostic bundle after one reproduction window.

#### Scenario: Missing operating-system evidence
- **WHEN** a log or job query is unavailable, denied, empty or times out
- **THEN** the coverage manifest distinguishes those states and does not interpret absent evidence as a nonexistent process or successful check.

### Requirement: Incident-correlated native update history
The application SHALL record bounded allowlisted update stages and freeze the relevant session into the existing contextual incident report before failure presentation or cleanup can alter it.

#### Scenario: Error presentation precedes abort callback
- **WHEN** Sparkle presents an error before notifying the abort delegate
- **THEN** the report contains the current session's available stages and terminal error, and the later callback does not create a conflicting incident or replace its snapshot.

#### Scenario: A later update cycle runs
- **WHEN** the user retries or the application restarts
- **THEN** a previously prepared incident retains its own history and the new session has distinct identity.

### Requirement: Private and bounded evidence collection
The system SHALL use explicit time, size and retention bounds, exclude private raw evidence from default exports, preserve partial diagnostics on collection failure, and avoid automatic uploads or mutations to app/security/service state.

#### Scenario: Raw logs contain private data
- **WHEN** logs contain user paths, tokenized URLs, document content or unrelated application events
- **THEN** the default bundle includes only validated structured facts, and raw text remains in a private local artifact excluded from sharing.

#### Scenario: Collection is interrupted or exhausted
- **WHEN** a command hangs, observation is cancelled, or an output limit is reached
- **THEN** owned collectors stop within defined deadlines and a partial bundle explains the incomplete coverage without terminating the application or updater.

### Requirement: Validate before requesting customer reproduction
The diagnostic tool SHALL pass local scenario, privacy, cleanup and real-update checks before requesting another customer reproduction, and SHALL distinguish observations from hypotheses.

#### Scenario: Known agent timeout evidence
- **WHEN** the #61 evidence contains EdDSA success and an agent connection timeout but no launchd/Updater records
- **THEN** the analysis identifies the confirmed connection timeout, lists the missing coverage and does not assert signature mismatch or on-demand scheduling as the proven root cause.
