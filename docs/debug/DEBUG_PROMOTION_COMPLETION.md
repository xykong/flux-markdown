# Promotion attribution completion — 2026-11-08

Scope: complete the already-approved cross-repository attribution implementation.
Keep production claims disabled until the signed installed-client journey passes.
Never write synthetic validation events to production.

Initial findings:
- Client branch had diverged from master; localization, copy incidents and error
  coverage require preserving both sides of the merge.
- Redesigned backend landing page had no claim preparation/open action even when
  the server enabled claims. Added behavioral tests before implementing this gap.
- Current local Xcode refuses deployment target 11; diagnostic tests may override
  to 12, but cannot be reported as macOS 11 release acceptance.

Acceptance evidence and pending gates will be recorded after execution, not assumed.

## Executed verification

- Integrated current master without dropping copy incident/localization additions.
- `make generate` passed; generated project remains ignored.
- 51 selected native tests passed, zero skipped/failures: PromotionAttributionTests,
  UsageAttributionLifecycleTests, UsageTelemetryTests, ErrorIncidentTests.
- New shared-store test races 40 app/Quick Look writers: exactly one lifecycle ID,
  preserved counters, common hourly lease and opt-out lifecycle removal.
- OpenSpec strict validation and diff whitespace checks passed.
- Backend verification includes the real Swift encoder through v4 HTTP, outbox and
  the acquisition report. See backend `docs/releases/2026-11-08-attribution-development.md`.

## Release gates still pending

Diagnostic tests used MACOSX_DEPLOYMENT_TARGET=12.0 and ad hoc signing on arm64.
They do not establish macOS 11/Intel compatibility or signed/notarized installed
browser → app → Quick Look acceptance. No production claim gate was enabled and
no new release was published by this development task. Retain these pending gates
rather than labeling local protocol tests as installed-app acceptance.


## Acceptance scope update — 2026-11-09

The maintainer excludes macOS 11 runtime validation from the acceptance scope.
Intel functional verification on he-macpro is the architecture requirement;
see DEBUG_INTEL_MACOS_VERIFICATION_20261109.md for the 51 passing focused tests
and Universal build evidence. Full installed-app acceptance and signing/notarization
remain separate gates. Historical macOS 11 limitations above describe evidence,
not a current blocker. Minimum deployment configuration is unchanged.
