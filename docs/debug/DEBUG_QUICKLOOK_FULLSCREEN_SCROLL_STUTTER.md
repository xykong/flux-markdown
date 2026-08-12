# Quick Look Full-Screen Scroll Stutter

## Symptom

In Finder Quick Look, a Markdown preview scrolls unevenly with a two-finger
trackpad gesture after entering full screen. The same document scrolls smoothly
when the standalone FluxMarkdown app is full screen.

## Test Environment

- Investigated and fixed on 2026-08-12.
- macOS: 26.5.2 (25F84).
- Baseline: FluxMarkdown 1.34.464 (build 464).
- Verified development build: `1.34.464-dev-20260812-115104`.
- Fixture: `CHANGELOG.md` (591 lines, about 43 KB).

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

## Implementation

- Removed the renderer's global non-passive `wheel` listener and WebKit gesture
  listeners. Ordinary two-finger scrolling is again eligible for WebKit's
  asynchronous scrolling path.
- Added the shared AppKit `NativeMagnifyingWebView` base class. Both Quick Look
  and the standalone app now recognize pinch with
  `NSMagnificationGestureRecognizer` and apply `WKWebView` visual
  magnification without a JavaScript round trip.
- Kept Command-scroll zoom in each host and two-finger double-tap reset in the
  shared native class.
- Kept Control-only synthesized-wheel compatibility at the native layer, where
  it scrolls with `window.scrollBy` without installing a permanent renderer
  listener.
- Removed the `pinchZoom` and `gestureZoom` script-message handlers from both
  hosts.
- Excluded full-screen transitions from Quick Look window-size persistence.
  macOS Quick Look's remote full-screen host does not forward the normal
  full-screen notifications and does not expose `.fullScreen` in its local
  `NSWindow.styleMask`, so the guard also rejects a window frame that fills the
  screen's visible frame within a two-point tolerance.

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

### TDD regression coverage

- Red: five of six focused renderer tests failed with the old global listener;
  the focused Swift run failed because `NativeMagnifyingWebView` did not yet
  exist.
- Green: renderer focused tests passed (`6/6`), native magnification and window
  persistence tests passed (`38/38` after the remote-host regression was
  added).
- Renderer full suite: `28/28` suites and `302/302` tests passed.
- Swift functional suite: `216/216` tests passed. The separate
  `RenderBenchmarkTests` suite cannot run inside the unsigned `xctest` sandbox:
  its WebKit child loses access to required system services and hangs on the
  first cold run. The signed application paths were exercised below instead.
- Renderer production build and macOS Release application build both passed.
- `git diff --check` passed, and source inspection found no renderer-level
  `wheel` listener or zoom message bridge.

### Finder Quick Look end-to-end

1. Installed and code-sign verified development build
   `1.34.464-dev-20260812-115104` with `make install-debug`.
2. Opened `CHANGELOG.md` from Finder with Space and confirmed the development
   version and rendered Markdown in the real Quick Look extension process.
3. Entered Quick Look full screen and moved the native scroll position from
   `0.75` to `0.25`; the visible document content and accessibility scroll value
   changed together.
4. Exited full screen and confirmed the windowed Quick Look size remained
   `1386x837`. Logs show `windowWillStartLiveResize` ignored the full-screen
   frame and `windowDidEndLiveResize` skipped persistence; no `1512x950` save
   occurred with the final build.

### Standalone app end-to-end

1. Opened the same `CHANGELOG.md` through the Quick Look Open action and
   confirmed development build `1.34.464-dev-20260812-115104` in the app.
2. Entered app full screen, moved its native scroll position from `0` to `0.6`,
   then injected an ordinary scroll action; the position advanced to `0.637`
   and the visible content updated.

The Computer Use harness cannot synthesize a continuous physical trackpad
gesture or pinch, so it cannot produce a valid 10-second frame-time trace or a
physical pinch verification. Those two hardware-specific acceptance checks
remain manual. The blocking cause is nevertheless covered directly: the
permanent non-passive wheel listener and synchronous zoom bridge are absent,
and both real signed host paths render and scroll successfully in full screen.
