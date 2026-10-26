# PR #62 Arabic localization and RTL acceptance

## Approved scope and baseline

User approved fixing review findings and merging PR #62 after validation. Preserve contributor commit 7aa44d0. Baseline is master c664e23 plus the PR, merged without conflicts in an isolated checkout.

Before fixes: 393 renderer tests and 20 existing WebKit cases pass. Targeted native tests (local Xcode, diagnostic macOS 12 target) execute 44 cases with four missing-translation assertions. Both Arabic bundles lack seven keys added on master. Real WebKit probe with Arabic UI and contentsSide=left reports documentLeft=20, tocLeft=504: the physical side is reversed.

## Acceptance before implementation

- Arabic key coverage matches current English in both bundles, including usage settings errors and recovery. Existing error-guidance tests and a key-parity regression must pass.
- Left/Right remain physical positions in App and Quick Look, both docked and overlay; UI language changes preserve the choice. Search stays centered over the document column.
- Native AppKit controls keep their existing physical placement; renderer reserves that edge. RTL text, code/math and English documents keep their appropriate direction.
- Run renderer tests/build, real WebKit geometry, native tests and pinned Xcode 16.4/macOS 11 CI on the exact merge candidate. Do not publish a release as part of this task.

## Fix and local verification

- Added the seven missing Arabic strings to both targets and a parity test against each target's current English keys. Red: 14 parity assertions failed. Green: complete native suite 370 tests, zero failures, one expected missing-adjacent-tap skip (local macOS 12 diagnostic target).
- Decoupled physical layout containers from text direction; Arabic contents text remains RTL while grid, toolbar placement and search centering preserve Left/Right. App floating toolbar uses an explicit LTR placement environment and Quick Look uses physical left/right anchors, matching the existing rightInset bridge even on RTL systems.
- Real WebKit red reproduced the reversed side. Green: 22 cases, including App/Quick Look, both sides, wide docked/narrow overlay, ar→en→ar switching, document/search geometry and native-right reserve. Existing source/math/document-direction checks retained.
- Renderer 43 suites / 393 tests and production build/typecheck pass. Pinned macOS 11 CI pending below.
