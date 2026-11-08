# Intel verification on `he-macpro` — 2026-11-09

## Environment

- Host: `MacPro`, Intel Xeon W-3235, x86_64, 24 cores, 96 GiB RAM.
- OS: macOS 26.7.2; Xcode 26.2; macOS SDK 26.2.
- The host is an Intel build/verification machine, but it is not a macOS 11
  runtime. Results do not replace macOS 11 UI/Quick Look acceptance.

## Results

- Regenerated `FluxMarkdown.xcodeproj` from the current `project.yml` before
  transfer. The stale generated project initially omitted the newly merged
  attribution controller; regeneration fixed the Intel build failure.
- Selected native tests passed: 51/51 on x86_64, zero failures/skips. This
  includes PromotionAttributionTests, UsageAttributionLifecycleTests,
  UsageTelemetryTests and ErrorIncidentTests.
- Release build passed with `MACOSX_DEPLOYMENT_TARGET=11.0` and x86_64
  destination using ad hoc signing.
- Main app, Quick Look extension, SearchLauncher XPC and Sparkle embedded
  binaries contain x86_64 and arm64 slices. Main app and extension report
  `minos 11.0`.
- `codesign --verify --deep --strict` passed for the ad hoc app bundle.
  `spctl` rejected it because ad hoc signing has no Team ID; this is expected
  and does not establish notarization.
- Full unfiltered Xcode test run produced no test case output for several
  minutes and was stopped. No compile error or test failure was emitted before
  stopping; the focused attribution suite is the reliable result for this run.

## Limits and next gates

- macOS 11 Intel runtime, Finder Quick Look and signed installed-app flow still
  need a macOS 11 environment.
- Formal release requires the project signing identity, provisioning where
  applicable, notarization and stapled assessment. The available remote identity
  belongs to Happy Elements and was not used for release signing.
- The verification workspace on the remote host is disposable and was not
  installed into the user's Applications folder.
