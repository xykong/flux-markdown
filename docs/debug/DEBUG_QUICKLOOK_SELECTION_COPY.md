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
