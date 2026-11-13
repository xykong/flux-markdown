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
- Release and installed-app checks are not performed in this investigation.
