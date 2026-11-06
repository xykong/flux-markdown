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
