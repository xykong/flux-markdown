## ADDED Requirements

### Requirement: Default-on collection with actionable opt-out
The application SHALL default to usage collection, disclose fields at first reading
with a direct disable action, and expose a localized shared settings switch.

#### Scenario: Disable and re-enable
- **WHEN** a user disables collection
- **THEN** new collection stops, unsent counters clear and the installation identity rotates
- **AND** re-enabling starts new counters without disabled-period activity

### Requirement: Partitioned persistent cumulative counters
The client SHALL persist cumulative seconds and document-view counts grouped by UTC
date, app version, macOS version and App/Quick Look source, with random bucket IDs
and monotonic sequences. It SHALL exclude document metadata, content and logs.

#### Scenario: Midnight or version transition
- **WHEN** the UTC date or version changes
- **THEN** new usage increments a separate bucket without resetting previous buckets

#### Scenario: Reload and repeated opening
- **WHEN** the same open document is automatically rerendered
- **THEN** the view counter does not increase
- **AND** reopening a closed document counts a new visible successful opening

### Requirement: Hourly shared upload budget
The client SHALL upload dirty cumulative snapshots at most once per hour across App
and Quick Look, never waking the computer or launching solely to send. It SHALL
retain at most 90 days and 720 buckets and send batches no larger than 50 buckets
or 64 KiB. Normal restart and upload acknowledgement SHALL NOT reset counters.

#### Scenario: Offline and ambiguous acknowledgement
- **WHEN** an upload fails or its acknowledgement is lost
- **THEN** cumulative values remain available for the next eligible hourly attempt
- **AND** rendering continues without waiting for a network response

#### Scenario: Usage advances during upload
- **WHEN** a snapshot is acknowledged after newer usage has accumulated
- **THEN** only the acknowledged sequence is marked delivered and newer values remain dirty

### Requirement: Durable snapshot storage and daily analysis
The Rust service SHALL persist accepted pseudonymous snapshots in local SQLite,
deduplicate by installation/bucket/sequence, and compute daily totals from each
bucket's highest accepted sequence rather than summing snapshots.

#### Scenario: Duplicate and out-of-order delivery
- **WHEN** an identical snapshot is retried or an older valid snapshot arrives
- **THEN** the service acknowledges it without increasing already-counted usage
- **AND** conflicting same-sequence values or newer counter regressions are rejected atomically

### Requirement: Bounded retention and restricted administration
Raw snapshots and daily counters SHALL expire after 180 days. Administrative
queries and deletion SHALL remain SSH-only; the public endpoint SHALL enforce
TLS, request size limits and rate limits without retaining request access logs.

#### Scenario: Retention timer runs
- **WHEN** records exceed their documented retention period
- **THEN** the daily local cleanup removes them
