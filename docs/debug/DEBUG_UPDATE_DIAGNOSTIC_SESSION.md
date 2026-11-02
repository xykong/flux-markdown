# Single-session update diagnostics

## Purpose and customer workflow

Observe a failing old installation without first replacing its updater. Start observation, attempt one normal update, then attach one `shareable.zip`. No automatic upload, sudo, additional runtime installation, security changes or service wake-up probes are used. The script uses macOS Bash, system utilities and JXA through osascript.

From a checkout:

```sh
bash scripts/collect-update-evidence.sh --live --output "$HOME/Desktop"
```

The standalone `scripts/diagnose-update.sh` is independently distributable. Default observation is 180 seconds; `--duration 300` can allow a slow download (range 1–900). `--app` selects an installation, default `/Applications/FluxMarkdown.app`. Start the normal in-app update only after the readiness message. Ctrl+C can finish early; collection stops automatically otherwise. Final checks/package generation follow the observation window and have individual deadlines. Partial evidence is preserved.

Only attach `shareable.zip` from the printed output directory. `raw/` remains private and can contain personal paths, URLs and unrelated Sparkle log activity. It is excluded from the ZIP, including macOS resource forks/extended attributes. The shareable files contain validated facts/categories rather than regex-redacted arbitrary messages. No separate questionnaire is needed for versions, system, attempt time and available incident codes.

## What is collected

- Initial/final version, UTC session boundaries, elapsed observations, system/architecture, free space, Sparkle version and installation-location category.
- Live Sparkle/system logs plus independent sampling of the application's installer/progress launchd jobs in gui/user domains. PID/parent/elapsed observations are filtered to the app and its Sparkle launcher cache before export. Sampling provides evidence even if system unified logs are unavailable.
- Signing/integrity/permissions/quarantine/entitlement checks. Component numbers: 0 host, 1 Sparkle, 2 Autoupdate, 3 Updater.app, 4 Installer.xpc. Detailed command text stays private; exit status and allowlisted identity facts are exported.
- Recent scoped archive candidates (at most two, at most 256 MiB each) with stable-before/after hash checks. These are explicitly candidates, not proof of download completeness, selected target or EdDSA verification. Missing/deleted archives remain unavailable.
- Recent relevant crash candidates (at most three) with bounded prefixes kept private and recognized exception/termination categories exported. Their presence does not establish causality or ownership; the time/PID evidence still matters.
- Existing app error incidents within the session, including safely validated source/target/system/domain/code fields and typed native stages when available. A successful update need not create an error incident.
- Every check has a start/completion status, elapsed time, timeout and possible truncation indicators. A missing completion means the check was interrupted. A successful log invocation does not imply useful log coverage.

## Resource and interpretation limits

Commands have a five-second watchdog and 32 KiB raw-output limit; the live stream has an 8 MiB limit. Sampling stops at an 18,000 KiB raw-directory threshold, leaving headroom for bounded final evidence under the 20 MiB budget. Structured outputs are bounded by the 900-second maximum, two archives, three crash candidates, 200 recognized log events and 100 bounded incidents; tests inspect the shareable ZIP against the 2 MiB budget. Native history is capped at three sessions / 32 events, with validation repeated at IPC decode.

The live shell interval is measured with Bash SECONDS; it is not a guaranteed monotonic clock under wall-clock adjustment. Native events use system uptime. Sample intervals can exceed one second when a query is slow; actual elapsed observations and deadlines are recorded. A command timeout can extend a sampling iteration; finalization has additional bounded checks. No attempt is made to change persistent logging configuration or acquire elevated log access.

Process sampling can miss very short-lived processes. Multiple running copies share the bundle's job names/cache; job/PID evidence must be correlated, and candidate categories are not unique root-cause assertions. Unified-log absence is reported separately from job sampling. A stopped observation window is not proof an update finished. The script does not automatically retry installation, classify an identity mismatch warning as a rejected archive, or promise that one run can bypass OS-private evidence.

## Verification

- Red-first collector tests and native session tests were added before implementation. The final collector suite passes all 10 tests, including candidate archive hashes and crash categories, private-data exclusion, unavailable evidence, deadlines, interruption, concurrent sessions and output caps.
- Native run: 38 tests across UpdateDiagnosticsTests, UpdateErrorPresentationTests, ErrorIncidentTests and ErrorFeedbackTests, zero failures. Actual Sparkle selectors and two consecutive real unavailable-feed failures are exercised.
- MacPorts export: two tests passed, preserving no-Sparkle distribution support.
- Local Debug/test and Release builds pass on Xcode 27 with diagnostic-only `MACOSX_DEPLOYMENT_TARGET=12.0`; product configuration remains macOS 11. Deep strict signature and release-entitlement checks also pass. This is not evidence of an Xcode 16.4 release build or affected macOS 26 behavior.
- Real observation: unmodified official 1.38.608 in `build/update-diagnostics-runtime/FluxMarkdown.app` updated via its standard UI/public feed to 1.42.645. New process PID 92361 ran from that same isolated bundle; deep strict code-signature verification passed. `/Applications/FluxMarkdown.app` was not replaced. App copies share user defaults/login services; this is not a clean VM.
- The capture recorded installer PID 91510 and progress PID 91511 through launchd snapshots, EdDSA success, the nonterminal identity-mismatch warning, and the initial/final versions. No launchd log records were delivered on this host; independent service sampling supplied the missing lifecycle evidence. Original evidence stays ignored in `build/update-diagnostics-runtime/`.
- The collector's post-run incident parser and resource-fork exclusion were independently tested with private-data fixtures. Simulated waiting jobs, denied/early-exit streams, hung commands, interruption, concurrent sessions and output flooding exercise coverage and cleanup; these are controlled fixtures, not reproduced macOS scheduling faults.

## Scope remaining outside this change

Sparkle remains pinned to 2.8.1. This change improves evidence collection; it does not claim to fix #61. A newer Sparkle candidate and affected-host verification remain separate. No customer message, release, issue closure or `done` label is performed here.
