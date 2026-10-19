# Change: Add opt-out anonymous usage telemetry

## Why

The project needs reliable evidence about supported macOS versions and real product usage before changing the minimum macOS version. The repository has no existing telemetry backend, so this change introduces a small independent HTTPS ingestion service and a client-side opt-out setting.

## What Changes

- Collect pseudonymous daily cumulative counters partitioned by versions and App/Quick Look source.
- Enable collection by default and provide a visible setting to disable it.
- Record visible reading duration and the number of Markdown documents previewed without collecting document names, paths, contents, or identifiers.
- Persist every accepted event on the telemetry service for later analysis, with an explicit retention policy and aggregate reporting jobs.
- Upload events asynchronously over HTTPS with bounded local retry storage; telemetry failures never affect rendering or updates.
- Document the collected fields, retention, disable behavior, and deletion process in the privacy documentation.

## Impact

- Affected specs: new `anonymous-usage-telemetry` capability.
- Affected code: shared preferences, host app lifecycle, Quick Look session tracking, settings UI, localization, release privacy documentation, and a separately deployable telemetry service.
- The service stores pseudonymous event records; network and infrastructure logs must follow the same retention policy and must not be used to reconstruct identity.
