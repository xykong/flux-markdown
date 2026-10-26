# QuickLook issues #59, #58, #49

2026-10-16 baseline 1.36.561. User authorized sequential fixes and local acceptance; no issue replies or release requested.

## Acceptance and investigation

1. #59: reproduce sibling-image reads in the release sandbox, then validate a portable permission solution in Finder QuickLook. Preserve image reference allowlist, symlink rejection, bounded reads; log actual failures instead of inferring failure from security-scope return value. Show persistent truncation notice for the 500 KiB preview limit. Test home, Downloads and external locations separately; do not claim unsupported locations work.
2. #58/#49: distinguish extension selection, launch failure and renderer failure. Collect registration, bundle identity/path/version/signature, UTI and actual preview invocation evidence. Repair must preserve default editors and distinguish registration success from runtime preview success. Reproduce a failure and validate recovery locally before claiming resolution; identical symptoms alone do not prove shared reporter root cause.
3. Use release entitlements for acceptance. Unit/WebKit tests supplement but do not replace actual QuickLook checks. Capture diagnostics before repair. Restore task-created fixtures/settings when done.

## Initial evidence

- Release extension grants only the shared preferences directory via home-relative exception, while Debug grants the user's home via an expanded absolute path.
- LocalSchemeHandler silently delivers read failures; collector silently skips stat/read failures.
- PreviewFileReader deliberately truncates after 500 KiB and appends a Markdown warning, which can be hidden inside an incomplete block.
- Current feedback report has no extension registration/runtime fields. Repair reports success based on command exits, not a successful preview.
- #49 body specifies macOS 15.7.7 despite its title; #58 and #59 report macOS 27.0.1. Their exact machines are not available in this workspace.

## Local evidence so far

- Host macOS is 27.0.1 / 26A434, matching #58/#59. Installed baseline 1.36.561 Finder preview reproduced missing image at ~/FluxMarkdown-Issue59-Acceptance/doc.md. Process path was the installed /Applications extension, not a development copy.
- A/B trial changed only the signed release extension's home-relative read-only paths to `/`; same Finder fixture rendered its Test Image. This establishes the permission regression for the tested home location.
- Implemented release-entitlement acceptance build renders home, Downloads and Documents fixture images in Finder. Documents was re-observed after a transient loading state, not counted as passed from the initial screenshot.
- Mounted HFS+ volume at /Volumes/FluxMarkdownIssue59: document loads but image read fails with Cocoa 513. This is outside the home grant; classify as permission denied and give an Open with FluxMarkdown notice. Do not claim universal external-volume support.
- A 600 KiB fixture ending in a code fence is truncated; native bottom notice remains visible outside the Markdown and points to the system Open with FluxMarkdown action.
- Missing-image test logs image-stat/missing-file/Cocoa 260 without exporting the document path.
- Actual QLPreviewView self-test of a unique generated document returned rendered. After explicitly disabling the extension, it returned unconfirmed; after --repair-quicklook it returned rendered. Editor state snapshots before/after matched. This validates the disabled-registration recovery path, not the unobserved reporters' root causes.
- The self-test checks matching UUID, release version, extension process and completed-render marker in OS logs. Registration alone, stale logs, another process or prepared-only marker cannot pass.

## Remaining evidence for #58/#49

Their original failing machines/state are not available. This system's working registration and an injected disabled-provider failure cannot prove the reports (including #49's already-enabled provider) are fixed. New feedback diagnostics and the actual self-test make the next failure actionable, but these issues must remain unconfirmed pending the affected machine's before/after results. No claim of universal repair, no done label or issue reply.

## Final local acceptance of implemented work

