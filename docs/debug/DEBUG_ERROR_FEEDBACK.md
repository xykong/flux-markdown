# Contextual error feedback implementation

Baseline: c252863; user approved implementing and validating add-error-feedback.

Acceptance: every inventoried app-owned failure offers task guidance, useful recovery and contextual reporting; a single activation opens a populated GitHub form, with optional inspection/exclusion, bounded safe diagnostics and non-recursive fallback. Validate source/event identity, malicious fields, missing diagnostics, repeated activation, Sparkle completion, renderer failure without JS and actual Quick Look handoff. Do not claim default-branch template availability before publication.

Evidence and per-surface acceptance will be recorded here. Local diagnostic builds explicitly use macOS 12 on Xcode 27; shipping minimum remains macOS 11.

## GitHub handoff decision

Verified the repository's real logged-in GitHub editor with a non-private title/body fixture: `/issues/new?title=...&body=...` opens the populated blank issue editor with no mandatory category/platform fields. No issue was submitted. Runtime uses this existing, verified route so feedback works before a newly added template reaches the default branch. `app_error.yml` and a tested template URL variant remain available for future template adoption; its publication is not a dependency of this release's default route. This is the graceful compatibility path for the approved one-click experience, not an extra user step.

## Implementation and evidence

- Shared `ErrorIncident` has typed operation/source/phase/reason, UUID scope, bounded error chain, failure-time version/environment/settings, recent related settings changes and operation events. JSON is validated again at IPC boundaries; 100 events / 64 KiB storage, 16 KiB requests. Raw error strings, document source and private paths are excluded. Optional notes remain user-controlled.
- `ErrorFeedback` implements one-action browser routing, duplicate-click suppression, optional local review/exclusion, retained drafts, copy/save fallback and history clearing. Native notices do not depend on WebKit. NSError recovery options expose file-open feedback through the system document error presenter.
- Quick Look's authenticated XPC service accepts only validated report payloads and fixed host-app destinations. The host preserves extension snapshots instead of replacing them with its own current state. A separate bounded operation opens the selected document in the matching host for recovery.
- The default runtime route uses the verified GitHub plain Issue editor. The optional specialized template is ready locally but not published; no client workflow depends on it.
- Initial new native tests failed because ErrorIncident/Store/Registry did not exist; initial renderer test failed before the feedback module existed. The existing updater presentation tests were updated for the new three-button behavior and verify that error capture precedes handoff and Sparkle acknowledgement occurs exactly once.
- Native functional suite passed 345 tests before the final additional UI/localization coverage tests. Final counts and CI outcome are recorded below. The unrelated benchmark suite waits indefinitely for its old harness handshake and was stopped; functional tests use the repository CI's documented `-skip-testing:MarkdownTests/RenderBenchmarkTests`. Real production-renderer WebKit checks run separately.
- Renderer suite: 374 passing tests, including every supported error class, stale document controls, redacted payloads, input-error replacement and image recovery. Actual WebKit: 19 passing cases, including a real Mermaid failure, one report message, stale-button rejection and exclusion of feedback UI from HTML export. Print CSS hides the same controls.
- Installed a backup-preserved Release-entitlement candidate locally. Deep signature and release-entitlement checks passed. Actual QLPreview self-test returned `quicklook_preview=rendered`. In Finder Space, the non-private Mermaid fixture showed recovery guidance and report/review buttons. One click opened the prefilled GitHub editor through the extension → XPC → host route; the report identified `Source: quicklook`, the correct candidate version, failure-time settings and renderer event. The fixture source sentinel was absent. No Issue was submitted.
- A later native accessibility capture intermittently returned `cgWindowNotFound`; this does not negate the completed Finder handoff, but further visual coverage is backed by native view/layout/action tests rather than claimed as additional screenshots.
- MacPorts source transformation passes with the new updater wrapper stripped; shared error feedback has no Sparkle dependency. Product minimum remains macOS 11; local Xcode 27 tests explicitly override to 12.0.

## Coverage inventory

| Surface | Implementation / verification |
| --- | --- |
| Update errors | Real Sparkle user-driver path; failure captured before dismissal, report after acknowledgement; download/review/close remain accessible; unit checks include repeated failed update cycles. |
| Document read/encoding/size | `DocumentReadFailure` exposes localized Foundation recovery options for choosing a file, reporting, review and closing; tested without opening another modal. OS-owned inaccessible failures still use Help fallback. |
| Reload | Main app/extension attach native persistent notice; main app retry retains current content. Registry deduplicates repeated same-kind/code errors within one document. |
| HTML/PDF export | Explicit foreground failure paths now attach native retry/save-location guidance; no feedback is generated for cancelled save panels. Generic action tests cover both operation kinds; CLI invalid-input probe separately verifies text-only guidance. |
| Renderer load/navigation/timeout/termination | Native notice survives failed JS; main app bounded handshake timer plus retry preserving queued content; extension offers matching host app. Narrow native layout tested at 360 px. |
| Local images/preview limit | Native extension notice offers host opening; web images have inline feedback removed on successful load. Known limits remain classified separately. |
| Quick Look repair/self-test | Failed outcomes use shared guidance/feedback; successful behavior unchanged. Actual installed Release self-test passed. |
| Search and external destinations | Inline regex guidance and focus recovery; search launcher/native link failures use shared notices; editor child-process failures checked after termination. |
| Renderer/Source/Mermaid/Typst/GraphViz/Vega/KaTeX | Existing error classes wired to bounded metadata-only bridge; technical details folded; direct editor/reload/host recovery; module-load failures get reload/reinstall guidance. DOM coverage tests and real Mermaid WebKit/Finder path pass. |
| Feedback failures | Injected browser failure preserves same draft; report opt-out, Unicode URL budget, missing store, copyable summary and no recursive feedback verified. |
| CLI | stderr adds actionable input/output guidance and a prefilled report URL with safe summary; no GUI feedback launch. |
| OS windows / extension not invoked / crash before capture | Cannot add a button to code that never runs; Help feedback remains the documented fallback. These are not represented as captured incidents. |

