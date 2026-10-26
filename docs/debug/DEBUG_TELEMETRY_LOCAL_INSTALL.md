# Local installed telemetry acceptance — 2026-10-26

Installed current product source `986466a` into `/Applications/FluxMarkdown.app`
as `1.37.596-dev-986466a-local`. Release configuration, local Xcode diagnostic
minimum 12.0; product target remains 11.0. Signed bundle verified. Vendor installer
preserved default Markdown editor settings. Previous installation is retained in
ignored `build/usage-local-acceptance/previous.app`. No release was published.

## Real observations

- No preexisting local telemetry state. Opened only a synthetic reading.md fixture
  in the installed app. Server received first snapshot with one view, zero seconds
  (sent immediately on first render), version 1.37.596, macOS 27.0.1, arm64,
  Asia/Shanghai, and valid Unix timestamp / UTC midnight 1792972800 (2026-10-26).
- Reading added local seconds while the acknowledged sequence remained 1. Reload
  left document count at one. The shared hourly lease prevented extra requests.
- `qlmanage -p` launched the actual installed extension executable under
  `/Applications/FluxMarkdown.app/Contents/PlugIns/MarkdownPreview.appex` and created
  a separate quicklook bucket. Both sources share the same installation identity.
- For bounded-duration acceptance, advanced ONLY `nextAttempt` under the same flock
  twice: first to observe extension transport, second to observe app fallback.
  Did not change bucket IDs, sequences, counters or fabricate upload payloads.
  This validates transport/checkpoints, not a real one-hour elapsed wait. Client
  automatically restored its normal one-hour next-attempt value after the send.
- App subsequent upload acknowledged app sequence 8 and quicklook sequence 7.
  Server daily totals at inspection: app 1 view / 87 seconds; quicklook 1 view /
  90 seconds. These are two source rows for ONE installation, not two users.
- The locally generated acceptance records remain on the server as this user's
  actual installation acceptance usage. No other user data was changed.
- Test qlmanage process was stopped; app was quit after acceptance to avoid leaving
  the synthetic document accruing time. New installation and default-on setting remain.

## Unresolved real-host limitation — NOT full acceptance

Quick Look direct upload under qlmanage failed with NSURLErrorDomain -1003.
System logs show mDNSResponder socket access denied (EPERM), not a bad certificate:
`dnssd_clientstub ConnectToServer ... Operation not permitted`.
The normal network.client entitlement is present; the preview host imposes an
additional restriction. Data remains local and can be uploaded by the main app.
Do not claim Quick-Look-only users are covered reliably without a transport fix
and a real Finder host retest. Failed extension attempts currently consume the
shared hourly lease and can postpone main-app uploads.

Finder key-based UI automation could not obtain a stable on-screen window despite
listing windows on another display; no successful Finder-specific network result
is claimed. App render/reload were observed through native accessibility; Quick
Look lifecycle and persistence were evidenced through process path and local state.

The computer-use skill was used for actual app/Finder interaction attempts.
