# App Full-Screen Linked Document Layout Regression

## Symptom

When FluxMarkdown is full screen and a local Markdown link opens another document, the new document initially fills the full-screen tab correctly. After a short flash, its content is constrained to a window-sized rectangle near the top-left while the rest of the full-screen window is black.

Reported reproduction file:

`/Users/xykong/workspace/HappyElements/animal-box/docs/onboarding/tool-publishing-guide.md`

Example links include `Project onboarding process` and `GitLab account and project onboarding` under the related standards section.

## Baseline

- Version: `1.34.471`
- Commit: `039965b chore(sparkle): update appcast.xml for v1.34.471`
- Windowed link navigation renders normally.
- The regression is specific to opening another document from an App full-screen window.

## Reproduction

1. Open the reported Markdown file in FluxMarkdown.
2. Enter full screen.
3. Click a relative link to another Markdown document.
4. Observe that the new full-screen tab is initially correct, then shrinks after a short delay.

## Initial Evidence And Hypothesis

`WindowAccessor` restores a persisted windowed frame immediately and schedules the same frame again after 0.20 and 0.80 seconds. Those delayed applications do not check whether the new document window has joined a full-screen tab group. The timing matches the reported flash followed by a window-sized content area inside the full-screen host.

The same class also persists document frames during App full screen. The current preference contains a full-screen-sized `hostWindowFrame`, confirming that full-screen geometry can overwrite the intended windowed restore frame.

## Acceptance Metrics

- A document window or any member of a full-screen tab group never receives startup frame restoration.
- Full-screen and full-screen-tab frames never overwrite `hostWindowFrame`.
- Windowed startup restoration and user resize persistence continue to work.
- Opening both reported local links from the full-screen source document keeps the selected document content at the full-screen content size after both delayed restore points.
- Swift unit tests, release build, and native App end-to-end verification pass.

## Result

### Root Cause

The new document window is created at a normal window size and then automatically joins the source window's full-screen tab group. `WindowAccessor` scheduled windowed-frame reapplications at 0.20 and 0.80 seconds without rechecking the window's current context. Once the document had joined the full-screen group, the delayed `setFrame` call resized the tab's SwiftUI content inside the unchanged full-screen host, producing the black surrounding area.

Full-screen move and resize notifications could also persist the full-screen frame as `hostWindowFrame`, replacing the frame intended for later windowed sessions.

### Resolution

- Detect full-screen state on the current window and every member of its tab group.
- Skip immediate and delayed startup frame restoration while that context is full screen.
- Recheck full-screen state at each delayed restore point so a window that joins the group after attachment is protected.
- Ignore full-screen and full-screen-transition frames during persistence, then save the restored windowed frame after full-screen exit.

### Verification

- Regression tests cover current-window full screen, full-screen tab groups, delayed restore cancellation, transition persistence, and unchanged windowed behavior.
- `WindowSizePersistenceTests`: 39 passed.
- Swift unit suite excluding the independent rendering benchmark target: 226 passed.
- Web Renderer: 28 suites and 302 tests passed.
- `make app CONFIGURATION=Release`: passed.
- Native App E2E used the reported source document and both reported targets:
  - `project-onboarding.md`: passed with two full-screen tabs; WebView `1920 x 1044` in a `1920 x 1080` content area after delayed restores.
  - `gitlab.md`: passed with the same full-screen dimensions and tab state.
- The temporary Debug-only E2E instrumentation was removed after verification.
