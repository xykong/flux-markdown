# Quick Look telemetry transport repair

Observed installed Quick Look under qlmanage: network.client entitlement exists,
but the host sandbox rejects mDNSResponder, producing URL error -1003. Main app
can upload shared counters. Fix: authenticated existing XPC helper receives only a
flush request (no URL/body/path), reads bounded shared counters itself, checks opt-out
and reserves hourly lease only there. Helper gets network.client and narrowly scoped
Telemetry directory access; document write access and broad sandbox exemptions are
not added. No main app launch, embedded secret, custom TLS bypass or raw logs.

Acceptance: app closed, installed extension independently produces server receipt
and local acknowledgement. Repeated helper requests share hourly lease, corrupt or
disabled state produces no upload. Helper connection failure before processing does
not consume a lease; retry wakeups are bounded. Verify exact installed process path,
helper entitlements, release verification and native regressions.

## Acceptance completed (2026-10-26)

- Full native suite: 363 passed before added regression coverage. Focused telemetry
  suite: 13 passed (new broker flush test checks disabled state, persisted counters,
  network failure retention and shared hourly lease). Peer/entitlement suite: 3 passed.
- Release-config local build passed with explicit macOS 12 diagnostic override;
  product target stays macOS 11. Release signature/entitlement verification passed.
- Installed into /Applications using vendor installer (editor settings preserved).
  qlmanage launched the exact installed extension and embedded XPC helper. Main app
  process was absent throughout the server-receipt checks.
- First helper send: local app seq9 and Quick Look seq8 acknowledged; server Quick
  Look views advanced from 1 to 2. CFNetwork helper logs showed TLS 1.3 and successful
  task completion, with no dependence on main app startup.
- While the lease was active, preview seconds increased locally without another
  acknowledgement. To verify another batch within acceptance time, advanced only
  nextAttempt under flock (no counter/sequence/identity changes). Helper sent the
  new cumulative Quick Look value: 2 views / 165 seconds, seq13 acknowledged.
  Main app remained at 1 view / 90 seconds. These are two sources, one installation.
- Native counter files remain private local evidence under ignored
  build/usage-broker-acceptance; no IDs or raw diagnostics committed.
- Test qlmanage process stopped; new installed app remains. Latest helper attempt
  restored the regular one-hour lease (10:04:47 UTC next eligible at test end).
- OpenSpec validation and git diff checks passed. No product release published.

The earlier DNS restriction is not bypassed in the extension. Its network request
is removed; the helper runs under its own standard sandbox with narrow networking
and state storage grants. The unchanged peer-validation gate rejects nonmatching
executables/users/signatures. The XPC method has no externally supplied upload URL
or body. The helper only reads already persisted bounded counters.
