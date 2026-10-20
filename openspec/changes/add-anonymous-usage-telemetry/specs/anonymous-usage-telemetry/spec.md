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


### Requirement: Unambiguous global timestamps
New clients SHALL send integer Unix seconds as `timestamp` and per-bucket
`day_start_timestamp`, with explicit UTC daily boundaries. They SHALL NOT send
local date/time strings or timezone offset strings. The server SHALL validate
units and boundaries, preserve client and receipt timestamps separately, and keep
legacy v2 counter identities compatible.

#### Scenario: Timezone or daylight saving changes
- **WHEN** the same instant is observed under another user timezone or DST offset
- **THEN** its uploaded timestamp and UTC daily bucket start remain identical

#### Scenario: Same snapshot retried at a different time
- **WHEN** a retry has a later upload timestamp but the same bucket and sequence
- **THEN** it is acknowledged without duplicate usage or conflicting counter identity


### Requirement: Minimal batch timezone metadata
The client SHALL send one IANA `timezone_id` per batch when known, alongside the
Unix `timestamp`. Daily snapshots SHALL retain `day_start_timestamp` without
repeating timezone metadata or transmitting `utc_offset_seconds`.

#### Scenario: User switches timezone
- **WHEN** the system timezone changes between uploads
- **THEN** the next batch carries the current identifier without resetting UTC counters

#### Scenario: Timezone distribution over a selected interval
- **WHEN** an administrator requests a half-open Unix-time interval [start,end)
- **THEN** each participating installation is assigned once to its latest reported timezone in that interval, regardless of arrival order
- **AND** missing metadata is classified as unknown and invalid identifiers are rejected
