# Issue #65 — configurable block copying

## Scope and decisions

User-approved implementation of https://github.com/xykong/flux-markdown/issues/65.
OpenSpec: `openspec/changes/add-block-copy/`.

The shared `showCopyButtons` preference defaults off. Settings → Rendering enables
it for app preview and full Quick Look. App changes trigger its normal render;
Quick Look reads the setting on render/open, so already-open previews need Reload.
Finder compact previews and source/TSV views exclude the controls.

Code text is captured before line-number decoration, including tabs, blank lines
and the parser-produced trailing newline (Markdown normalizes input line endings).
Quotes use semantic DOM traversal: paragraphs separated by blank lines, list items
on separate lines without Markdown list markers, nested body once, visible link
labels, image alt text, alert title without its decorative SVG. Embedded code uses
the same pre-decoration snapshot. Controls, placeholders and feedback are excluded.
Enabled diagram pipelines do not get code-copy controls. Disabled Mermaid/Typst
rendering exposes ordinary code; Typst now correctly honors the disabled setting
at placeholder generation rather than leaving a permanent loading placeholder.

Buttons use an in-flow header so they cannot cover code or long horizontal lines.
Status is on the leading side so success does not shift the trailing copy button.
The controls are keyboard-accessible native HTML buttons, with localized names,
visible focus and polite live status. The shared native settings switch also has
an explicit accessible title and hint (the previously empty toggle label was
identified during AX inspection). Six renderer/native languages are covered.
Print/PDF hides the header; HTML export removes headers and unwraps code hosts.
Search ignores control text.

## Clipboard and failure boundary

`BlockCopyBridge` is shared by both hosts. It checks the existing bundled-renderer
main-frame origin policy, exact message shape, enabled setting, current incident
scope, numeric monotonic request ID, and 4 MiB UTF-8 limit. Compact Quick Look also
rejects writes. Duplicate/replayed IDs never repeat the write. Only trusted button
activation enters the production renderer copy path; document HTML is sanitized
and no new script privileges are added.

NSPasteboard's write result is acknowledged through parameterized JavaScript
arguments. A missing bridge, rejected/failed write or 5-second timeout never reports
success. Requests coalesce while pending; rerender/disposal clears pending native
callbacks, timers and controls. Stale callbacks cannot update the next document.
Oversized text is rejected, never truncated.

Failures remain inline: localized guidance, Select Text, a reusable Copy button,
and the existing ErrorFeedback record/report/inspection/recovery controls. The
native registry accepts `copy` incidents; titles and guidance exist in both bundles.
Only fixed operation metadata and allowlisted environment/settings enter feedback;
clipboard/document text is never included. Reporting opens a prepared form, not a
claim of submission. Feedback transport fallback stays within the existing system.

## Verification evidence (2026-10-29)

Environment: macOS 27.0.1 arm64, Xcode 27.1. Diagnostic native builds explicitly use
`LOCAL_DEPLOYMENT_TARGET=12.0`; product deployment remains macOS 11.

- Tests were introduced before implementation: missing copy module failed first;
  a later disabled-diagram regression failed before the targeted fix.
- `npm test --prefix web-renderer -- --runInBand --silent`: **47 suites, 415 tests**.
  Handwritten expected text covers Unicode/emoji/entities/tabs/newlines, nested
  quotes/code, alerts, controls, defaults/context toggles, source mode, HTML export,
  search, oversize rejection, synthetic clicks, pending deduplication, timeout,
  late acknowledgement and content-free contextual reporting.
- `make app CONFIGURATION=Debug LOCAL_DEPLOYMENT_TARGET=12.0`: both native targets
  and final renderer bundle build successfully.
- Native functional suite: **377 tests passed, 0 failed**, using
  `xcodebuild -project FluxMarkdown.xcodeproj -scheme Markdown -configuration Debug
  -destination 'platform=macOS,arch=arm64' MACOSX_DEPLOYMENT_TARGET=12.0
  -skip-testing:MarkdownTests/RenderBenchmarkTests -test-timeouts-enabled YES
  -default-test-execution-time-allowance 30 test -quiet`.
  New tests exercise default/persisted shared preference, stale/invalid/oversized
  requests, replay rejection, and independent NSPasteboard readback.
