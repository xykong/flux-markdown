# Usage Counter acceptance (2026-10-19)

## Scope

Approved replacement of per-session deltas with daily cumulative counters. See
`openspec/changes/add-anonymous-usage-telemetry` and `docs/PRIVACY.md`.
No macOS minimum-version change or product release is part of this work.

## Implementation and boundaries

- Random installation and bucket UUIDs. Bucket dimensions: UTC day, application
  version, macOS version, App/Quick Look source. No file identity is serialized.
- Visible successful opening counts once, rerenders do not. Reopen counts again.
- App uses active/key/visible window conditions. Quick Look uses its view lifecycle,
  because remote host windows do not behave like ordinary AppKit windows. Time is
  therefore a preview-lifetime estimate, not attention measurement. Hidden/sleep
  timer gaps do not count; checkpoint cadence is 15 seconds, so abrupt exits can
  lose a partial checkpoint. Same-source overlapping persisted intervals coalesce.
- All processes lock the same atomic state file; the upload attempt lease is
  shared. Reading UI uses nonblocking lock acquisition; counters/network run on a
  utility queue. Every attempt, including failure, consumes the one-hour lease.
- Snapshot acknowledgement advances delivered sequence only; counts never reset.
  Opt-out clears counters/rotates identity; unsaved opt-out is reported through
  ErrorFeedback. An already transmitted request cannot be recalled.
- Storage corruption fails closed. 90-day/720-bucket local cap, 50-bucket batches.
  Local files are permission protected, not application-encrypted. See privacy doc.
- Quick Look gains write access only to the Telemetry directory. Existing home
  read-only access and helper restrictions remain. Verification enforces the narrow grant.

## Evidence

- Native full functional suite: 357 tests passed before final lifecycle/UI coverage;
  final focused telemetry suite: 9 tests passed, including concurrent writers,
  UTC rollover, persistence, stale acknowledgement, opt-out, HTTP 503/200, and
  native disclosure/disable controls, reopen-vs-rerender behavior and previews closed before the first timer tick.
- A standalone signed `.app` probe with actual Quick Look release entitlements
  successfully created/read/cleared a temporary counter directory. A raw standalone
  executable could not initialize App Sandbox; packaged probe was used instead.
- Rust tests verify retry/conflict, out-of-order high-water marks, regression
  rejection, daily/version partitioning, and transactional invalid-batch rollback.
- Production HTTPS v2 acceptance: sequences 1/3/2/3 acknowledged; totals remained
  30 views / 300 seconds. Sequence 4 with lower counts returned 409. SSH `daily`
  confirmed the result. Only that synthetic installation was then deleted; daily
  data returned to an empty list.
- Local Xcode 27 checks explicitly use deployment target 12.0; product target stays
  11.0. Compatibility build must use the pinned Xcode 16.4 workflow.

## UI verification limits

Native window/action tests and signed sandbox tests verify the lifecycle contract,
layout controls and opt-out. This is not a claim of screenshots or acceptance on
all Finder host versions. The installed user app has not been replaced by this work.

## Final compatibility verification

[Release CI 39254046562](https://github.com/xykong/flux-markdown/actions/runs/39254046562)
passed for source commit `277186b0de6926820f1a231fc2503986fe8efa52` using Xcode 16.4.
Native suite: 360 executed, one expected environment-dependent skip, zero failures.
Renderer tests, real WebKit tests, MacPorts transforms, macOS 11 target, universal
arm64/x86_64 Release build, signing/entitlement checks and artifact packaging passed.
The documentation-only completion commit does not change these build inputs.

Deployed Rust SHA256:
`7290646def88913a8bcd1a9b6e969c9be228a02ab18979660c4c40a4f3d200a5`.
Local cross-build and installed server executable hashes match. Service, nginx,
retention timer and certificate renewal timer are active. Product app publication
and replacement of the user's installed app were not performed.
