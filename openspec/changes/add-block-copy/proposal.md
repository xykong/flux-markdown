# Change: Configurable block copying (#65)

## Why
Readers need an accurate, accessible way to reuse code and quoted text without selecting it manually.

## What Changes
- Default-off shared setting for app and full Quick Look; compact Finder previews exclude controls.
- Copy ordinary code blocks, quotes and GitHub alerts through a validated native clipboard bridge.
- Acknowledge actual writes, reject stale requests, preserve privacy, and integrate contextual error feedback.
- Exclude controls from exported HTML and print/PDF.

## Impact
- Affected specs: block-copy (new).
- Affected code: shared preferences, settings/localization, both WebView hosts, renderer, shared error feedback.
- Scope and implementation authorized by the user's instruction to implement the reviewed plan.