- `scripts/test-renderer-webkit.sh`: **26 real WebKit cases passed**. Added checks
  cover contexts, accessible names, synthetic-event rejection, non-overlap, export
  cleanup, narrow RTL/light/dark long-code geometry and repeated large-document renders (600 controls).
- Actual app: enabled initially-off setting, clicked code and nested-quote buttons,
  then independently compared `pbpaste` against handwritten expected strings.
  Both matched exactly, including the initial tab and final newline. Wrote a
  sentinel to the clipboard and activated the focused copy button with Space;
  readback again matched. Collapse/expand hides/restores quote controls.
- Actual Finder Space Quick Look with a temporarily installed, signature-verified
  test build: code and quote buttons showed success and independent `pbpaste`
  comparisons matched exactly. Actual Finder preview pane exposed document content
  but **no Copy buttons** with the same enabled preference.
- Actual app Export as PDF: saved the clean fixture, extracted text with Poppler,
  rendered the page to PNG and inspected it. Content is retained; no copy buttons
  or statuses appear. The Unicode emoji is visually present (Poppler omits the
  color emoji glyph in extracted text, so extraction alone is not the oracle).
- AX inspection confirms named buttons, live status and keyboard focus; spoken
  VoiceOver output and macOS 11 hardware/runtime were not available for this run.
  No physical printer or external Issue submission was involved.

Initial full native run was deliberately cancelled after its old
`RenderBenchmarkTests/testBenchmarkAllFixtures` awaited the old loadHTMLString
renderer handshake without a timeout. Its result bundle identifies that cancelled
case; this is not reported as a passing full suite. A genuine translation-parity
failure exposed missing QuickLook copy error strings; those were fixed before the
377-test passing rerun. Performance is measured by the working real WebKit harness
instead. Initial 300-code/300-quote samples: off 27/21/19 ms, on 30/30/27 ms;
Final 600px-viewport samples were off 57/33/28 ms and on 53/43/37 ms.
These are local observations, not a cross-device SLA.

Local raw logs, fixture/PDF and acceptance notes are retained under the ignored
`build/issue-65-acceptance/` directory. No release, remote push or Issue reply is
part of this work.

## Local environment restoration

The originally installed app was backed up before temporary testing and restored
with a matching code-directory hash; strict deep signature verification passed.
LaunchServices and pluginkit again select `/Applications/FluxMarkdown.app`
(v1.41.635). The newly added shared preference was removed to restore default off.
Finder returned to Downloads with its preview pane hidden, and task-owned app/
qlmanage processes were stopped. Test artifacts remain in the ignored evidence
directory.

## Hover visibility follow-up (2026-10-29)

User requested nonpersistent controls. Toolbar opacity is now zero while idle;
hovering its code host, quote or alert reveals it immediately. Leaving waits
600 ms before a 250 ms fade. Returning cancels hiding. Layout space is preserved,
so document text does not move. Hidden idle controls ignore pointer input but
remain Tab-reachable; focus-within reveals them. Pending, success (2 seconds), and
unresolved failure states pin the toolbar visible. Reduced-motion removes fading;
hoverless input devices retain visible controls.

Validation: 416 renderer tests passed; 27 real WebKit cases passed. A new lifecycle
test proves pending/success/error visibility state and expiry. A new real WebKit
case checks initial hidden opacity, focus reveal, exit delay, reentry cancellation,
completed fade and persistent error visibility. This case activates a temporary
native window: a windowless WKWebView can have document.activeElement while
:focus-within remains false, so a windowless focus assertion was not valid evidence.
The previous foreground app is restored after the focused-window case. Both app
and extension build successfully with the explicit local macOS 12 override.

The missing QuickLook buttons were independently traced to a newer DerivedData app
running alongside the older installed extension. The installed extension assets
contained no block-copy controls while the shared preference was enabled. This
follow-up installs the verified current development app and its matching extension
to /Applications/FluxMarkdown.app, superseding the prior acceptance-only restoration.
LaunchServices/pluginkit now select that installation, and both bundled stylesheets
contain the hover/focus/feedback rules. Strict deep signature verification passed.
The previous app is backed up under ignored build/issue-65-hover/. QuickLook cache
was reset; no old extension process remained. Existing app windows need an app
restart to load the new renderer bundle. Finder's compact preview still intentionally
excludes copy controls under the original agreed scope. No public release was made.