- Native suite: 315 cases passed, zero failures. Production renderer WebKit suite: 18 cases passed.
- Final local Release-entitlement preview: `1.36.561-dev-20261016-162625`, installed in /Applications. Signed entitlements verified. Actual self-test returned `quicklook_preview=rendered`; diagnostics identify the installed copy and the test version/time. Feedback UI shows the same diagnostic fields. No issue submission was triggered.
- Missing-image fallback in final Finder UI shows a native instruction to open the document in FluxMarkdown. Truncation notice was verified with a deliberately incomplete fenced block.
- External-volume image permission failure was observed in an earlier acceptance build. After reinstall, the same mounted-volume file sometimes remained at Finder's icon/metadata preview despite a passing QLPreviewView self-test; cache reset did not resolve that particular fixture. This is a separate unresolved host-selection/access observation, not evidence that all Finder hosts are repaired. Home-folder Finder previews continue rendering. Retain this limitation in further investigation.
- Existing default editor was preserved in the controlled disable → repair → rendered cycle. The extension was re-enabled after the negative test.
- #59's home-folder regression is locally fixed. #58/#49 reporter root causes and universal external-volume support remain unconfirmed. Goal is not complete until affected-state evidence supports their resolution.

## Reporter evidence requested

The user authorized requesting help directly from the reporters. Posted and read back English diagnostic requests on 2026-10-16:

- #58: https://github.com/xykong/flux-markdown/issues/58#issuecomment-6211497244
- #49: https://github.com/xykong/flux-markdown/issues/49#issuecomment-6211497747

Requests use checks available in the published version: exact OS/build, non-private fixture screenshot, extension registrations/versions, strict signature verification, file UTI and logs from one Finder attempt. They explicitly state that the new self-test is not published, that 1.36.561 is not a confirmed fallback fix, and that private paths should be redacted. No issues were closed or marked done. Await affected-state evidence before claiming #49/#58 resolved.

## Optional AI-assisted investigation

At the user's explicit request, added and verified optional AI prompts in English:

- #58: https://github.com/xykong/flux-markdown/issues/58#issuecomment-6211672385
- #49: https://github.com/xykong/flux-markdown/issues/49#issuecomment-6211673017

The replies distinguish diagnosis-only from voluntary developer/PR work, disclose token/quota/cost and non-developer difficulty, recommend small tool-enforced budgets, require evidence rather than guesses, and require reporter review before posting or pushing a PR. A manual report remains sufficient. Reusable copy is in docs/support/AI_ASSISTED_QUICKLOOK_REPORT.md. These comments do not establish that either fallback issue is fixed.

## #59 published

At user request, released 1.36.568, verified the formal package and actual Homebrew upgrade, and installed it locally. #59 received the `done` label and https://github.com/xykong/flux-markdown/issues/59#issuecomment-6211966535; it remains open. See docs/release/RELEASE_1.36.568.md for checks and limitations. #49/#58 are still awaiting affected-machine evidence; the self-test and diagnostics requested earlier are now available in the published build.

## 2026-10-26 follow-up: #58 new evidence and #49 status

- #58 reporter's October 22 report states 1.36.582, macOS 27.0.1 / 26A434, one enabled registration, valid signature and expected Markdown UTI, with persistent Finder failure. No runtime invocation/render log was supplied. Treat these as reporter evidence, not locally observed state.
- Local published 1.38.608 on the same OS/build: diagnostics show valid signature, enabled installed copy, and seven registrations including six development copies. Ran `/Applications/FluxMarkdown.app/Contents/MacOS/FluxMarkdown --quicklook-self-test`; exit 0, `quicklook_preview=rendered`. No repair, cache reset or default-editor change performed. This QLPreviewView result cannot prove the reporter's Finder problem fixed.
- Requested self-test/Finder comparison and one bounded failed-preview log, rather than repeat reinstall instructions. Corrected old comments saying the self-test was unpublished.
- Posted and read back #58: https://github.com/xykong/flux-markdown/issues/58#issuecomment-6412737704.
- Posted and read back #49: https://github.com/xykong/flux-markdown/issues/49#issuecomment-6412738582.
- Status: both waiting for affected-machine runtime evidence; neither marked done or closed. Similar symptoms are not proof of identical causes.
