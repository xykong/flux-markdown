# Change: Capture one complete update diagnostic session

## Why

Issue #61's second customer capture established a progress-agent connection timeout but omitted launchd and Updater evidence. Retrospective logs and domain/code-only reports cause repeated customer requests. Capture the relevant layers concurrently before a single reproduction, preserving unknowns and privacy boundaries.

## What Changes

- Extend the existing collector with a bounded live session usable against unmodified installed 1.38.608; do not require a successful upgrade to diagnose a failed upgrade.
- Start live logging and read-only process/job sampling before inviting reproduction. Include baseline, failure/success window, post-attempt state and collection health in a single local bundle.
- Add allowlisted, correlated native update-stage events to the existing ErrorIncident / ErrorFeedback system for future builds. Freeze the event history at failure, before acknowledgement and cleanup.
- Produce an evidence coverage summary with explicit missing/denied/timed-out/truncated states and confidence-qualified findings. No claim that every system failure is guaranteed diagnosable from one attempt.
- Verify the collection against failure scenarios locally before asking the customer to run it once. No automatic upload, unrestricted error text export, security-policy changes or Sparkle dependency bump in this change.

## Impact

- `scripts/collect-update-evidence.sh` and collector tests/support code.
- `Sources/Markdown/UpdateDelegate.swift`, `AppUpdaterController.swift`, `Sources/Shared/UpdateDiagnostics.swift`, and existing incident capture/validation/export boundaries.
- Native diagnostic and presentation tests, MacPorts export checks, `docs/debug/DEBUG_ERROR_FEEDBACK.md`, and Issue #61 investigation record.
- User-visible diagnostic session behavior is new; implementation follows approval of this proposal. Sparkle upgrade remains a separate candidate so instrumentation and attempted repair are not conflated.
