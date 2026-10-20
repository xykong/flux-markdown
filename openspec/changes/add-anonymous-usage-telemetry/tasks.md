## 1. Specification and privacy

- [x] 1.1 Approve the telemetry fields, retention period, service owner, and hosting location.
- [x] 1.2 Add the `anonymous-usage-telemetry` capability spec and privacy documentation.

## 2. Client collection

- [x] 2.1 Add the default-on opt-out preference and localized settings UI.
- [x] 2.2 Implement installation/bucket identity and schema-versioned cumulative snapshot models.
- [x] 2.3 Track App foreground duration, Quick Look visible preview sessions, and document-view counts without source metadata.
- [x] 2.4 Add bounded permission-protected cumulative storage, hourly shared throttling, snapshot acknowledgements, and disable cleanup.
- [x] 2.5 Add client tests for consent, field allowlists, counters, lifecycle boundaries, and failed uploads.

## 3. Independent service

- [x] 3.1 Create the HTTPS ingestion endpoint and versioned request schema.
- [x] 3.2 Validate and persist raw events with idempotency, public ingress rate limits and SSH-only administrative access.
- [x] 3.3 Add a retention timer and local aggregate query command.
- [x] 3.4 Add service tests and deployment/operations documentation.

## 4. Verification

- [x] 4.1 Verify no document content, paths, names, or credentials leave the client.
- [x] 4.2 Verify opt-out prevents new uploads and clears pending local events.
- [x] 4.3 Verify App and Quick Look behavior remains functional when the service is unavailable.
- [x] 4.4 Run native, renderer, service, and release checks.

## 5. Global timestamp correction

- [x] 5.1 Encode new uploads as Unix seconds with explicit UTC daily starts.
- [x] 5.2 Keep v2 compatible; migrate integer timestamp columns without resetting counters.
- [x] 5.3 Test timezone/DST/midnight boundaries, unit errors, retries and migration.
- [x] 5.4 Deploy v3, verify HTTPS using synthetic data and clean up test data/temporary backup.

## 6. Minimal timezone metadata

- [x] 6.1 Add batch-level IANA timezone_id without offset or per-counter duplication.
- [x] 6.2 Preserve UTC counters and compatibility for older requests without timezone.
- [x] 6.3 Store observations transactionally; implement SSH-only latest-per-installation interval statistics.
- [x] 6.4 Include timezone observations in retention and installation deletion.
- [x] 6.5 Update localized collection notices, privacy documentation, tests and production verification.
