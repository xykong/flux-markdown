# Quick Look diagnostic session

Baseline: 39b80fe, 2026-11-06. User approved implementing the single-session plan and closing evidence-blocked reports after more than one calendar month without a reporter message. #49 closed NOT_PLANNED (reporter last message August 14); #58 remains open (October 22). No fixed/duplicate claim.

Acceptance: discriminate expected/other extension copies, self-test/Finder UUIDs, prepare/read/handshake/render stages and explicit failures. Reject private fields and unrelated records. Demonstrate bounded collection, partial results on interruption/failure, and actual positive and controlled-negative behavior. Do not substitute static registration or log absence for runtime proof.


## Implementation and verification

- Single distributable `scripts/diagnose-quicklook-session.sh`, using stock macOS
  Bash/JXA/log/zip. Starts restricted live logs and process-presence sampling before
  a caller-token self-test and Finder reveal; reports terminal outcome independently.
  Schema 2 stages include document UUID, per-prepare request UUID, compact/quicklook
  context, version/build, and only allowlisted numeric errors. Ordinary/private
  documents do not emit these diagnostic stage records.
- Commands and observation have bounded durations; captures have size limits. Own
  helpers are terminated, including descendants; pre-existing Finder/app/extension
  processes are not killed by the collector. Ctrl+C writes partial output. Safe ZIP
  includes exactly three known files using `zip -X`, excluding resource forks and
  arbitrary filesystem metadata. Raw evidence stays local with owner-only access.
- 13 collector tests pass. Coverage: self/Finder separation, unrelated token,
  alternate executable/version/build, compact versus full request separation,
  file-read/handshake/renderer/unverified/source-mode evidence, absent logs,
  malformed/NDJSON/oversized input, private-field exclusion, event caps, observed
  outcome mismatch, disabled registration metadata, failing and hanging baseline
  commands, interruption, duration validation and ZIP content/permissions.
- 11 native tests pass (probe evidence, stage vocabulary/sanitization and registration
  preservation). Release build and OpenSpec strict validation pass. Local Xcode 27
  uses the explicit macOS 12 deployment override; no macOS 11/physical Intel runtime
  validation or product-support change is claimed. Renderer sources were unchanged
  in this work item; their prior 563-test / 30-WebKit-case acceptance is not rerun.
- Installed schema-2 local acceptance build `1.44.761-dev-20261106-181917` is retained.
  Release entitlements/signature pass; before/after default editor snapshots match.
  The earlier installed app remains backed up under the ignored validation folder.
- Real positive session: both self-test and intended Finder fixture contain
  prepared/fileRead/handshake/renderStarted/rendered from the installed extension.
  Independently inspected actual Finder Quick Look tree and screenshot for the
  same fixture, including expected heading/bold/body, contents and development
  version. The collector's `observed` stays not-reported because the Terminal
  outcome was not manually selected; visual acceptance is recorded separately.
- Real negative session: a wrong-content fixture opened by a task-owned `qlmanage`
  system host reached renderUnverified, with no verified-render result. It remains
  labelled an intended Finder fixture with actualHost not-verified; this test does
  not pretend `qlmanage` is Finder. Owned preview processes and test Finder window
  were closed after acceptance; the user's other Finder window was retained.
- Exact live evidence: `build/quicklook-session-validation/schema2-czx2b_a2/`,
  including positive/negative shareable ZIPs, native Finder screenshot/tree,
  entitlement verification and editor snapshots. The initial schema-1 prototype
  capture is historical and not the final report format.

## Limits and delivery status

Explicit denied-read, disabled-provider, handshake-timeout and alternate-copy
classification are covered by controlled evidence/unit tests; this run did not
reproduce all those failures in the reporter's actual sandbox/OS. System candidate
message counts are not root-cause diagnoses. No absence of logs is promoted to
proof that an extension did not start. Request/context metadata prevents combining
compact and full preview events, but the extension does not claim an independently
verified host identity from its fixture UUID.

#49 was closed NOT_PLANNED under the user's explicit inactivity rule. #58 is open;
its October 22 reply is less than a calendar month old as of November 6. The two
reports share this tooling and investigation queue, not an asserted root cause.
No unattended closer was scheduled. No additional issue message, release or public
artifact publication was performed. The current public v1.44.761 lacks schema-2
stages; distribute the validated tool with a suitable instrumented release/build
before asking #58's reporter for another attempt. Support steps are prepared in
`docs/support/QUICKLOOK_DIAGNOSTIC_SESSION.md`.
