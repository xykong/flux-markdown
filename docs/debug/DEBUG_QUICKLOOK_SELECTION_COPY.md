# Copying a selection in Finder Quick Look

## Reproduction

On macOS 26.0.1 (25A362), select a Markdown file in Finder, press Space,
select a few words, and press Command-C. In FluxMarkdown 1.42.645, the
pasteboard stays unchanged. Copy from the context menu writes the same
selection successfully.

## Acceptance

- Command-C copies the selected text in the rendered preview and source view.
- Right Arrow still advances through a multi-file preview. Space and Escape
  still close it.
- Preview appearance does not move the window's first responder, and
  the native search button still hands off to the main app.

## Focus and command delivery

With the original focus override, the extension received the pointer events
and WebKit created a selection. The extension did not observe an AppKit
`copy:` action for the shortcut. When the WebView used WebKit's default
first-responder eligibility, the host delivered the standard copy action to
the WebView and the selected text reached the pasteboard.

A local 1.42.645 build with that single change passed the Finder checks
above for copying, navigation, and dismissal. Quick Look still logged
`Quick Look extensions should not have any views or subviews claim first responder`
after interacting with the view. The controller leaves focus assignment to
AppKit. Finder runtime coverage is limited to macOS 26.0.1 on Apple
Silicon.

## Maintainer local verification — 2026-11-10

PR head `5fc0d724` merged without conflicts into local master as `f5fa5dae`.
No remote merge, push or release was performed.

### Independent evidence

- Regenerated project and production renderer using `make generate`.
- Intel he-macpro, macOS 26.7.2: all 11 QuickLookSearchTests passed,
  zero failures, using the merged source and x86_64 destination.
  Original deployment target was retained. Raw log:
  `/tmp/flux-pr70-evidence/intel-tests.log` on the local workstation.
- Local arm64 Debug build passed with command-line deployment target 12.0.
  The first build failed because the local SDK rejects deployment target 11.0;
  project settings were not changed. This is not minimum-OS validation.
- Candidate installed temporarily; strict deep signature validation passed.
  Observed extension PID 43793 launched from the installed candidate path
  `/Applications/FluxMarkdown.app/Contents/PlugIns/MarkdownPreview.appex/Contents/MacOS/MarkdownPreview`.
- Finder fixture window placed on secondary display at (1600, -1300).
  Background Space delivery was unverified; foreground retry returned
  `window_not_focused` despite restore-window. Extension AX observation returned
  `window_not_found`. No copy or keyboard regression success is inferred.
- Original installation restored; strict deep signature validation passed and
  main executable SHA-256 matched the saved original.

### Pending actual-host acceptance

Rendered and source selection copying, exact clipboard payload, navigation after
selection, Space/Escape dismissal, reopen/full-screen transitions, and main-app
search handoff remain unverified locally. Intel Finder UI also remains unverified;
its XCTest success is separate evidence. No clipboard contents were read or changed.

For continuation, use unique fixture markers and a sentinel clipboard, verify
actual loaded extension path, then compare baseline and candidate under identical
Finder interactions. Record host warning timing separately from functional failure.
Do not substitute direct JavaScript copy, a standalone WKWebView, or synthetic
action success for Finder command delivery. Raw local automation evidence and
restored-original/candidate bundles are under `/tmp/flux-pr70-evidence`.

### Continuation: real Finder checks via CUA

Local OS is macOS 27.0.1. CUA correctly bound the remote Quick Look window,
resolving the previous Orca window-targeting blocker without user intervention.
Candidate PID 62920 was observed at the installed extension path.

Passed in actual Finder: rendered selection copied `Omega`; source selection
replaced `PR70-source-sentinel` with `Omega`; Escape closed selected rendered
preview; Space closed selected source preview; reopening worked; Left and Right
after text selection navigated between copy-one.md and copy-two.md.
Search button opened copy-two.md in the main app with the search field focused;
actual typing `unique` produced 1/1. Full-screen entry and Escape exit worked.

Unresolved: full-screen double-click plus Cmd-C produced Finder filenames
(copy-one.md and copy-two.md) rather than selected text. Returning to normal
preview and repeating copied `document`. A second full-screen observation showed
no selection highlight after the semantic double-click. This does not yet
distinguish host input routing from automation failure; not counted as passing.
Baseline A/B and Intel actual-host UI remain pending. Original installation
restored again with successful strict deep signature verification.

### Single-variable A/B — 2026-11-11

Built a separate baseline from the merged source with exactly one production
change: InteractiveWebView.acceptsFirstResponder returns false instead of super.
Diff inspected before installation; same Debug configuration and local target 12.0.
Baseline build and strict deep signature verification passed.

