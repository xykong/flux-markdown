# Quick Look #49 / #58 follow-up — 2026-11-06

## Scope and baseline

User requested deeper investigation of #49 and #58, in that order. No reporter
messages, release, registration repair or editor changes are part of this task.
Repository baseline: ecda850; worktree initially clean.

Both GitHub issues were reread on November 6. Neither has a new comment after
the October 26 diagnostic request. #49 describes Sequoia 15.7.7 / 24G720 despite
its Tahoe title. #58 reports macOS 27.0.1 / 26A434 and version 1.36.582, one
enabled registration, valid signature and the expected Markdown UTI. Neither
supplies runtime evidence from a failing Finder preview.

Local host: macOS 27.0.1 / 26A434. Installed extension: 1.43.755 (not the latest
published 1.44.761). Read-only diagnostics report valid signature, enabled
installed registration, and 16 registered copies including 15 other copies.
The stored self-test result is from 1.42.645 on October 29, not a current test.
This machine is not equivalent to either reporter's installation.

## Investigation acceptance

- Distinguish registration, provider selection, extension invocation, file read,
  renderer handshake and render completion.
- Audit the self-test's evidence and false-positive/false-negative boundaries.
- Run a fresh bounded preview probe without repairing registration, resetting
  caches, changing editors or replacing the installed app.
- Treat local success and code-level diagnostic defects separately from the
  reporters' unconfirmed root causes.
- Record concrete next checks and avoid requiring repeated reinstallations.

## Findings

### Fresh local runtime evidence

- Installed-app `--quicklook-self-test` returned `quicklook_preview=rendered`.
  The matching event at 12:30:11 +08:00 identifies the exact executable beneath
  `/Applications/FluxMarkdown.app`, version 1.43.755, not a development copy.
- Created a unique 76-byte temporary Markdown fixture, selected it in Finder,
  and pressed Space through native UI automation. At 12:31:08 +08:00 the same
  installed executable logged `preparePreviewOfFile`, file monitoring and the
  matching UUID's `stage=rendered` event.
- Independently inspected Finder's actual Quick Look accessibility tree and
  screenshot: heading, bold text, contents sidebar and FluxMarkdown toolbar
  were rendered; visible version was 1.43.755. This adds actual Finder evidence
  beyond the in-app QLPreviewView self-test.
- Closed the task-created preview and folder window and deleted the temporary
  fixture. No repair, cache reset, registration removal, application replacement
  or default-editor change was performed. The self-test updates its stored
  result/version/time; normal preview code may record ordinary usage/preferences.

This is a positive control, not a reproduction or fix of either issue. The
local OS matches #58 but the app version, default editor and registration set
do not; Sequoia from #49 was not available. The 15 development registrations
are a local confounder, not evidence of the reporter's cause (#58 reports one).

### Diagnostic defect 1: installed-copy identity is not actually checked

`Sources/Shared/QuickLookProbeEvidence.swift` accepts a matching UUID, version,
subsystem and executable **suffix**. It does not require the executable inside
the app running the self-test. `QuickLookSelfTest.show()` nevertheless says
"The installed extension rendered the test document."

Compiled the production evidence parser with an isolated Swift driver and a
synthetic matching event from `/tmp/development/FluxMarkdown.app/...`.
Result: `same_version_development_copy_accepted=true`. This is a demonstrated
false attribution in the parser, not a claim that such a copy ran in today's
probe. Today's raw process-path evidence independently establishes the installed
copy. A follow-up fix should match the expected canonical bundle/executable and
build identity and test same-version alternate copies explicitly.

### Diagnostic defect 2: JavaScript completion is not rendering success

The extension emits `stage=rendered` on any successful `callAsyncJavaScript`
completion. In `web-renderer/src/index.ts`, a missing `markdown-preview` node
returns normally; the main rendering catch also displays an error and resolves
the promise normally. Neither guarantees the intended Markdown is displayed.

Ran an isolated Jest diagnostic against the real production entry point with
the preview container absent. The promise resolved to `undefined`, no heading
existed, and the logger recorded the missing-container error (1/1 diagnostic
passed). The temporary test was removed. The caught-error branch is code-review
evidence; it was not separately fault-injected into the native host.

