<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# PROJECT KNOWLEDGE BASE

**Generated:** 2026-01-05
**Context:** Hybrid macOS QuickLook Extension (Swift + TypeScript)

## OVERVIEW
macOS QuickLook extension for Markdown files. Hybrid architecture: Native Swift app hosts a `WKWebView` which runs a bundled TypeScript rendering engine.

## STRUCTURE
```
.
├── Makefile            # Main build orchestrator (npm + xcodegen + xcodebuild)
├── project.yml         # XcodeGen config (Generates .xcodeproj - DO NOT EDIT PROJECT DIRECTLY)
├── Sources/
│   ├── Markdown/       # Host App (SwiftUI) - Container for extension
│   └── MarkdownPreview/# Extension (AppKit) - WKWebView, QLPreviewingController
├── web-renderer/       # Rendering Engine (TypeScript/Vite) -> See web-renderer/AGENTS.md
└── scripts/            # Versioning and packaging scripts
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Project Config** | `project.yml` | Add files/targets here. Run `make generate` to apply. |
| **Build Logic** | `Makefile` | `make all` builds everything. |
| **Extension Logic** | `Sources/MarkdownPreview/PreviewViewController.swift` | Lifecycle, File I/O, JS Bridge. |
| **Host UI** | `Sources/Markdown/MarkdownApp.swift` | Minimal SwiftUI container. |
| **Rendering** | `web-renderer/src/index.ts` | Markdown parsing (see subdir AGENTS.md). |
| **Rules** | `.clinerules` | TDD & Doc-first requirements. |
| **Release Process** | `docs/release/RELEASE_PROCESS.md` | Complete PR handling and release workflow. |
| **Homebrew Cask (tap)** | `../homebrew-tap/Casks/flux-markdown.rb` | Full-featured version. Updated automatically by `update-homebrew-cask.sh`. |
| **Homebrew Cask (official)** | `../homebrew-tap/Casks/flux-markdown-official.rb` | Official-compliant draft for homebrew/homebrew-cask submission. No formula deps. |
| **Homebrew Submission Guide** | `docs/release/HOMEBREW_SUBMISSION.md` | How to submit and maintain the official cask. |

## ARCHITECTURE & PATTERNS
- **Hybrid Bridge**: Swift loads `index.html`, calls `window.renderMarkdown(content)`. JS logs back via `window.webkit.messageHandlers.logger`.
- **Ephemeral Project**: `.xcodeproj` is ignored. Always use `xcodegen` (`make generate`).
- **Versioning**: `.version` file stores full version (e.g., `1.13.149`). Build number (third part) aligns with git commit count.
- **Sandbox**: App Sandbox enabled. Read-only access to files.
- **Release Flow**: 
  1. **PR Merged**: Run `./scripts/analyze-pr.sh <PR_NUMBER>` to generate CHANGELOG entry, add to `[Unreleased]` section.
  2. **Release**: Run `make release [major|minor|patch]` → Updates `.version`, `CHANGELOG.md`, builds DMG, creates GitHub release.
  3. **Homebrew**: Run `./scripts/update-homebrew-cask.sh` to update both tap and official cask files automatically.
  4. See `docs/release/RELEASE_PROCESS.md` for complete workflow.
- **Homebrew Distribution**: Two tracks — tap version (full features) and official homebrew-cask (compliant, no formula deps). See `docs/release/HOMEBREW_SUBMISSION.md`.

## CONVENTIONS
- **TDD**: Write tests/metrics *before* implementation (see `.clinerules`).
- **Docs**: Create `docs/debug/DEBUG_*.md` for hard problems.
- **Logs**: Use `os_log` via the JS bridge. Do not rely on `console.log` alone.
- **Error UX**: Every error must help the user take the next useful action and
  provide contextual feedback. Follow **ERROR GUIDANCE AND FEEDBACK** below.
- **Automatic Commits**: After completing and verifying each important,
  self-contained work item, automatically create a Conventional Commit. Do not
  wait for the user to request the commit unless they explicitly ask not to
  commit. Stage only files that belong to the completed work item, and leave
  unrelated worktree changes untouched.

## ERROR GUIDANCE AND FEEDBACK

The two requirements are inseparable: **guide the user forward** and **make
feedback one action from the failure**. A technical error dump, a generic apology,
or a link to an empty feedback form does not satisfy them.

- **Explain the task impact.** Use a short title describing what could not be
  completed, then one or two sentences giving a useful next step. State causes
  only when supported by evidence. Do not blame the user or promise an unverified fix.
- **Make recovery executable.** The primary action performs the best available
  recovery or opens a concrete alternative. Use explicit labels such as
  "Download Latest Version", "Choose Another Folder", or "Open in FluxMarkdown".
  Do not stop at "Something went wrong", "OK", "Try again later", or instructions
  to find a menu the current interface could open itself. Offer Retry only when
  it can help, and avoid unbounded or automatic retry loops.
- **Keep the first view simple.** Show the recommended recovery, a secondary
  "Report This Problem" action, and a safe dismissal where appropriate. Put long
  instructions, technical details and optional report controls behind disclosure.
  For update failures, offer the official download page directly, with concise
  manual DMG installation instructions available in the same interface.
- **Make feedback contextual and effortless.** One activation at the error must
  prepare the relevant safe diagnostic context and enter the chosen feedback
  channel. Do not require users to locate Help, copy logs, choose an already-known
  component, retype their system/app version, or pass through a compulsory local
  report editor. Additional explanation and diagnostic inspection are optional.
- **Capture before presenting.** Freeze the specific incident's identity,
  component, operation/stage, safe error information and relevant environment when
  the error occurs. Do not substitute the most recent unrelated error or later
  settings. Collect only useful allowlisted diagnostics; exclude private document
  content, paths, credentials and raw logs by default. Explain the destination and
  included data briefly before the action; users can inspect or exclude diagnostics.
- **Be honest about delivery.** Distinguish prepared, opened, sending, accepted
  and failed states. Opening a GitHub form is not submission; a service must
  acknowledge receipt before the app says "Sent". Explain required sign-in or
  final confirmation for the selected channel without inventing completed delivery.
- **Preserve the user's work and escape route.** Failure, dismissal and reporting
  must preserve the document and edited report. Avoid repeated prompts; keep an
  actionable error reachable until recovery or dismissal. Inline errors stay
  inline, and repeated equivalent errors may share one accessible feedback entry.
- **Make feedback failure recoverable.** Keep the report available when collection,
  browser launch or delivery fails. Offer a concrete retry, copy or save alternative;
  never recursively open another error-reporting dialog. Missing diagnostics must
  not block reporting. Retrying a send must not create duplicate reports.
- **Reuse the shared implementation.** New error surfaces must use
  `ErrorIncident` / `ErrorFeedback` and the renderer's validated `errorFeedback`
  bridge, adding their recovery and feedback checks to the coverage inventory in
  `docs/debug/DEBUG_ERROR_FEEDBACK.md`. Do not create a parallel raw-error alert,
  ad hoc diagnostic uploader, or empty Issue link.
- **Cover and verify the real surfaces.** Apply these rules to app-owned dialogs,
  notices and renderer errors in every supported language, with keyboard and
  accessibility support. Native feedback must survive renderer failure. Document
  system-owned/unreachable surfaces honestly. Reviews must demonstrate both an
  executable next step and a usable contextual report without manual troubleshooting.

## GITHUB ISSUE MANAGEMENT

### Replying to Issues
- **Language**: Always reply in the same language as the issue. English issue → English reply. Chinese issue → Chinese reply. Never reply in a different language.
- **Label `done`**: When a fix is confirmed released, add the `done` label and post a reply linking the release. Do NOT close the issue — the reporter closes it.
- **Reply format** (confirmed fix):
  - State which version fixed it and link to the release tag.
  - List the specific fixes relevant to that issue.
  - Provide update instructions (Homebrew + DMG link).
- **No closing issues**: Only add `done` label + comment. The issue author decides when to close.

### Workflow for Closing Out Fixed Issues
```bash
# 1. Add done label
gh issue edit <NUMBER> --add-label "done"

