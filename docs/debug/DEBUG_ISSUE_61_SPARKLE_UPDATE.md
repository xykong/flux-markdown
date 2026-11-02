# Issue #61: in-app update fails

## Baseline and acceptance

- Report: https://github.com/xykong/flux-markdown/issues/61
- Reported installed version: 1.36.568, macOS 26.4.1 (25E253), arm64.
- Screenshot: Sparkle reports “An error occurred while running the updater.” No underlying error is included.
- Source baseline: 1.36.582. Local host: macOS 27.0.1 (26A434).
- Reproduction target: an unmodified published 1.36.568 app checks for and installs a published newer release.
- Acceptance: capture the failing stage and underlying error, add a regression check before implementation, and verify the corrected update flow with real Sparkle installation. Preserve the existing installed app and document any environment differences or remaining limitations.
- No release or issue reply is included in this investigation.

## Investigation

- Current update delegate logs only localizedDescription using print; nested NSError details are not retained in the application diagnostic report.
- Published updates use Sparkle 2.8.1. Installer launcher XPC service is enabled in Info.plist.
- Existing historical update scripts either replace the installed app or change its signed Info.plist; do not use these as faithful reproduction of the reported update.

## Findings and change

- Copied the published 1.36.568 DMG app with `ditto` to an isolated build directory. Deep strict signature verification passed. Its actual Sparkle flow downloaded, verified EdDSA, extracted, installed 1.36.582 and relaunched; the resulting bundle also passed deep strict signature verification. The reported failure was **not reproduced** on this macOS 27 host.
- Sparkle logged a mismatch between the old/new ad-hoc code signatures, but accepted the valid EdDSA signature and completed installation. That message alone is not evidence of a failed update.
- The main host has no app-sandbox entitlement, but enabled `SUEnableInstallerLauncherService` and retained sandbox-only installer exceptions. [Sparkle's official customization guide](https://sparkle-project.org/documentation/customization/#sandboxing-settings) explicitly says not to enable that service for a non-sandboxed application. Removed the key and the host's obsolete installer exceptions. The Quick Look extension retains its sandbox.
- Added a bounded, persistent latest-failure diagnostic containing date, source/target versions, and at most eight allowlisted NSError domain/code pairs. Unknown domains become `other`. No descriptions, arbitrary userInfo, private URLs or document paths are persisted or exported. The host logs that safe summary via os_log, and Help → Report an Issue includes it alongside settings history.
- Last failure is explicitly historical; a later successful update does not turn it into current-status evidence.

## Verification

- Red: the new configuration test failed against the original Info.plist. Diagnostics tests initially failed to compile because the diagnostic type was absent.
- Green: 23 native tests passed: UpdateDiagnosticsTests, FeedbackDiagnosticsTests, ReleaseEntitlementsTests. Covers persistence across a new store instance, nested errors, privacy, depth bounds, no-history state, and Debug/Release host configuration.
- Renderer production build/typecheck passed while generating the project.
- Local Release candidate built with an explicit diagnostic-only macOS 12 minimum on Xcode 27.1. Its version/build were overridden at build time to 1.36.568/568 solely to exercise a real upgrade to published 1.36.582. No source version file was changed, and this local candidate is not a distributable macOS 11 build.
- Candidate deep strict signature and release-entitlement checks passed.
- The corrected Release candidate then completed the real public-feed download, EdDSA verification, extraction, installation and relaunch into 1.36.582 in its isolated directory. The installed version and deep strict signature were verified after the update. This tests updating **from** the corrected launcher configuration; the public target is unchanged. Local logs remain under ignored `build/issue-61/` and are not committed.

## Remaining reporter evidence

- This is a configuration correction and diagnostic improvement, **not a confirmed resolution of #61**. The reported host runs macOS 26.4.1, whereas local testing uses 27.0.1. The exact failed target version and underlying error are still unknown.
- An already failing old updater cannot receive its own launcher correction until the user installs a corrected app manually (DMG or Homebrew). Do not promise that simply publishing a new target fixes installation from every old build.
- On the affected machine, capture one failing attempt using Console / a bounded log stream filtered to subsystem `org.sparkle-project.Sparkle` and processes FluxMarkdown, Autoupdate, Installer, Updater. Preserve the failure before cache resets or reinstalls; review/redact private paths before sharing. The new diagnostic section only exists in builds containing this change.
- No GitHub reply, `done` label, issue closure or release has been performed.

## Actionable error window follow-up

- User requirement: errors must explain the next useful action. Update failures must offer the official manual download/install path. Persist this principle in AGENTS.md.
- Acceptance before implementation: the actual Sparkle user-driver error entry point shows localized recovery instructions, a Download Latest Version button opening the fixed official Releases URL, and a close action; completing either action acknowledges the failure exactly once so subsequent checks remain possible. Browser-launch failure must provide a copyable URL. Test the real delegate selector and error recording, rather than only testing the diagnostic store.
- API audit found the previous delegate method `updater:didAbortUpdateWithError:forItem:` is not a Sparkle 2.8.1 callback. Replace it with `updater:didAbortWithError:` and retain the target version from `didFindValidUpdate`. No-update and user-cancellation outcomes must not be recorded as failures.
- Keep Sparkle's standard UI for normal checks/downloads/installations, customizing only error presentation through its public user-driver API. No changes to vendored Sparkle resources or runtime method replacement.
- Implemented a standard-user-driver subclass with manual DMG recovery, a Download Latest Version button pointing to `https://github.com/xykong/flux-markdown/releases/latest`, and a selectable address. A browser-launch failure offers Copy Download Link. Every dismissal acknowledges Sparkle exactly once. The check menu observes Sparkle's availability via KVO so it is enabled again when a failed cycle finishes.
- Corrected the actual abort callback, retained the found update's display version until the cycle ends, and ignored no-update / authorization-cancellation outcomes. Removed two unused methods that were not Sparkle delegate callbacks. MacPorts export also strips the new controller so its no-Sparkle build remains supported.
- English and Simplified Chinese native NSAlert previews were inspected using window captures; guidance, addresses and buttons fit without truncation. A temporary preview app used the production driver code with a stubbed URL opener; it does not replace the installed application. The test harness has a placeholder application icon; the real app uses its own icon.
- All seven recovery strings are present in each of the five host localizations. MacPorts source transformation passed in an isolated staging directory. Local Release build, deep signature verification and release-entitlement checks passed (macOS 12 diagnostic-only build on Xcode 27.1).
- Final native run: 28 tests passed, zero skips/failures across UpdateErrorPresentationTests, UpdateDiagnosticsTests, FeedbackDiagnosticsTests and ReleaseEntitlementsTests. A real Sparkle check against an unavailable loopback feed was repeated twice; both errors used the recovery driver, reached the corrected diagnostic callback, and released the update cycle. The test waits for the asynchronous delegate notification after acknowledging the alert.

## 2026-10-26 published progress follow-up

- Verified the published v1.38.608 release notes include launcher configuration correction and contextual update diagnostics/recovery. Earlier sections describing no release/reply are historical.
- Posted and read back Chinese progress response: https://github.com/xykong/flux-markdown/issues/61#issuecomment-6412738136.
- Explained existing local upgrade verification and OS mismatch, manual DMG/Homebrew recovery, and why a broken old updater cannot necessarily install its own correction. Requested failed target version/current reproduction and new diagnostics where available.
- Status: waiting for affected-machine confirmation; not marked done or closed. No additional update implementation or release was performed in this follow-up.

## 2026-10-28 exact-version investigation (in progress)

- New report: comment 6461144947; official 1.38.608 → 1.40.622 on macOS 26.4.1 (25E253), arm64; incident 8F436A98-7221-4639-AF15-9E74063C6D34; error chain 4005 → 10. The previous correction did not resolve this reporter's failure.
- Acceptance before changes: preserve official artifacts and their hashes; map errors to the bundled Sparkle source; reproduce with unmodified bundles; capture the first failing process/stage; use single-variable controls. A mismatch diagnostic alone is insufficient. Do not claim resolution without the affected-path validation.
- Local machine is macOS 27.0.1 (26A434); results here cannot establish behavior on macOS 26.4.1. Evidence directory: ignored `build/issue-61-20261028/`.
- Hypotheses: archive validation; nested installer launch/trust rejection; XPC connection failure; sandbox/permissions; replacement/relaunch failure; OS-specific behavior. No product change selected yet.

### Artifact and source audit

Official release DMGs downloaded independently on 2026-10-28:

| Version | SHA-256 (matches GitHub release asset digest) |
| --- | --- |
| 1.38.608 | `0d51a50932ef2a875a607cb0acb1612108baee8397094b696ad42a9f668b41a9` |
| 1.40.622 | `6afd22b8013274ce5849c03921c3311dc0b7d02265940209a48d6460d0f75f8d` |

Both bundles contain Sparkle 2.8.1 build 2050. Main app, framework, Autoupdate and Updater.app are ad-hoc signed; their individual strict verification passes. The framework and two helpers have identical CDHashes across these releases. The main app hashes match those in the reporter's attachment. The old host has no installer-launcher/connection enable keys. The launcher bundle is named Installer.xpc (not InstallerLauncher.xpc); optional missing keys are not themselves defects for this non-sandboxed host.

Independent controls:

- Apple CryptoKit Ed25519 verification using the old bundle's SUPublicEDKey and the captured official appcast signature accepts the target DMG. Flipping one byte in an in-memory copy makes verification fail. No release artifact was modified.
- `codesign --verify --strict --all-architectures -R=<old requirement> <new app>` returns 3. This independently confirms the mismatch, not its causal role.
- Sparkle tag 2.8.1 checked out at `5581748cef2bae787496fe6d61139aebe0a451f6`.
- [SUUpdateValidator.m lines 335–376](https://github.com/sparkle-project/Sparkle/blob/2.8.1/Sparkle/SUUpdateValidator.m#L335-L376) accepts a valid EdDSA chain even when old/new identity matching fails, provided the new code signature is internally valid and update policy checks pass.

### Error propagation and discriminating evidence

[AppInstaller.m](https://github.com/sparkle-project/Sparkle/blob/2.8.1/Autoupdate/AppInstaller.m) uses `SPUInstallerError` (numeric 10) for many conditions, not a unique timeout. Examples: input-data timeout (235), agent-connection timeout (239), failed update validation (312, with a nested validation error), early agent invalidation (387), PID-retrieval timeout (422), and filesystem/install-stage errors. [SPUInstallerDriver.m](https://github.com/sparkle-project/Sparkle/blob/2.8.1/Sparkle/SPUInstallerDriver.m#L159-L205) wraps a retained installer error as 4005 when its connection is invalidated.

The 18-second startup timer checks installation data and the **Updater.app progress agent connection**. If the raw message is `agent connection was never initiated`, Autoupdate has already started; it does not mean Autoupdate never launched. Validation and agent connection progress independently, so EdDSA success followed by this timeout is consistent with a delayed or rejected progress agent.

| Hypothesis | Evidence so far | Decisive next observation |
| --- | --- | --- |
| Corrupt official download / wrong EdDSA key | Independently verified download and signature pass | Compare affected machine's actual cached archive digest if different |
| Old/new CDHash mismatch alone blocks install | Mismatch reproduced; validator explicitly permits valid EdDSA alternative | Follow validation result and subsequent stage, not the warning alone |
| Nested helper integrity / wrong Team ID | Audited official helpers pass and are ad-hoc in both versions | Affected-machine helper paths, signatures, permissions and rejection logs |
| Updater launch delayed / on-demand-only domain | Consistent with attachment's timing; upstream has matching cases | launchd job submission → pending spawn → PID timestamps, before the 18s deadline |
| Agent exits or fails IPC | Not excluded by numeric error chain | Updater launch/crash report and first connection invalidation message |
| Replacement permissions / install failure | Not excluded by numeric error chain | Full code-10 message and stage-specific nested error |
| OS, quarantine, security software or installation-location differences | Local host differs; downloaded CLI artifacts have no quarantine | Controlled affected-host run; preserve attributes and policies before changing them |

### Upstream lead (not a confirmed diagnosis of #61)

[Sparkle discussion #2794](https://github.com/sparkle-project/Sparkle/discussions/2794) documents delayed progress-agent startup on some macOS 26 machines. Its maintainer describes a status-service XPC probe in >=2.9.1 that should wake an on-demand job, and an artificial RunAtLoad-disabled control that fails on 2.8.x but succeeds with the newer mechanism. The discussion also warns that RunAtLoad alone did not eliminate all reports. Our 2.8.1 source already has RunAtLoad=YES but lacks the post-submission probe.

This makes an upstream dependency update a concrete candidate **if** affected logs show that failure mode. It does not establish that all 4005/10 reports share it. Changing the downloaded target cannot change the updater running inside the old installed app; migration and subsequent upgrades must be tested separately. Do not patch launchd settings, disable security checks, or promise a signed target alone will fix the old updater.

### Evidence collection on an affected machine

Immediately after one failure, before reinstalling, rebooting or clearing caches, run from this checkout:

```sh
bash scripts/collect-update-evidence.sh /Applications/FluxMarkdown.app "$HOME/Desktop"
```

The script creates a private local directory and records the last ten minutes of filtered Sparkle/process/system logs, bundle/helper signing metadata, relevant updater configuration, quarantine presence and per-command exit status. It does not upload or alter the installed application. Raw output may contain private paths, URLs and unrelated apps' Sparkle activity: inspect/redact locally before sharing. Missing optional Info.plist keys and unused XPC bundles are recorded rather than interpreted as failures.

Provide the attempt time/timezone and target version alongside reviewed output. In the logs, distinguish Autoupdate from Updater, correlate PIDs and `com.xykong.Markdown` job labels, find the first failure, and compare timestamps with the 18-second deadline. If Updater crashes, inspect the matching local DiagnosticReports entry separately. Only if retrospective debug entries are missing, repeat once with a live filtered log capture. The script's output window alone does not prove all entries belong to one incident.

### Exact-version runtime result and limits

On macOS 27.0.1 arm64, copied the **unmodified official 1.38.608** bundle with `ditto` to `build/issue-61-20261028/run1/FluxMarkdown.app`. Used a generated, non-private Markdown fixture and the app's normal Check for Updates UI against the official feed. No Info.plist override, re-signing, replacement helper, or manual target copy was used.

Observed timeline (2026-10-28, Asia/Shanghai):

| Time | Observation |
| --- | --- |
| 15:17:30.579 | Autoupdate PID 31114 opens installer and progress-agent listeners |
| 15:17:30.974 | Updater PID 31115 already running and initiating system connections |
| 15:17:31.530 | Sparkle reports EdDSA signature correct |
| 15:17:31.546 | Exact old/new CDHash mismatch reported |
| Before installation | Standard UI reaches “Ready to Install” / “Install and Relaunch” |
| 15:17:44.714 | New FluxMarkdown process PID 32407 starts from the isolated run1 path |
| Post-install audit | Version 1.40.622, target CDHash `1261978e8f00e79d24a1ae6703e86d2235791f5b`, deep strict signature verification exit 0 |

The installation click tool reported a focus error as the old process exited; success is established independently by the replacement bundle, matching target signature, and newly running process, not by the click return value. The installed `/Applications/FluxMarkdown.app` was not replaced by this test.

This is a direct counterexample to **unconditional** failure caused by this pair's CDHash mismatch. It does not refute an OS-specific trust/launch issue on the reporter's machine. This was an isolated bundle in the existing login session, not a clean VM: user defaults, session services and caches are shared. CLI-downloaded artifacts have no quarantine attribute. A second fresh copy was prepared, but no second update was completed because GUI focus targeting became unreliable; it is not counted as another pass. No macOS 26.4.1 guest or separate verifier was available in this session.

### Deliverables, validation and next gate

- Added `scripts/collect-update-evidence.sh`; validated Bash syntax, help, invalid-input rejection, and an actual collection against the official old bundle. Verified private output directory mode 0700; signature/component checks and log capture complete successfully. Missing optional configuration/quarantine is explicitly recorded with its command exit code.
- Local evidence index: `evidence/release-{old,new}.json`, `issue.json`, `reporter-analysis.md`, `appcast.xml`, `{old,new}-signing.json`, `continuity.json`, `independent-eddsa.txt`, `run1.log`, `run1-result.json`, `run1-final-ui.json`, `upstream-2794.json`, `upstream-direct-diff.patch`, and private `flux-update-evidence.*` directories. Raw logs remain ignored and are not committed or uploaded.
- Use the direct tag-to-tag diff, not GitHub's merge-base comparison, to determine what 2.8.1 already contains. It already includes RunAtLoad=YES; the later post-launch status probe is the relevant candidate difference.
- **Status: root cause not yet established.** No speculative product fix, dependency bump, release, issue reply, done label or closure performed.
- Next required evidence: one affected macOS 26.4.1 attempt with the complete code-10 message and Updater/Autoupdate/launchd timeline. If on-demand startup delay is confirmed, test the upstream >=2.9.1 mechanism in a candidate, including old-version migration and a subsequent real update. If logs indicate rejection, crash or file replacement failure, follow that branch instead.
- Fix acceptance remains pending: reproduce failure → single-variable candidate → successful real install/relaunch → reversal or independent affected-environment verification. Developer ID signing/notarization is a separate distribution improvement, not a demonstrated fix for this incident.

### 2026-10-28 reporter assistance requested

- User explicitly authorized posting findings and requesting reporter assistance.
- Posted and read back the Chinese follow-up, mentioning @aFakeRobot: https://github.com/xykong/flux-markdown/issues/61#issuecomment-6463326757.
- Shared exact-version successful-upgrade evidence, independent signature checks, source-level distinction between mismatch and rejection, ambiguous code 10, and the upstream progress-agent startup hypothesis.
- Supplied a self-contained live-log command because the local collector commit is not yet published. Uses a private uniquely named desktop file, no sudo or upload; requested one attempt, time/timezone, versions, install location and reviewed/redacted relevant excerpts. Existing failure logs are acceptable; no downgrade requested.
- Status: waiting for affected-machine evidence; issue remains open and not marked done. No claim of a confirmed fix or release.


## 2026-11-02 reporter log: progress-agent connection timeout confirmed

### Evidence and acceptance

- Follow-up: https://github.com/xykong/flux-markdown/issues/61#issuecomment-6576161544.
- Incident `824107AE-45C1-43B9-A7DB-D48182584688`: official 1.38.608 → 1.42.645, macOS 26.4.1 (25E253), arm64; report time 2026-11-02T11:33:01Z.
- Downloaded the linked ZIP without running any attachment content. SHA-256: `51a1a39855eb0e1d0df0dff406bb869f3c9482acc4fa4aed65caa2f75010e1a5`. It contains one 510,647-byte text log plus macOS metadata. Private original evidence remains in ignored `build/issue-61-20261102/`; do not commit the raw log, which includes a user home path.
- Acceptance for this investigation: correlate the incident timestamp, identify the exact code-10 branch, distinguish observed failure from inferred scheduling cause, and check the candidate upstream mechanism against tagged source. No product implementation selected before this audit.

### Observed timeline

Times below are the attachment's local clock, consistent with UTC+08:00 and the incident report.

| Local time | Original log line | Observation |
| --- | --- | --- |
| 19:32:41.895 | 8 | amfid reports ad-hoc/unknown-chain status for Autoupdate. |
| 19:32:41.907 | 10–11 | Autoupdate PID 77103 opens both installer and progress-agent listeners. It did execute despite the preceding signature diagnostic. |
| 19:32:41.909 | 32 | Installer listener accepts a peer connection from the host. |
| 19:32:41.912 | 58 | Stale download bookmark warning explicitly says processing continues. |
| 19:32:42.759 | 142 | Archive EdDSA verification succeeds. |
| 19:32:42.795 | 211 | Old/new code-signature identity mismatch warning. Resource/signature inspection continues afterward. |
| 19:33:01.089 | 3927 | Autoupdate reports `Timeout: agent connection was never initiated`. |
| 19:33:01.089 | 3928–3930 | Autoupdate cancels its connections. |

The timeout is approximately 19.182 seconds after listener activation, consistent with the 18-second dispatch timer firing later. Do not describe the observed elapsed time as exactly 18 seconds. Its second matches the report's 11:33:01Z failure timestamp.

### Diagnosis and limits

- **Confirmed immediate failure: Updater progress-agent connection did not become established before Autoupdate's startup deadline.** Sparkle 2.8.1 `Autoupdate/AppInstaller.m`, lines 228–241, emits this exact message from the `_agentConnection.connected == NO` branch using `SPUInstallerError` (10). The installer-connection invalidation path in `Sparkle/SPUInstallerDriver.m` wraps the retained error as installation error 4005. This resolves the previously ambiguous numeric chain for this incident.
- Autoupdate startup failure and archive EdDSA failure are contradicted by this attempt's positive evidence. The ad-hoc warning and CDHash mismatch do not establish the terminating cause; the terminal failure is the agent connection timeout. This does not prove every security check passed or exclude a separate Updater launch rejection.
- There are **zero Updater process records and zero launchd process records** in the supplied capture. In particular, it does not contain `pending spawn, domain in on-demand-only mode`. Absence from this filtered capture is not proof the process never existed. Delayed launch, rejection, early exit and connection failure remain distinguishable underlying causes.
- The supplied log establishes the failure stage more strongly than the earlier report; it still does not establish the underlying launchd scheduling cause or demonstrate a fix.

### Concrete candidate and validation gate

- Rechecked upstream discussion [#2794](https://github.com/sparkle-project/Sparkle/discussions/2794) and local tagged source. Sparkle **2.9.1** `Sparkle/SPUInstallerDriver.m`, lines 499–505, probes the status service after successful installer submission; 2.8.1 lacks this post-submission probe. This directly addresses the matching on-demand startup hypothesis. Merely adding `RunAtLoad` is not a new correction: our 2.8.1 already has it.
- A dependency-update candidate is now well motivated by the confirmed timeout, but must be tested as a candidate, not presented as a confirmed resolution. Before changing the pin, define a controlled delayed/on-demand-agent regression case and verify the selected release's compatibility and complete install/relaunch path. The current investigation did not execute that candidate or reproduce the affected OS.
- Affected-host discriminating evidence remains the progress job's submission/spawn/PID and any rejection/crash around this known attempt. Prefer existing retained system logs for 19:32:35–19:33:10 local time rather than asking the reporter to repeat the same capture. The supplied capture's missing launchd records must be explicitly accounted for in any further collection.
- Migration constraint remains: installation is driven by Sparkle inside **installed 1.38.608**. Publishing a target containing newer Sparkle cannot retrofit the currently failing installer. A corrected candidate may require manual DMG installation, followed by a subsequent real in-app update to verify it on macOS 26.4.1.
- Investigation-only change: no dependency bump, release, GitHub comment, done label or issue closure. Immediate failure is diagnosed; underlying cause and affected-host fix acceptance remain open.


## 2026-11-02 single-session diagnostics implemented

- User approved `add-update-diagnostic-session` to reduce repeated customer requests. Added a standalone stock-macOS live collector usable with the affected old app, with targeted launchd/process sampling alongside live logs, bounded checks, scoped artifact/crash candidates, incident parsing and an allowlisted shareable ZIP. Private raw evidence is excluded by default.
- Native public Sparkle callbacks now record bounded correlated stages. The existing ErrorIncident report freezes this session before presenting update failure, preserving it across acknowledgement/abort and subsequent attempts. No raw NSError descriptions or private paths are persisted.
- Verification: 10 collector tests, 38 native tests and two MacPorts export tests pass; local diagnostic Release build, deep signature and entitlement checks pass. Full limits and coverage: `DEBUG_UPDATE_DIAGNOSTIC_SESSION.md`.
- Repeated an actual official 1.38.608 → 1.42.645 upgrade from an isolated unmodified bundle on macOS 27.0.1. Confirmed replacement version, relaunch and signature; captured installer/progress job PIDs, EdDSA success and the nonterminal CDHash warning. System launchd logs were again absent, but read-only job snapshots supplied lifecycle evidence. This validates the observation approach, not a fix on macOS 26.4.1.
- Prepared a local `FluxMarkdown-update-diagnostics-v1.zip` containing only the standalone tool and one-run Chinese instructions. No customer contact, upload, release or Sparkle version change occurred. Root-cause repair and affected-host confirmation remain pending.


### 2026-11-02 customer follow-up delivered

- User authorized requesting reporter assistance. Posted and read back the Chinese follow-up mentioning @aFakeRobot: https://github.com/xykong/flux-markdown/issues/61#issuecomment-6576960735.
- Published only the standalone tested collector to https://gist.github.com/xykong/bfae3c0fa71532e70318973c395ab6c8; no raw logs or local artifacts were uploaded. Downloaded its immutable raw URL and compared byte-for-byte against the tested source. Script SHA-256: `afdf4cc84c1d4f1651fde6b0686500e6be781f28f9a46d9586899826dfe4e0c5`.
- Supplied one copy/paste command to download the tool into a private desktop directory and observe for up to 300 seconds. Requested one normal update attempt and only `shareable.zip`; no separate version/time questionnaire, downgrade, sudo or security changes. Explained early completion, degraded log access and startup-failure fallback.
- Status: awaiting this diagnostic bundle. The confirmed failure remains progress-agent connection timeout; underlying cause and fix remain unconfirmed. No release, done label or issue closure.
