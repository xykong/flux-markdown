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
