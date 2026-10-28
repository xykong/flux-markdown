# Add explicit promotion attribution

## Why
The owner approved the complete promotion-attribution design and requested implementation and verification of all stages on 2026-10-28. This change records that existing authorization; it does not require a second approval for the same scope.

## What changes
- Record a stable first-effective-use fact alongside existing cumulative counters.
- Upload v4 lifecycle metadata with independent acknowledgements and bounded v3 fallback.
- Add a narrow `markdownpreview://attribution` flow with explicit confirmation and fixed HTTPS redemption.
- Preserve opt-out, Quick Look-only usage, the hourly automatic upload lease, and parameterless XPC flush.
- Disclose provenance, lifecycle data, attribution limits and deletion/retention.

## Impact
Shared telemetry state/transport, host app URL routing and confirmation UI, privacy documentation, native tests and release verification. No document contents, hardware IDs, browser history or IP-based cross-device joins are introduced.
