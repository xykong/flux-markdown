## Context

FluxMarkdown runs both as a host app and as a Quick Look extension. There is no existing backend. The data is needed to estimate macOS-version coverage and product usage before making a compatibility decision.

## Goals / Non-Goals

- Goals: default-on transparent collection, one-click opt-out, minimal anonymous events, durable raw event storage, later aggregation, offline tolerance, and no impact on preview behavior.
- Non-Goals: document telemetry, advertising, user profiling, crash dump collection, or collection of raw IP addresses by the application.

## Decisions

- **Independent service:** provide a small HTTPS ingestion API separate from the application repository's product services. The service accepts a versioned batch endpoint and writes validated events to append-only storage.
- **Pseudonymous identity:** generate a random installation UUID locally. Do not derive it from hardware, Apple ID, file paths, or network identifiers. Resetting the installation creates a new identifier.
- **Event records:** each event includes schema version, installation ID, event ID, client version/build, macOS version/build, architecture, install channel, event timestamp, event type, session ID, active duration, and documents-viewed count where applicable. No filename, path, content, URL, account, or raw log is included.
- **Usage semantics:** a document viewed means a successful App render or Quick Look preview request; repeated renders of the same request are counted once per session. Active duration measures foreground App time or the lifetime of a Quick Look preview session, with a bounded heartbeat fallback.
- **Consent:** telemetry is enabled on first launch. Settings show the current state, the exact categories collected, and a disable action. Disabling stops new events and deletes unsent local telemetry; it does not request server-side deletion of already accepted anonymous events unless a separate deletion token flow is added.
- **Transport:** upload small batches asynchronously over HTTPS, with exponential backoff, a bounded queue, duplicate event IDs, and a server-side idempotency check. A failed upload is silent and must never block rendering.
- **Retention:** raw events are retained for a documented, finite period (default 180 days), then deleted or irreversibly aggregated. Service access is restricted and infrastructure request logs use a shorter retention window.

## Risks / Trade-offs

- Default-on collection can surprise users; mitigate with first-launch disclosure, a prominent setting, and clear privacy documentation.
- Raw records enable better analysis but increase privacy and storage obligations; mitigate with strict schema validation, field allowlists, retention limits, and access controls.
- Quick Look has short-lived processes; session summaries may be incomplete after termination. Use bounded heartbeats and mark incomplete sessions rather than inferring exact values.

## Open Questions

- Where will the independent service be hosted and who owns its credentials?
- What exact raw-event retention period and deletion workflow will be approved?
- Which settings screen should contain the opt-out control?
