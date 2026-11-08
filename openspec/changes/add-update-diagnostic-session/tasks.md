## 1. Specification and review
- [x] Inspect current collector, native callbacks and incident export boundaries.
- [x] Define old-version-compatible flow, coverage matrix, privacy and validation gates.
- [x] Obtain proposal approval before implementation.

## 2. External one-session collector
- [x] Add failing fixture tests for #61 classification, missing coverage and privacy.
- [x] Implement bounded live stream, read-only targeted job/process sampling and concurrent baseline checks.
- [x] Add artifact/signature/crash metadata collection with provenance and explicit unknowns.
- [x] Add automatic finalization, interruption cleanup, partial-bundle preservation and coverage summary.
- [x] Verify no third-party runtime requirement, default shareable allowlist and optional private raw retention.

## 3. Native update evidence
- [x] Test typed bounded stages, persistence, backward-compatible decoding and incident-time snapshots before implementation.
- [x] Instrument public Sparkle callbacks with correlated os_log and safe persisted stages.
- [x] Integrate into ErrorIncident/ErrorFeedback across presentation/abort ordering without duplicate incidents.
- [x] Verify cancellation, successive cycles, restart, failure recovery and MacPorts export.

## 4. Delivery verification
- [x] Run failure/collector fault/privacy fixtures and inspect produced bundles.
- [x] Run an isolated real update and check observation readiness and final installation evidence.
- [x] Update error-feedback coverage inventory and Issue #61 investigation with actual results and limitations.
- [x] Prepare one customer instruction and versioned diagnostic artifact; customer contact requires authorization.

Implementation/verification details and environment limits: `docs/debug/DEBUG_UPDATE_DIAGNOSTIC_SESSION.md`. Customer instructions and a local versioned artifact are prepared; no external contact or release is included.
