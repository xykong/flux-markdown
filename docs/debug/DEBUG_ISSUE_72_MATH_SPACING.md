# Issue #72: gap after inline math

- Report: https://github.com/xykong/flux-markdown/issues/72 by @avdbauw, FluxMarkdown 1.48.816, macOS 27.
- Reproduction: `The space \(A\) is one-dimensional.` with copy buttons enabled.
- Initial evidence: inline math copy tools use inline-flex and a start margin. Shared hover styling hides them using opacity, which preserves their width. HTML export removes tools.
- Acceptance: real WebKit must show the same following-text position with copy controls enabled and disabled. Controls must remain focusable, and copy failure recovery must remain in document flow.

## Verification

- Before fix, real WebKit regression fails: `Inline copy adds 31px gap in app`.
- Fix: anchor inline copy tools below the formula without reserving prose width; restore normal flow for error recovery.
- Production renderer build/typecheck and 13 math-copy Jest tests pass.
- WebKit regression exercises app and Quick Look spacing with controls enabled/disabled and keyboard focus. Existing native math checks cover Space copy, reference navigation, scrolling and narrow multilingual copy-error recovery.
- Final real WebKit run: all 4 math cases passed, including spacing/focus and native multilingual recovery. Run with `FLUX_TEST_WINDOW_POLICY=secondary-foreground FLUX_WEBKIT_CASE_FILTER=math scripts/test-renderer-webkit.sh`.
- Release validation was not performed; installed-app validation is recorded below.

## Installed-app end-to-end verification (2026-11-13)

- Source commit: `09815f6b6c9822116342109195708e8fb34259d7`.
- Opened the [same fixture](evidence/issue72/sample.md) in the previously installed 1.48.816 development app: the reported gap is visibly present after both `\(A\)` and `$A$`, and after consecutive inline formulas. [Before screenshot](evidence/issue72/before.png).
- Built using `make app LOCAL_DEPLOYMENT_TARGET=12.0`. The default build gate correctly rejected Xcode 27 with the macOS 11 target. This is a local diagnostic build, not a distributable release or evidence of macOS 11 runtime support.
- Installed the built app into `/Applications/FluxMarkdown.app`, retaining the previous app in `/tmp/flux-issue72-e2e/installed-previous.app`. `codesign --verify --strict --deep --verbose=2` passed. App and embedded extension signatures were checked; notarization was not tested.
- Read back installed renderer CSS against the built bundle: identical, SHA-256 `fcf92c2b1d7cb046c4bbdce6872a4109482af1894d4b7b7e7bed40472eefea5c`.
- Reopened the exact same Markdown file in the installed app (new process PID 6854): the gap disappears for both delimiter forms and consecutive formulas. [After screenshot](evidence/issue72/after.png).
- Pointer interaction at the first formula shows its copy control below the formula without changing prose spacing. [Control screenshot](evidence/issue72/hover.png).
- Activated the first copy control in the real app: native UI reads “已复制”; independently read the system clipboard as exactly `\(A\)`.
- Pressed Tab to the second formula copy control and Space: UI reads “已复制”; system clipboard independently reads exactly `$A$`. Restored all saved clipboard representations afterward.
- Re-ran real WebKit math coverage: all 4 cases passed, including App/Quick Look context spacing, keyboard copy/reference navigation, and narrow multilingual failure recovery.
- Scope: installed App verified on this Mac. Finder-hosted Quick Look, Intel hardware and formal release/notarization acceptance were not exercised in this check.

## Follow-up: space before displayed formulas (2026-11-15)

- New report: https://github.com/xykong/flux-markdown/issues/72#issuecomment-6880530545.
- The reporter confirms the earlier inline fix, then reports excessive vertical space before each displayed formula. No usable screenshot or original Markdown is attached to this comment.
- Hypothesis: display-math copy tools still occupy a normal-flow row above the formula even at opacity zero. This is separate from inline width reservation.
- Acceptance before implementation: real WebKit must preserve formula and following-paragraph vertical positions with copy tools enabled/disabled in App and Quick Look, across display delimiters and fenced math. Ordinary MathJax display margins must remain. Error recovery must stay in flow and preserve selectable source.

### Follow-up result

- Baseline production bundle failed the new real WebKit test: `Display copy adds 29.53125,29.53125px vertical gap in app`. Both formula output and following paragraph moved by the same amount.
- Formula copy tools now float at the display wrapper's upper trailing edge; inline tools retain their below-baseline position. Error tools return to normal flow in both cases. Standard MathJax display margins remain unchanged.
- The new windowless WebKit case passes 24 display comparisons: `\[...\]`, `$$...$$`, fenced `math` × App/Quick Look renderer contexts × 300/800px widths × English/Arabic. It also verifies pending/success geometry, error-flow positioning, normal display margins and the existing inline spacing across these settings. No test window was opened or focus taken.
- Full Jest: **67 suites / 614 tests passed**, including exact display-source copying, failed-copy source preservation, retry success and controller disposal. Production typecheck/build and `git diff --check` pass.
- Scope: verified current built renderer in real macOS WKWebView and unit tests. Installed application, actual Finder host, trusted keyboard activation, Intel device and release/notarization were not revalidated for this follow-up. No release or GitHub reply was performed; the reporter's original document remains unavailable.

### Follow-up screenshots (2026-11-15)

Saved [before](evidence/issue72-display/before.png) and [after](evidence/issue72-display/after.png) using the same [Markdown fixture](evidence/issue72-display/sample.md), 800×900-point windowless WKWebView, light theme, 18px text and enabled copy controls. Original PNGs are 1600×1800 pixels. These are reproduction screenshots, not the reporter's original document or installed-app screenshots.

The before bundle was built in an isolated temporary renderer copy with `src/styles/math.css` restored from `949be61^`; the after bundle is the current production build at `949be61`. No screen capture, focus or visible test window was used. The saved [snapshot script](evidence/issue72-display/snapshot.js) runs through `scripts/research/issue64-math/main.swift` with `FLUX_MATH_PROBE_WIDTH=800`, `FLUX_MATH_PROBE_THEME=light` and `FLUX_MATH_PROBE_SNAPSHOT=<output.png>`. Both images were visually inspected: the first and second display equations retain their contents, and the extra blank row before each is removed. Raw formula positions are recorded in `before.json` and `after.json` beside the images.
