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