# 2. Post reply (in the issue's language)
gh issue comment <NUMBER> --body "..."

# DO NOT run: gh issue close <NUMBER>
```

### Issue Reply Template (English)
```
Fixed in [vX.Y.Z](https://github.com/xykong/flux-markdown/releases/tag/vX.Y.Z).

**What changed:**
- [specific fix relevant to this issue]

**To update:**
\`\`\`bash
brew update && brew upgrade --cask flux-markdown
\`\`\`
Or download the DMG from the [Releases page](https://github.com/xykong/flux-markdown/releases/tag/vX.Y.Z).
```

### Issue Reply Template (Chinese)
```
已在 [vX.Y.Z](https://github.com/xykong/flux-markdown/releases/tag/vX.Y.Z) 中修复。

**修复内容：**
- [与此 issue 相关的具体修复]

**更新方式：**
\`\`\`bash
brew update && brew upgrade --cask flux-markdown
\`\`\`
或从 [Releases 页面](https://github.com/xykong/flux-markdown/releases/tag/vX.Y.Z) 直接下载 DMG。
```

## ANTI-PATTERNS
- **Never commit .xcodeproj**: It is generated.
- **No manual build numbers**: Use `make` or scripts.
- **Do not edit `dist/`**: It is a build artifact of `web-renderer`.

## COMMANDS
```bash
make generate                    # Generate Xcode project from project.yml
make build_renderer              # Build TypeScript engine (npm install && build)
make app                         # Build macOS app
make release [major|minor|patch] # Release new version
./install.sh                     # Build & install locally (clears QL cache)
log stream --predicate 'subsystem == "com.markdownquicklook.app"' --level debug
./scripts/analyze-pr.sh <PR_NUM> # Analyze PR and generate CHANGELOG entry
./scripts/update-homebrew-cask.sh # Update both tap and official Homebrew Cask
./scripts/submit-to-homebrew.sh   # Submit official cask to homebrew/homebrew-cask
```

## RELEASE VERSION POLICY

- Regular user-requested releases increment the minor version by default. Do not
  choose patch-only releases unless the user explicitly requests one. The third
  component remains the script-generated commit-count build number.
