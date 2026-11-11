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
| Quick Look diagnostic CLI | Uses existing native ErrorIncident/ErrorFeedback for app failures; new stage markers contain only dedicated fixture/request UUIDs, mode, validated version/build and allowlisted error domain/code. The standalone collector preserves partial evidence and offers explicit output-folder, inspect/share and ZIP-failure alternatives; no report is sent. Evidence/privacy/interruption/timeout tests and real positive/negative session capture pass. |
| Quick Look self-test | Failure continues through shared native ErrorFeedback. Verification now requires canonical extension identity/version/build and the completed visible fixture; missing root, caught errors, stale/source mode and wrong/hidden content are rejected. Covered by native evidence tests and the real WebKit probe case; actual candidate launch rejected a different installed extension without claiming success. |
| Update errors | Real Sparkle user-driver path; failure captured before dismissal, report after acknowledgement; download/review/close remain accessible; unit checks include repeated failed update cycles. |
| Document read/encoding/size | `DocumentReadFailure` exposes localized Foundation recovery options for choosing a file, reporting, review and closing; tested without opening another modal. OS-owned inaccessible failures still use Help fallback. |
| Reload | Main app/extension attach native persistent notice; main app retry retains current content. Registry deduplicates repeated same-kind/code errors within one document. |
| HTML/PDF export | Foreground failures retain operation-specific titles. A closed renderer preparation result identifies mathematical blockers, offers Open in Editor, and records only the typed blocker in shared ErrorIncident. Other failures retain retry/save-location recovery; cancelled panels generate no feedback. Native notice/action, strict payload/incident validation, real WK invalid→valid recovery and actual App CLI PDF checks pass. Actual foreground editor/report activation and VoiceOver remain unverified under desktop lock. |
| Renderer load/navigation/timeout/termination | Native notice survives failed JS; main app bounded handshake timer plus retry preserving queued content; extension offers matching host app. Narrow native layout tested at 360 px. |
| Local images/preview limit | Native extension notice offers host opening; web images have inline feedback removed on successful load. Known limits remain classified separately. |
| Quick Look repair/self-test | Failed outcomes use shared guidance/feedback; successful behavior unchanged. Actual installed Release self-test passed. |
| Search and external destinations | Inline regex guidance and focus recovery; search launcher/native link failures use shared notices; editor child-process failures checked after termination. Local file links resolve editor-style `path:line[:column]` targets to the existing file (issue #71), name the missing-target/locative cause in the notice and copy a plain path as recovery; resolver, decision and clipboard text are unit-tested. |
| Renderer/Source/Mermaid/Typst/GraphViz/Vega/KaTeX | Existing error classes wired to bounded metadata-only bridge; technical details folded; direct editor/reload/host recovery; module-load failures get reload/reinstall guidance. DOM coverage tests and real Mermaid WebKit/Finder path pass. |
| MathJax mathematical input limits (issue 64 implementation) | Shared math incident/feedback entry with six-language simplification/split guidance and existing editor/host recovery. Original source retained; error prevents complete-success export. UTF-8/count/aggregate boundary and real-engine tests pass. Native limit recovery/report activation remains part of final issue-64 acceptance. |
| MathJax missing bundled glyph (issue 64) | Native WK transport probe in six languages × three renderer contexts checks source preservation, named recovery/report/inspect actions, fixed five-field diagnostics, incident identity, stale-control rejection and valid-document recovery. The opt-in receiver records only; actual native recovery/report execution, trusted keyboard and VoiceOver remain separate acceptance. See `scripts/issue64/resource-failure.js`. |
| Unsupported image-backed mathematics | MathML `mglyph`, nested SVG `image` and HTML `img` retain formula source, reject successful export and preserve following formulas. Shared math/resourceUnavailable incident, six-language explanation and existing editor recovery; diagnostic tests exclude source. Native bundle and loopback HTTP probes verify zero requests for the mathematical images, with an ordinary-image positive control. Actual host recovery/report activation and VoiceOver remain separate gates. |
| Mathematical source-copy failure at narrow zoom | Real native Space activation with an injected negative copy reply; inline/display formulas in English/German/Arabic at 320 points and 2x page zoom retain exact selectable source, bounded recovery controls and clean export. Real Enter selects all source without replacing the isolated pasteboard. Shared feedback UI is retained; actual report/editor execution and VoiceOver are separate gates. See `copy-failure-recovery.json`. |
| Copy-result live status | Pending, localized failure and success update the same polite status node; failure instructions appear once and successful retry removes recovery UI. Six-language tests plus native failed-copy transport verify the DOM behavior. Actual VoiceOver speech remains unverified. |
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

## Arabic coverage (PR #62)

Arabic is covered in both native error/feedback bundles, including usage-statistics failure recovery added on master. Resource parity tests compare Arabic with current English keys; FailureKind title/guidance checks now include all six languages. Renderer feedback recovery/report controls include Arabic. See DEBUG_PR62_ARABIC_RTL.md for regression and CI evidence.

## TSV preview coverage (2026-10-28)

TSV uses the existing read and renderer failure paths. Read failures remain native `ErrorIncident`/`ErrorFeedback` incidents; bounded preview truncation is an inline, non-failure notice and contains no document content in diagnostics. Renderer failures retain the existing recovery/report controls. Automated coverage includes safe TSV rendering, bounded UTF-8 decoding, native file-type registration, and 23 real WebKit cases. Host table/source UI was observed. Signed-install Finder TSV preview and QuickLook-to-host search handoff subsequently passed; error-report submission was not performed. See docs/design/TSV_PREVIEW.md.

## Block copy failures (Issue #65)

`FailureKind.copy` uses the shared native incident registry and validated renderer
`errorFeedback` bridge in both app and Quick Look. Inline failures offer Select
Text, explicit reactivation of Copy, and contextual report/inspection; native
recovery opens the editor (app) or FluxMarkdown (Quick Look). Oversize/missing
bridge/timeout/failed writes never show success, and document text is excluded
from diagnostics. Both native bundles and renderer controls cover all six
languages. See `DEBUG_BLOCK_COPY.md` for clipboard readback, lifecycle, privacy,
export and actual QuickLook acceptance evidence.

## Update diagnostic sessions (2026-11-02)

- Update failures now freeze a typed session in the existing ErrorIncident before the error UI is shown. The public Sparkle check/appcast/download/extraction/install/abort/cycle callbacks record safe stages through os_log and a bounded persisted history (32 events/session, three sessions). Unknown error descriptions are not exported; recognized code-10 descriptions map through an exact allowlist.
- The user-driver and abort callback share an idempotent frozen snapshot. A later check gets a new session; error dialogs retain their original context. Startup errors without a check callback use `observationStarted`, not an invented check event. The existing recovery/report/dismiss UI and diagnostic opt-out remain unchanged.
- Coverage: real Sparkle selector tests, before-acknowledgement capture, repeated real failed checks, persistence/restart, history limits, invalid decoded history and private error rejection. Existing incident/feedback tests and MacPorts export are included.
- Old installed versions can be observed with `scripts/diagnose-update.sh`; `collect-update-evidence.sh --live` forwards to it. System evidence remains outside the normal automatic report, with an allowlisted local ZIP and a separately private raw directory. See `docs/debug/DEBUG_UPDATE_DIAGNOSTIC_SESSION.md` for operating instructions and limits.


Issue 64 actual App menu verification found native overlays missing from WebKit's external AX tree and an untranslated editor caption. NativeMagnifyingWebView now exposes IncidentNotice groups alongside its remote document tree; the App reuses the translated Open in External Editor key. Thirty targeted native tests pass, and actual HTML export on invalid math now exposes the translated recovery and contextual report controls in the external AX tree. This is not VoiceOver speech or report-delivery proof.

## Document path clipboard
File → Copy Document Path (Command-Option-C) uses the focused saved document. Clipboard rejection captures `.copy` before presenting the shared native `ErrorFeedback` recovery/report surface; Retry retains the original URL and diagnostics contain no path. Unicode, spaces and shell punctuation are tested with an isolated pasteboard. No document/non-file URLs disable the action.
Recent-document reopening retains unavailable entries. Failed opens capture `.fileRead` and present shared native feedback with “Choose Another File”; the action opens the native file picker. The report excludes the document path.

## Promotion source association (implementation in progress)

The host's attribution URL route uses `FailureKind.attribution` and the existing
`ErrorFeedback` recovery/report flow. Retriable network failures retry the same
claim ID; expired/conflicting/invalid capabilities open the fixed promotion page.
The fallback for browser-open failure offers copying that public page link.
Codes, installation IDs and raw claim URLs are excluded from incident payloads.
Opt-out is a normal no-submission state, not a forced settings change.
Translations are present in all six host/Quick Look resource bundles and checked
by `ErrorIncidentTests.testAllIncidentGuidanceHasTranslationsForBothBundles`.
Signed-install interactive acceptance is still pending.