Actual Finder baseline PID 71822 loaded from the installed path. Selecting the
same rendered sentence and Cmd-C left `PR70-baseline-sentinel` unchanged. This
contrasts with candidate `Omega`, establishing a direct ordinary-preview fix.
Baseline full-screen double-click/Cmd-C returned `copy-one.md`, reproducing the
filename-copy symptom seen with the candidate. Thus that observation is not
evidence of a new regression from the changed eligibility property; full-screen
text-selection acceptance remains unproven. Baseline full-screen Escape exit
and preview close worked. Original app restored and strict deep signature passed.

Intel remote session is logged in, but AXIsProcessTrusted() returns false for
the SSH-launched process. No new Accessibility permission was granted. Asked
maintainer to choose manual Intel acceptance or remote UI setup; pending reply.

### Full-screen selection disambiguation — 2026-11-11

Reinstalled candidate; extension PID 76135 verified at installed path. Used
CUA coordinate drag from (80,380) to (820,380) against the current full-screen
screenshot. Screenshot visibly highlighted the complete sentence
`Alpha 中文 Omega PR70-20261110`. Seeded clipboard with
`PR70-fullscreen-sentinel`, then sent Cmd-C: actual clipboard was `copy-one.md`
(exact expected-text comparison false). Right-clicking the same selection
exposed WebKit menu item WKMenuItemIdentifierCopy; clicking it copied exactly
`Alpha 中文 Omega PR70-20261110` (comparison true).

This resolves the missing-selection uncertainty for the candidate: full-screen
shortcut copying is not fixed, despite working selection and context-menu copy.
The baseline previously showed the same filename symptom; no claim of a new
PR regression is supported. Ordinary-preview fix remains independently proven.
Exited full screen, closed preview, restored original application and passed
strict deep signature verification. Intel host UI permission choice is pending.

Review disposition: reasonable bounded fix for ordinary Finder preview. Do not
advertise all Quick Look modes as fixed. Full-screen command routing remains
an explicit limitation, and Intel UI acceptance is still outstanding.

## Intel actual Finder verification — 2026-11-11

User connected Apple Remote Desktop to MacPro (he-macpro, macOS 26.7.2).
Operated through CUA, using pointer actions in the remote desktop. Direct CUA
keyboard delivery to ARD did not work, including Escape on its local menu;
used the remote macOS Keyboard Viewer to generate actual modifier/key commands.
No Accessibility permission was added. Keyboard Viewer closed after testing.

Rebuilt merged source Debug for x86_64 with ad-hoc signing; strict deep signature
verification passed. Initial Finder selection loaded an old all-tests bundle,
so those observations were excluded. Temporarily unregistered both old bundles;
verified candidate extension PID 60219 at
`/private/tmp/flux-intel-derived/Build/Products/Debug/FluxMarkdown.app/Contents/PlugIns/MarkdownPreview.appex/Contents/MacOS/MarkdownPreview`.
Mach-O reports x86_64. Restored old bundle registrations after testing.
No application was installed in /Applications on this machine.

| Actual-host check | Result | Evidence |
|---|---|---|
| Rendered Cmd-C | PASS | Sentinel replaced with exact Alpha 中文 Omega PR70-20261110 |
| Source Cmd-C | PASS | Separate source sentinel replaced with same exact text |
| Space after source selection | PASS | Preview closed; Finder visible |
| Escape and reopen | PASS | Keyboard Viewer Escape closed preview; Space reopened |
| Navigation after selection | PASS | Right changed COPY ONE to COPY TWO; Left returned to COPY ONE |
| Full-screen transitions | PASS | Entered full screen; Keyboard Viewer Escape returned to normal preview |
| Full-screen Cmd-C | FAIL | Selected sentence present; clipboard became copy-two.md CR copy-one.md |
| Search handoff | FAIL in ad-hoc environment | Search failure UI; retry also rejected by XPC listener |

Search log: `Peer connection was rejected by the listener`, followed by
`Host also refused document search launch`. Local evidence files:
`/tmp/flux-pr70-evidence/intel-search.log`, `intel-runtime.log`; remote build log
`/private/tmp/flux-pr70-signed-build.log`. This is a failed acceptance result,
not proof that PR70 changed XPC trust. Apple Silicon installed-app search passed
earlier. Neither a universal search pass nor formal release readiness is claimed.

## Final review disposition

Local merge and planned verification execution are complete, with failures
explicitly retained. The one-line change is causally supported for ordinary
Finder preview on both architectures. Do not label all Quick Look copying fixed.
Keep full-screen command routing and Intel ad-hoc search handoff as limitations.
Recommend accepting the bounded ordinary-preview fix only with that documented
scope; this review does not authorize remote merge or publication. No production
code beyond the original PR was changed.
