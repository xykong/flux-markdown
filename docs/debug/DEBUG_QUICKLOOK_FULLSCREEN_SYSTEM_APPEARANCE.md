# Quick Look Full-Screen System Appearance

## Symptom

When the preview appearance is set to **System** and macOS is using Light
appearance, a Finder Quick Look Markdown preview is light while windowed but
turns dark after entering full screen. Explicit Light and Dark modes are not
reported to have this problem.

## Environment

- Investigated on 2026-08-12.
- macOS: 26.5.2 (25F84).
- Baseline application: development build based on commit `6c4424f`.
- Host: Finder Quick Look, including its remote full-screen window.

## Reproduction

1. Set macOS appearance to Light.
2. Set FluxMarkdown preview appearance to System.
3. Open a Markdown file with Finder Quick Look.
4. Confirm the windowed preview is light.
5. Enter Quick Look full screen.

Expected: the preview remains light because System means the macOS appearance.

Actual: the preview becomes dark in the remote full-screen host.

## Initial Diagnosis

`PreviewViewController.currentThemeString()` derives the renderer theme from
`view.effectiveAppearance`. In System mode the preview view has no explicit
appearance, so it inherits its host window. Quick Look gives the remote
full-screen window a dark appearance even while macOS itself is light. The
effective-appearance observer then sends `dark` to `window.updateTheme()`.

An initial attempted fix used `NSApplication.shared.effectiveAppearance`, but
real Finder E2E showed that the Quick Look extension application's effective
appearance is also overridden by the remote full-screen host. With macOS Light
and the shared preference set to System, development build
`1.34.464-dev-20260812-151642` still rendered dark after entering full screen.
The host view and extension application are therefore both presentation state,
not reliable sources for the global system setting.

A second Finder E2E using global `AppleInterfaceStyle` resolution still turned
dark in build `1.34.464-dev-20260812-151936`. Swift correctly resolved Light,
but the `WKWebView` itself still inherited the remote full-screen appearance.
Renderer styles use `prefers-color-scheme` in addition to the explicit
`data-theme` attribute, so the WebKit content process continued applying dark
media-query rules. The resolved native appearance must be applied directly to
the WebView as well as its container.

The selected preference and the actual system appearance are separate inputs:

- Explicit Light or Dark must continue to override the system.
- System must resolve from macOS's global `AppleInterfaceStyle` preference,
  independent of the Quick Look host window and extension application.

The initial native background currently has the same host-inheritance problem
because it also reads `view.effectiveAppearance` directly.

## Acceptance Criteria

- System + macOS Light stays light across windowed -> full screen -> windowed.
- System + macOS Dark resolves to dark.
- Explicit Light remains light even if the system or host is dark.
- Explicit Dark remains dark even if the system or host is light.
- A host-only appearance change cannot override System mode.
- Initial native background and rendered HTML use the same resolved theme.
- Finder Quick Look end-to-end verification covers the full-screen transition.

## Verification Status

### Implementation

- Added a testable theme resolver that keeps explicit Light/Dark overrides and
  resolves System from the global macOS `AppleInterfaceStyle` preference.
- Applied the resolved `NSAppearance` to both the Quick Look container and its
  `WKWebView`. This keeps WebKit `prefers-color-scheme` media queries aligned
  with the explicit renderer theme when the remote full-screen host is dark.
- Updated the initial native background from the same resolved theme.
- Observed `AppleInterfaceThemeChangedNotification` so System mode still tracks
  a real macOS appearance change without observing host presentation changes.

### Automated verification

- Red: the focused XCTest build failed because the resolver did not exist.
- Green: five Quick Look system-appearance tests passed, including System Light
  with a dark host, System Dark, explicit overrides, and direct WebView
  appearance application.
- Renderer-bundle startup background tests passed alongside the new tests.
- Full Swift functional suite passed (`221/221`, excluding the WebKit benchmark
  that cannot run in the unsigned test sandbox).
- Release application build passed.
- `git diff --check` passed.

### Finder Quick Look end-to-end

The final signed development build was
`1.34.464-dev-20260812-152235`. macOS was Light and the shared preview
preference was System.

1. Opened `CHANGELOG.md` with Finder Quick Look and confirmed the development
   version plus a light rendered background.
2. Entered full screen and confirmed the rendered background, text, code spans,
   toolbar controls, and CSS media-query-driven elements all remained light.
3. Exited full screen and confirmed the windowed preview remained light.

The two intermediate signed builds documented above were necessary to separate
Swift theme resolution from WebKit media-query inheritance. Only the final
build, which applies the resolved appearance directly to `WKWebView`, passed
the full windowed -> full screen -> windowed sequence.
