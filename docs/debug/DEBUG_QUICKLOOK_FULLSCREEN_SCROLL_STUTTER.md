# Quick Look Full-Screen Scroll Stutter

## Symptom

In Finder Quick Look, a Markdown preview scrolls unevenly with a two-finger
trackpad gesture after entering full screen. The same document scrolls smoothly
when the standalone FluxMarkdown app is full screen.

## Current State

- Investigated on 2026-08-12.
- macOS: 26.5.2 (25F84).
- FluxMarkdown: 1.34.464 (build 464).
- Fixture: `CHANGELOG.md` (591 lines, about 43 KB).
- The installed Quick Look extension and the repository build are the same
  version.

## Reproduction

1. Select `CHANGELOG.md` in Finder and press Space.
2. Wait for the FluxMarkdown Quick Look renderer to finish loading.
3. Enter Quick Look full screen.
4. Scroll vertically with a continuous two-finger trackpad gesture.
5. Compare the motion with the same file in the standalone app in full screen.

## Findings

### The normal Swift scroll path does no per-frame work

For a wheel event without Command, both WebView subclasses immediately forward
the event to WebKit:

- Quick Look: `InteractiveWebView.scrollWheel(with:)`
- Standalone app: `ResizableWKWebView.scrollWheel(with:)`

Full-screen logs show layout passes during the full-screen transition, but no
repeated `viewDidLayout` calls while the document remains full screen. Window
size persistence and the native toolbar are therefore not doing work for every
scroll event.

### Every wheel event is forced through JavaScript synchronously

`web-renderer/src/index.ts` registers a document-wide wheel listener with
`{ passive: false }`:

```ts
document.addEventListener('wheel', (event: WheelEvent) => {
    if (event.ctrlKey) {
        event.preventDefault();
        // Forward pinch zoom to Swift.
    }
}, { passive: false });
```

The handler only calls `preventDefault()` for Control-modified events, but the
listener registration is non-passive for all wheel events. WebKit must therefore
send every ordinary two-finger scroll event to the JavaScript main thread and
wait for the handler before it can commit the scroll.

The standalone app uses the same renderer, but its WKWebView is hosted directly
in the app window. Quick Look adds an extension remote view and the
`QuickLookUIService` host. At full-screen surface size, the synchronous event
round trip and remote composition make the blocked asynchronous scroll path
substantially easier to perceive.

The non-passive listener was introduced by commit `097b7e8` for issue #21 and
was repurposed by `3f4785a` as one of the pinch-to-zoom paths. Current tests
verify whether individual events call `preventDefault()` or the Swift bridge,
but do not verify that ordinary wheel scrolling remains eligible for WebKit's
asynchronous scrolling path.

### Pinch and synthesized scrolling are conflated

The same `ctrlKey + wheel` shape has represented two different inputs in the
project history:

- Issue #21: scrolling synthesized by Mouseless, which should scroll.
- Current behavior: trackpad pinch, which should magnify.

Treating both inputs in a global non-passive wheel listener both blocks ordinary
scrolling and risks regressing the Mouseless behavior that originally added the
listener. A fix should separate pinch recognition from wheel scrolling at the
native gesture/event layer, or otherwise avoid a permanently blocking wheel
listener.

## Secondary Finding

Quick Look's animated full-screen transition emits
`NSWindow.willStartLiveResizeNotification` and
`NSWindow.didEndLiveResizeNotification`. The current resize tracker treats that
pair as a user resize and saves the full-screen size (`1512x950` in this run).
This is a separate persistence bug. It does not explain the scrolling stutter:
the notifications stop when the transition ends, before the scroll gesture.

## Fix Direction

1. Keep ordinary wheel events off any permanent non-passive JavaScript listener.
2. Recognize pinch separately, preferably in AppKit, and keep both Quick Look
   and standalone app behavior aligned.
3. Preserve issue #21 behavior for Mouseless-style synthesized scrolling.
4. Add a regression test that inspects wheel-listener registration, not only
   the handler result for a constructed event.
5. Handle full-screen transitions separately from user-initiated window resize
   persistence.

## Acceptance Criteria

- The renderer has no document/window-level non-passive wheel listener active
  during an ordinary scroll gesture.
- A normal wheel event does not call `preventDefault()`, post a zoom message, or
  wait on a Swift bridge.
- Quick Look full-screen scrolling has no requestAnimationFrame gap above 33 ms
  during a 10-second continuous two-finger scroll on the test machine.
- The same trace has a 95th-percentile frame interval at or below 16.7 ms on a
  60 Hz display.
- Pinch zoom and two-finger double-tap reset still work in both hosts.
- Command-scroll zoom still works in both hosts without momentum drift.
- Mouseless-style synthesized scrolling scrolls rather than zooms.
- Entering or exiting Quick Look full screen does not overwrite the persisted
  windowed Quick Look size.

## Verification Status

- Reproduced the Quick Look full-screen host path with the installed 1.34.464
  extension.
- Confirmed that the same renderer bundle is used by Quick Look and the app.
- Confirmed the permanent non-passive wheel listener and its commit history.
- Confirmed via logs that full-screen transition layout work stops before
  scrolling.
- Continuous physical trackpad frame timing still needs to be collected after
  the implementation change; the Computer Use harness cannot synthesize the
  required continuous trackpad gesture for a valid frame-time comparison.

