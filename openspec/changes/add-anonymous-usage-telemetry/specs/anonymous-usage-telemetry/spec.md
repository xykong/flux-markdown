## ADDED Requirements

### Requirement: Default-on anonymous collection with opt-out

The application SHALL enable anonymous usage collection by default, disclose the collected categories, and provide a visible setting that disables future collection.

#### Scenario: User disables collection
- **WHEN** the user turns off anonymous usage collection
- **THEN** the client stops creating new telemetry events and deletes unsent local events

#### Scenario: Service is unavailable
- **WHEN** an upload fails or the telemetry service is unreachable
- **THEN** preview, rendering, updates, and normal application behavior continue without blocking

### Requirement: Minimal usage events

The client SHALL upload only schema-versioned events containing anonymous installation/session identifiers, client and macOS versions, architecture, channel, timestamps, event type, active duration, and document-view counts where applicable.

#### Scenario: Document preview is recorded
- **WHEN** the App renders a document or Quick Look starts a preview session
- **THEN** the client records a count event without the document name, path, URL, content, or raw logs

### Requirement: Durable raw event storage

The telemetry service SHALL validate and persist each accepted event record, deduplicate by event ID, and make records available for later aggregate analysis.

#### Scenario: Duplicate retry arrives
- **WHEN** the client retries an event after an ambiguous network response
- **THEN** the service stores at most one copy of that event ID and returns a successful acknowledgement

### Requirement: Bounded retention

The telemetry service SHALL delete raw event records after the documented retention period or irreversibly aggregate them, and SHALL document access and deletion operations.

#### Scenario: Retention job runs
- **WHEN** an event exceeds the configured raw retention period
- **THEN** the service removes the raw event or replaces it with an irreversible aggregate
