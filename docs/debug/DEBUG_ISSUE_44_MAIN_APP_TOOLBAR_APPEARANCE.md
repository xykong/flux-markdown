# Issue #44: Main App Toolbar Appearance

## Symptom

Issue #44 was marked fixed in v1.34.449, but a user confirmed that the
standalone app still renders the top-right action buttons with insufficient
contrast in Light mode. QuickLook is reported as fixed.

## Current State

- Baseline commit: `ba2050b`
- Released version reported by the user: `1.34.449`
- The renderer WebView receives `AppearancePreference.currentMode`.
- The main app's native toolbar buttons inherit the host window appearance.
- The host window appearance can differ from the explicitly selected preview
  appearance.
- Existing toolbar tests cover button type, hit area, tooltips, and source
  integration, but not a host/preview appearance mismatch.

## Reproduction

1. Set macOS to Dark appearance.
2. Open a Markdown file in the standalone FluxMarkdown app.
3. Set FluxMarkdown appearance to Light.
4. Observe the native toolbar controls over the light renderer background.

## Hypothesis

`NSColor.labelColor` and the native circular bezel resolve against the
toolbar button's inherited host appearance. When the WebView is explicitly
Light while the host remains Dark, the button can resolve a light foreground
over a light page.

## BDD Acceptance Scenarios

### Scenario: Light preview inside a dark host

- **GIVEN** the host appearance is Dark
- **AND** the user selects the Light preview appearance
- **WHEN** the main app creates its floating toolbar buttons
- **THEN** each button uses the Light preview appearance
- **AND** its label color resolves to a dark, visible foreground

### Scenario: Dark preview inside a light host

- **GIVEN** the host appearance is Light
- **AND** the user selects the Dark preview appearance
- **WHEN** the main app updates its floating toolbar buttons
- **THEN** each button uses the Dark preview appearance
- **AND** its label color resolves to a light, visible foreground

## Verification

- Red: the targeted XCTest build failed with `extra argument 'appearance' in
  call` before the production API existed.
- Green: `ToolbarButtonHitAreaTests` passed with explicit Light and Dark
  preview appearances, including the SwiftUI `Color` to `NSColor` bridge.
- Green: the `Markdown` scheme built successfully in Release configuration.
- Pending final E2E: exercise the installed app with mismatched system/app
  appearances and confirm QuickLook remains unchanged.