A follow-up should make success explicit and verify the known self-test fixture's
rendered DOM before accepting the completion marker. Negative checks should
include missing root, caught renderer error, stale generation and source mode.
The current false-success boundary does not establish that either reporter
encountered it, and today's screenshot independently confirms real rendering.

### Other limits of the current diagnostics

- Only the terminal `rendered` probe stage is emitted. Preparation/handshake
  messages do not form a complete UUID-correlated structured stage record.
- `log show` visibility and polling limits can produce `unconfirmed` even when
  the UI renders; `unconfirmed` is not proof that the extension never launched.
- File preparation logs currently expose the document path as public log text.
  A shareable collector must extract allowlisted stages/codes and omit raw logs
  and document paths by default.
- The extension starts in preview mode, but retains source/preview state while
  its controller is reused. A source-looking view with FluxMarkdown controls
  needs to be distinguished from the system plain-text fallback. There is no
  reporter evidence currently establishing either case.

## Issue-specific decisions and next work

| Report | What is established | Next discriminating evidence |
| --- | --- | --- |
| #49 | App renders; reporter tried registration/reinstallation; OS description conflicts with title. | Confirm OS/build; capture a failed Finder preview and identify whether FluxMarkdown controls and extension invocation exist. Preserve the user's VS Code association. |
| #58 | Reporter confirms one enabled copy, valid signature, expected UTI; same OS build works locally. | Compare self-test and Finder on the affected machine, including selected executable/build and correlated prepare/read/handshake/render stages. Do not repeat static checks or reinstalls as the principal next step. |

Recommended implementation order before another reporter round trip:

1. Correct self-test identity and success semantics using failing regression
   checks first. These are bounded diagnostic fixes, not reporter-root-cause fixes.
2. Prepare one bounded, read-only diagnostic session that begins before a single
   failed Finder attempt, distinguishes app/extension/host processes and outputs
   an allowlisted shareable summary. Missing OS logs must remain "unavailable",
   not "extension did not start". Do not auto-upload or alter associations.
3. Request only this missing affected-machine evidence, then target the observed
   failing stage. No external message was sent in this investigation.

Neither #49 nor #58 has a confirmed root cause or released fix. Do not mark done,
merge them as proven duplicates, or claim ad-hoc signing/default editor causes
without the failing runtime evidence.

## Authorized corrective work

User requested fixes for the confirmed causes. Scope: the two diagnostic defects
above; no claim of resolving either reporter's original fallback. Before code
changes, added an alternate-copy rejection regression and renderer checks for a
successful fixture, missing root, caught error, invalidation/source mode, wrong
content and hidden/zero-size output. The renderer API will keep its existing
promise contract; a separate probe verifier will require a completed current
render and the expected visible heading/bold DOM. Native probing will require
canonical executable identity and version/build plus this affirmative result.


## Corrective result and validation

Both confirmed diagnostic defects are corrected. The self-test reads the embedded
extension's executable/version/build and accepts only a matching canonical path
(including legitimate filesystem aliases), exact version/build, token, subsystem
and rendered marker. Missing identity fails closed. Renderer probe verification
requires the completed current generation and visible, nonzero-size expected
heading and bold text. Source mode, caught errors, missing DOM, hidden ancestors,
wrong content and superseded work cannot emit the successful probe marker. Normal
render/export promise behavior remains unchanged; this does not introduce a new
error surface or suppress the existing native self-test feedback.

Evidence:

- Before implementation: the native alternate-copy assertion failed, and the new
  renderer positive contract check failed. The earlier isolated missing-root
  experiment established why resolved promises are insufficient.
- After implementation: all 563 renderer tests / 62 suites pass, production
  typecheck/build pass, and all 30 real WebKit cases pass. The new WebKit case
  verifies actual layout plus missing root, caught failure, hidden content,
  source mode, stale generation and wrong content. Six Jest probe cases include
  a newer asynchronous render invalidating previously successful content.
- Native Xcode tests: 9 passed, zero failures, covering probe evidence and
  registration/editor preservation. The first run encountered a stale Sparkle
  module cache; an isolated derived-data run passed. Release configuration builds
  successfully. Local Xcode 27 uses the explicit macOS 12 deployment override;
  no macOS 11/physical Intel runtime acceptance or support-policy change is claimed.