## Remaining release-only gate

If switching the runtime to `app_error.yml`, publish it on the default branch and verify it first. The current verified title/body route does not require that publication. No release, master push, issue reply or done label is included in this task.

## Final refinements

- Quick Look-related reports can add allowlisted registration/enabled/signature/self-test status, explicitly timestamped as a report-time check. Collection is asynchronous with a two-second fallback; late results cannot reopen or replace an already-handed-off report. Timeout and unavailable history are disclosed, and optional user notes remain intact.
- Native notices use vertically arranged actions in narrow previews. Guidance and recovery activation are exercised for every FailureKind, and both native bundles' five language resources are validated. Update report continuations retain the manual download action. Update reports carry the known target version and only relevant language settings.
- Runtime GitHub URL generation handles long Unicode notes within 6000 bytes, explicitly marks omitted content, and retains complete notes locally. Reports with diagnostics excluded still contain a useful task summary.

## Cleanup and compatibility verification

The temporary acceptance install was replaced with the backed-up original 1.36.573 app. Its strict signature is valid and the saved Markdown-editor state matches byte-for-byte. Test-owned last-file/preview-state changes were restored conditionally; other current settings were not overwritten. The preview helper and test host processes were stopped; unsubmitted test GitHub tabs were closed.

Implementation commits: `41d43b7` and `f013440`. Verification branch: `verify/error-feedback-20261018`. Runs: initial [39119222259](https://github.com/xykong/flux-markdown/actions/runs/39119222259), final [39119432970](https://github.com/xykong/flux-markdown/actions/runs/39119432970). Both use the repository's pinned Xcode 16.4 workflow, macOS 11 deployment target and universal arm64/x86_64 packaging. The branch is for validation only; master and releases were not published by this task.

## Document error presenter correction

A direct Foundation bridge probe caught that Swift `RecoverableError` alone did not populate the NSError recovery metadata on this SDK. Added explicit `CustomNSError` userInfo and both synchronous/asynchronous NSObject recovery-attempter overrides. Regression tests inspect the actual NSError options/attempter and verify callback result/context and exactly-once completion; closing does not launch feedback. These tests failed before the correction and passed afterward.

- Final recovery review separates missing renderer resources from a transient render failure: missing files offer downloading/reinstalling the app, with a copy-link fallback if the browser cannot open. Reload recovery reuses retained rendered content directly instead of treating externally loaded disk content as a new SwiftUI model edit.

## Packaging regression

A full staged MacPorts build exposed a YAML-null dependency block after stripping the test target's only Sparkle dependency. The exporter now removes empty dependency blocks. A regression test runs the real export transforms and XcodeGen parser; this check is included in release CI. Document recovery also reports the original read as unrecovered when an alternative/report is chosen, rather than implying that reporting repaired the file.

## Final verified result

- Final product-code commit: `19625b7a117678dfa9c792f2f291821269e2d618`.
- [Final CI run 39120891184](https://github.com/xykong/flux-markdown/actions/runs/39120891184) passed every applicable job: MacPorts export regression, renderer build/tests, real WebKit, macOS 11 native tests, universal Release build, signature/entitlement checks and artifact packaging.
- Local native functional run: 351 passed, no failures. CI executed 351 native tests with zero failures and one expected skip because the adjacent homebrew-tap checkout is absent. Renderer: 42 suites / 374 tests passed. Actual WebKit: all 19 cases passed. Final targeted recovery/supplement checks passed after the last functional refinements.
- Downloaded final CI artifact to `build/feedback-ci-39120891184/`; verified its SHA256, provenance commit and strict deep signature. Host app, Quick Look extension and XPC helper each contain arm64 and x86_64 slices, with macOS 11.0 minimum for both slices.
- Actual staged MacPorts Release build passed after the empty-dependency export fix; `otool` confirms no Sparkle linkage and release-entitlement verification passes. This local no-Sparkle build explicitly targets macOS 12 for the installed Xcode 27 diagnostic toolchain.
- Direct NSError bridge probe passed with the localized recovery label and recovery attempter present. Sync/async recovery callback tests pass; feedback/alternative actions do not falsely report that the original read succeeded.
- Acceptance-only error history was archived under ignored build artifacts and removed from the user's store. Original 1.36.573 installation and its editor association were restored. No release, default-branch push, Issue submission, reporter reply or done label was performed.
- The only commit after the verified product-code revision updates these acceptance records and OpenSpec task status; no application behavior changes are included in that documentation commit.

## Usage statistics preference failure

The shared usage-statistics switch reports persistence failure through
`FailureKind.usageSettings` / `ErrorFeedback`. Recovery retries the explicit
opt-out; guidance explains closing the app/Quick Look and checking disk space.
The switch does not claim the preference was saved on failure. Feedback captures
the preference incident without uploading local telemetry counters or identifiers.
