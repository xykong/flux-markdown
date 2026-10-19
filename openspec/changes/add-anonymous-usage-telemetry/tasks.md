## 1. Specification and privacy

- [ ] 1.1 Approve the telemetry fields, retention period, service owner, and hosting location.
- [ ] 1.2 Add the `anonymous-usage-telemetry` capability spec and privacy documentation.

## 2. Client collection

- [ ] 2.1 Add the default-on opt-out preference and localized settings UI.
- [ ] 2.2 Implement installation/session identity and schema-versioned event models.
- [ ] 2.3 Track App active duration, Quick Look preview sessions, and document-view counts without source metadata.
- [ ] 2.4 Add bounded encrypted-at-rest retry storage, batching, backoff, duplicate IDs, and disable cleanup.
- [ ] 2.5 Add client tests for consent, field allowlists, counters, lifecycle boundaries, and failed uploads.

## 3. Independent service

- [x] 3.1 Create the HTTPS ingestion endpoint and versioned request schema.
- [x] 3.2 Validate and persist raw events with idempotency, public ingress rate limits and SSH-only administrative access.
- [x] 3.3 Add a retention timer and local aggregate query command.
- [x] 3.4 Add service tests and deployment/operations documentation.

## 4. Verification

- [ ] 4.1 Verify no document content, paths, names, or credentials leave the client.
- [ ] 4.2 Verify opt-out prevents new uploads and clears pending local events.
- [ ] 4.3 Verify App and Quick Look behavior remains functional when the service is unavailable.
- [ ] 4.4 Run native, renderer, service, and release checks.