- Actual candidate self-test: temporarily registered a signed Release-entitlement
  candidate without replacing the installed app. System Quick Look selected the
  existing `/Applications` 1.43.755 extension instead. Its old rendered event was
  correctly rejected and the candidate returned `quicklook_preview=unconfirmed`.
  This is an actual cross-copy negative test, not a candidate positive-host pass.
- Removed the candidate registration in a `finally` cleanup. Before/after
  registration snapshots and default-editor state are byte-for-byte identical.
  Local evidence remains under `build/quicklook-probe-validation/run-xks164pp/`.
  The self-test's normal last-result/time preferences were updated by the run.

Limit: the OS did not select the candidate extension during that actual-host
attempt. Positive semantics are verified in real WKWebView and the exact-identity
native tests, but positive candidate extension selection on this machine is not
claimed. Do not disrupt the user's installed application or purge other registered
copies to force a passing result. #49/#58 remain unconfirmed pending the reporters'
failing runtime evidence. No release, issue reply or label update was performed.

## Installed-candidate acceptance (user-authorized follow-up)

The user explicitly requested installing the fixed candidate and testing it.
Before placement, verified no FluxMarkdown document windows were open, backed up
1.43.755, and captured editor/registration state. Use the existing acceptance-app
preparer with Release entitlements and a development display version; preserve
script-generated release/build numbers. Acceptance requires the installed copy's
new version/build/exact path marker, visible Finder heading/bold content, a negative
probe with wrong content, preserved editor state, and final signature verification.
Keep the working candidate installed if acceptance passes; retain the backup.

### Installed acceptance result

Installed and retained `1.44.761-dev-20261106-174520`, containing commit `5f6ed0d`,
under `/Applications/FluxMarkdown.app`. Used `prepare-acceptance-app.sh ... Release`
and the vendor `install-flux-markdown.sh`; the latter performs registration/repair
and preserves the captured editor handlers. The older running extension was
terminated before replacement so the new executable could be loaded. Product
version/build remain 1.44.761/761; this is a local acceptance build, not a release.

- Actual installed `--quicklook-self-test` returned `rendered`. The fresh log at
  17:45:30 +08:00 contains the exact installed executable path, matching UUID,
  `version=1.44.761 build=761 stage=rendered`. This resolves the prior inability
  to test the candidate as the system-selected installed extension.
- Finder positive fixture emitted the same new identity/build-aware marker.
  A second fixture with the dedicated probe filename but incorrect heading/bold
  text reached `preparePreviewOfFile` in the installed extension, then logged
  `Quick Look probe did not verify the rendered fixture`; no successful marker
  for that negative fixture exists in the captured interval.
- Independently opened the positive fixture in the existing system QLPreviewView
  harness. Foreground accessibility and screenshot show the expected heading,
  bold text, body, contents and native toolbar, including the installed development
  display version. The initial background-host screenshot showed only native
  controls; it was not counted as visual success. Foreground inspection showed
  the actual rendered document. This observation does not establish the cause of
  the initial background capture difference.
- Finder foreground window automation was unreliable (including a focus refusal),
  so no successful Finder screenshot is claimed. Finder invocation evidence and
  independent foreground system-host visual evidence are recorded separately.
- Final deep signature and Release entitlement checks pass. Default-editor
  snapshot exactly matches before installation. Test host processes and the
  task-created Finder window were closed; the user's pre-existing Finder window
  remains. No reporter issue, label or release was changed.

Evidence: `build/quicklook-probe-validation/installed-if0ach3c/acceptance.json`,
`positive-host.png`, the positive/negative event records, final diagnostics and
entitlement checks. The verified previous application is preserved as
`previous-1.43.755.zip` in that directory; ZIP integrity and the archived executable
SHA-256 match the pre-install backup. Staged candidate/backup app directories were
removed after archiving to avoid leaving extra discoverable app copies. Fixture
files are retained only in this ignored evidence directory. The installed candidate
is intentionally left in place at the user's request. The original #49/#58 reporter
machines remain untested; this is local acceptance of the diagnostic corrections.
