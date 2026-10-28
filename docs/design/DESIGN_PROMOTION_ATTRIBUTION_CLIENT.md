# Explicit promotion attribution client contract

Status: implementation in progress following the owner's approved cross-repository design (2026-10-28).

A first-effective-use fact belongs to the same random installation generation as the cumulative counters. It is recorded only after positive reading seconds or a successful visible document opening, using the existing locked/atomic shared state. Welcome windows, source association screens and installer operations are not activation.

New states use `fresh_state`. Existing persisted states lacking metadata decode as `upgraded_state`; they must not invent a new first-use event. Opt-out/re-enable uses a new ID marked `opt_in_reset`, without storing a link to the previous ID. App and Quick Look use the same lifecycle fact and hourly lease.

v4 adds an optional lifecycle object with event_id, first_effective_at (Unix seconds), first_effective_source and identity_origin. Usage and lifecycle acknowledgements are independent. An explicit unsupported-v4 response schedules a bounded v3 fallback on a later normal upload opportunity; arbitrary network failures do not trigger immediate duplicate uploads. Unacknowledged lifecycle may accompany one already-acknowledged counter anchor, preserving cumulative idempotency. There is no extra background wakeup.

The host adds a strict attribution branch to its existing markdownpreview URL scheme. The user may skip association. Disabled statistics mean no exchange and no automatic opt-in. Claims go to a fixed HTTPS endpoint; URL parameters never provide a network destination or a file path. Errors use the existing ErrorIncident/ErrorFeedback recovery pattern. Raw claim URLs/codes are excluded from logs and feedback.

The helper interface remains parameterless flush. Network-side sources are distinct from installation channels and the app/quicklook usage source. Client state claims cannot prove a genuine new person or install; the reporting service retains the corresponding limitations.

Public promotion-domain provisioning is still being resolved; production activation requires verified HTTPS routing and the server-side v4/claim contract before a client release.


## Verification completed for lifecycle transport (2026-10-28)

The initial three lifecycle tests failed against the unmodified v3 state, then
passed after implementation. Six focused Swift state tests now pass, including
independent ACKs, leased fallback and terminal/expired lifecycle behavior.

The generated native Xcode test target passed all 20 selected UsageTelemetryTests
and UsageAttributionLifecycleTests. This includes URLProtocol-based HTTP v4
unsupported → later v3 fallback without immediate retries, and the existing
Quick Look visible-session/shared-broker checks. Network fixtures use temporary
state and URLProtocol; they do not write test usage to production.

Command: `xcodebuild -project FluxMarkdown.xcodeproj -scheme Markdown -destination
'platform=macOS,arch=arm64' -derivedDataPath /tmp/flux-promotion-derived-data
-only-testing:MarkdownTests/UsageTelemetryTests
-only-testing:MarkdownTests/UsageAttributionLifecycleTests
MACOSX_DEPLOYMENT_TARGET=12.0 CODE_SIGN_IDENTITY=- test -quiet`.

The local macOS deployment override is diagnostic only; this is not a signed,
notarized macOS 11 release. The attribution confirmation UI, actual external URL
journey, service delivery and public deployment gates are still pending.

The real Swift state encoder was also compiled and posted to an independently
launched Rust service with a fresh temporary database. v4 ACK, lifecycle retries,
v3 compatibility and invalid-metadata isolation all passed without increasing
cumulative counts twice.
