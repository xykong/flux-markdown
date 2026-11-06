# Issue #63: relative SVG images

## Baseline and acceptance (2026-10-26)

- Report: https://github.com/xykong/flux-markdown/issues/63; 1.36.582 versus working 1.34.475.
- Source baseline: 375d12a, published 1.38.608. Reporter supplied HTML and Markdown references to plugin/assets/plugin.svg; actual SVG and document location are not supplied. Form says macOS 27; embedded diagnostics say 26.7.1 / 25G241.
- Before changing implementation: reproduce the exact three reference forms using a minimal SVG; require actual decoded image dimensions in real WebKit, with and without native image inlining. Preserve allowlisting, symlink checks and resource budgets.
- A synthetic fixture passing does not establish that the reporter's SVG or sandbox location works. Do not claim the 8 MiB change fixes this report without evidence.

## Verified finding

- Added the reporter's three references to Jest and the real WebKit integration harness before implementation. Both failed: the HTML image lost its src. WebKit export readiness failed on that missing source; the other images' zero dimensions at that instant were not proof of independent failures.
- The URI regex's negated character class used an unescaped hyphen between dot and colon, forming the ASCII range `.-:`. This accidentally excluded slash and digits as scheme terminators. Bare relative HTML paths containing a directory were stripped. Dot-prefixed paths escaped this specific defect; Markdown images were rewritten before sanitization.
- Escaped the hyphen to preserve relative paths without allowing executable/unknown schemes. Added URI safety checks and actual SVG decoding assertions for all three references, app/quicklook renderer contexts, and native inlining on/off.
- Green: production typecheck/build and all 20 real WebKit cases pass. This is an unsandboxed WebKit harness, not proof of the reporter's Finder sandbox access.
- The pure Markdown failure is not reproduced with the minimal SVG. Actual SVG, location category, affected host, and exact OS remain necessary to resolve the whole report. No released-fix or done claim is justified yet.

## Follow-up

- Full renderer suite: 43 suites / 388 tests passed; production typecheck/build passed.
- Local fix committed as `5a83055`; not published. Reporter response posted and read back: https://github.com/xykong/flux-markdown/issues/63#issuecomment-6412707064.
- Status: partial local fix; waiting for the actual SVG/host/location and OS clarification. Issue remains open without done.

## 2026-11-06 follow-up: matching public SVG

The partial HTML-path fix above was published in v1.39.614; the earlier local-only
status is historical. No new reporter reply has arrived. The reporter's latest
message is October 21, so the inactivity closure threshold has not been reached.

Found the reporter's public repository `https://github.com/zhengcan/dbx-notebook`
with `plugin/assets/plugin.svg`, an SQL Notebook SVG matching the issue's path and
label. Blob `d3043c119bfacf4a688c71831694f82110a53556` is 861 bytes and uses a
viewBox without explicit width/height. Its first public file commit is October 22
(`3e2db9a6f2deae4fe25f2e7b41583b4f94302ba9`), after the October 21 report; this is
a matching public candidate, not proof of the exact originally failing bytes.

Tested that SVG against the unchanged production WebKit harness, substituting only
the fixture image and checking actual complete/nonzero decoded dimensions instead
of the synthetic fixture's fixed 96px intrinsic size. All three reported reference
forms decoded in App/QuickLook renderer contexts, both via local scheme and native
image inlining (12 image/context/route combinations). Existing export-readiness
checks passed too. Evidence: ignored `build/issue63-public-svg/`, including original
asset, isolated probe and result log. No external repository code was executed.

No remaining renderer failure was reproduced with this public SVG. Finder sandbox
access on the reporter's machine, file location and exact original bytes remain
unconfirmed. Keep the issue open without a whole-issue done claim; no new image
permission change or speculative fix is justified by these results.
