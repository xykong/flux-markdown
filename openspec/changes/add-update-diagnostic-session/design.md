# One reproduction, concurrent evidence

## Current gaps verified in source

- UpdateDelegate uses print for found/install events and persists only error domain/code at abort. Error presentation can capture its incident before the abort callback, so adding history only in didAbort is too late.
- ErrorIncident supports only generic phases and twelve related steps. Dedicated typed update stages must have explicit schema validation, bounds and backward-compatible optional decoding; arbitrary dictionaries/raw NSError text are not an acceptable shortcut.
- The collector runs `log show --last 10m` after static checks; it does not run a live stream or sample transient launchd jobs. Existing capture exit codes do not establish whether a successful log command included the required processes.
- Old 1.38.608 cannot gain new callbacks by downloading a newer target. The first customer-facing diagnostic must run externally against the installed app.

## Customer flow

Deliver one tested, versioned diagnostic tool with a single command and no extra runtime dependency absent from supported macOS. It starts observation, reports readiness, and asks the user to attempt the normal update once. A bounded session finalizes automatically; an explicit finish action can shorten it. Do not automatically trigger installs or repeated checks. The output is one local shareable diagnostic bundle plus an optional private raw directory. The user attaches the bundle once through the existing issue. No account/configuration questionnaires: collect safe source/target/system/time/install-location category automatically where observable, and mark unknowns.

For future builds, persist minimal safe events during normal updates. Use existing contextual reporting; optional deeper collection must start before reproduction and clearly state its local destination. Do not present an empty reporting form or force a report-editing workflow.

## Coverage and provenance

| Layer | Evidence | Limits / fallback |
| --- | --- | --- |
| Session | Random session ID, UTC and monotonic elapsed times, collector version, source/target, start/end, stop reason | External tool cannot retrofit an app incident ID; correlate time/PID and retain explicit uncertainty |
| Host | Check, appcast, found/no update, download start/end/failure, extraction start/end, install handoff, abort/cancel, cycle finish, relaunch observation | Verify callbacks against pinned Sparkle public headers; absence of callback is not a failed stage |
| Artifact | Observed archive size/hash, expected feed metadata when available, signature results, extraction result | Hash only a known complete update archive; do not recursively scan private caches or claim independent EdDSA success from codesign |
| Bundle | Source/target/Sparkle version, architecture, executable permissions, signatures/entitlements, quarantine presence, install-location category | No xattr removal, resigning or installed-bundle mutation |
| Installer / agent | Live Sparkle events, PID/PPID/executable identity, process start/exit observations | Polling can miss short-lived processes; label inferred transitions and sampling gaps |
| launchd / XPC | Read-only specific `com.xykong.Markdown-sparkle-updater` / `-sparkle-progress` job snapshots in applicable domains; state/PID/exit status; installer/progress/status connections | No bootstrap, kickstart, domain dump or probe that wakes the agent and masks the failure; record missing job vs denied query separately |
| System | Narrowly scoped launchd/amfid/syspolicyd/taskgated/sandbox events, relevant crash metadata, free disk space | Do not copy unrelated crash reports or imply missing logs establish no rejection |
| Outcome | Final version/process/signature observation, terminal failure category or unconfirmed outcome | Process launch alone is not successful installation; unchanged version is not proof of failure if user did not install |
| Collector | Per-check start/end/exit status, timeouts, stream readiness/early exit, sample counts, dropped/truncated output | Failed collector steps must not block the app or erase partial evidence |

## Bounds, privacy and lifecycle

- Define and test concrete duration, per-command timeout, byte, sample and retention limits before coding. Initial defaults: 180-second live session, 1-second process/job sampling, 5-second command deadline, 20 MiB total raw output, 2 MiB shareable bundle and at most three retained native sessions. Stop reason and truncation must survive limit exhaustion.
- Start streaming before potentially slow signature checks. Run baseline checks with deadlines so code-signature validation cannot consume the reproduction window. Readiness requires established observation or an explicit degraded-coverage notice.
- External collector observes without changing host settings or service scheduling. No sudo or persistent logging configuration changes. Retry only bounded read-only probes, never repeat installation automatically.
- Store raw output locally with directory 0700/files 0600 and exclude it from the default shareable bundle. A separate explicit raw export is optional, never silently attached.
- Build the shareable artifact from allowlisted structured facts and recognized event categories, not a promise that regex replacement makes arbitrary logs safe. Exclude paths, usernames, credentials, raw URLs, document content, arbitrary NSError userInfo and unrelated applications. Unknown raw lines remain private; report unclassified-event counts so information loss is visible.
- Preserve recognized terminal categories such as agentConnectionTimeout, installationDataTimeout and signatureValidationFailure as typed values with original provenance retained privately. Do not derive a unique cause from code 10 alone.
- Reuse ErrorIncident/ErrorFeedback. Freeze a copy of this session's safe events at the error surface; later cycles must not alter an already prepared report. Keep the same incident across user-driver and delegate paths without duplicating it.
- Cancellation, timeout, app restart and collector interruption must close owned subprocesses and retain partial output. No killing app/Sparkle processes. The collector must not hold an update process alive.

## Local acceptance before customer contact

1. Replay redacted #61 evidence: detect confirmed agent connection timeout, EdDSA success and missing launchd/Updater coverage; never classify CDHash mismatch alone as the terminating cause.
2. Deterministic process/command fixtures exercise delayed agent, crash, rejected launch, missing installation data, invalid archive, disk/permission failure, cancellation and success. Assert evidence captured/unknown without claiming fixture tests reproduce macOS behavior.
3. Inject denied logs, stream early exit, hung command, disk/output cap, interruption, concurrent sessions and restart. Verify deadlines, partial bundles, no leaked subprocesses and no cross-session contamination.
4. Privacy fixtures include home paths, URL tokens, multiline errors and unrelated Sparkle applications; none reach the default export.
5. Exercise the actual tool against an isolated official old bundle and real public-feed flow on the local OS, keeping the installed application intact. Inspect artifact contents and verify process/job observation is active before reproduction. Record OS differences honestly.
6. Native tests exercise actual pinned delegate selectors, failure-time snapshot ordering, repeated cycles, persistence/bounds, existing contextual report usability and MacPorts compatibility. Supported release build remains macOS 11; local diagnostic overrides are not release compatibility evidence.

## Diagnosis boundary

One session should distinguish failure stages and collect evidence for all identified hypotheses. It cannot guarantee access to system-private events or establish causality when the OS withholds evidence. If instrumentation is inadequate in local verification, fix the tool before contacting the customer. If the single customer run still has inaccessible evidence, state the exact gap rather than automatically requesting another identical attempt.

## Implementation refinements verified locally

The external tool uses Bash SECONDS for elapsed observations, not a guaranteed monotonic clock; native history uses system uptime. Observation is bounded separately from final checks, each with a five-second deadline. Slow job queries reduce the sample rate and are recorded. The default raw threshold is 18,000 KiB with headroom under 20 MiB, using 32 KiB command outputs and an 8 MiB stream cap. Error-incident JSON is read through stock macOS JXA with an explicit allowlist. Recent scoped archive hashes are candidate observations, never a claim of download completeness. No new diagnostic UI is needed: the existing contextual report includes frozen native stages; deeper collection is the standalone tool for this version.
