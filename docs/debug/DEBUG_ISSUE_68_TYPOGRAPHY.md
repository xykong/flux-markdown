# Issue #68: parenthesized letter sequences

- Report: https://github.com/xykong/flux-markdown/issues/68
- Baseline: `2b6e0e8` (v1.45.774).
- Reproduction: render `(a) (b) (c)`; the last marker becomes `©`.
- Cause: `buildMd()` enables markdown-it's typographer, whose replacements
  rule treats every ordinary-text `(c)` as a copyright abbreviation.

## Repair and acceptance criteria

Treat this as a rendering bug and apply the reporter's automatic-detection
alternative. Preserve `(c)` / `(C)` when the preceding parenthesized letter
marker is `(b)` / `(B)` in the same case. Track markers in visible ordinary
text across inline formatting, line breaks, paragraphs and list items. Reset
the tracking at headings and fenced/indented code blocks; inline code, HTML
and automatic links do not supply sequence markers. Each render starts fresh.

Only the sequence marker is protected: independent copyright abbreviations,
explicit `©`, `&copy;`, trademark replacements and smart punctuation retain
their existing behavior. A repeated `(c)` after a completed sequence therefore
remains a copyright abbreviation. This is a heuristic: a lone `(c)` still
converts, and unrelated `(b)` followed by `(c)` in prose can look like a sequence.
Authors can use Markdown escaping or inline code for ambiguous literal text.

Protect matched markers as markdown-it `text_special` tokens before its
replacements rule, using its existing text-join stage to restore plain text.
Do not rewrite generated HTML, link destinations or the user's source.

## Verification

- Red: 9 of the 19 new integration cases failed against the original renderer.
- Green: all 19 typography cases pass; all 64 Jest suites / 591 tests pass.
- `npm run build`: TypeScript checking and production Vite build pass.
- Real WebKit: the focused issue #68 case passes against the production bundle
  for both App and Quick Look contexts, including HTML export. Executed with a
  temporary copy of the existing harness selecting only this case.
- Full WebKit run stopped at the existing foreground-focus test because the
  default window policy disables foreground interaction. No full-suite WebKit
  pass is claimed; the focused typography case needs no foreground interaction.
- No native application installation or release performed.

## Release follow-up

Published in v1.46.779 after all 33 local WebKit cases and final-tag release CI
passed. See `docs/release/RELEASE_1.46.779.md` for package/channel verification and
the remaining GitHub embedded-artwork access limitation. No local application
installation was performed.
