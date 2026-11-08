# Inline release credits — 2026-11-08

The maintainer requires each reporter/contributor credit inside its corresponding
feature or fix item. No separate Acknowledgments/致谢 heading or collective
thank-you list is permitted. This applies to all historical GitHub Releases,
CHANGELOG and Sparkle descriptions, and is now explicit in AGENTS.md and the
release process.

## Scope

- Scanned all 71 GitHub releases, the full CHANGELOG and all 69 Sparkle items.
- Moved the standalone sections in 23 GitHub releases and 23 CHANGELOG version
  groups into feature/fix entries. Converted 22 Sparkle descriptions in the same
  way, retaining HTML profile and issue links.
- Preserved all reporter handles, prior implementation credits and artwork.
- Two early releases have no existing Sparkle entry; no obsolete entry was added.
- Matched unnumbered early entries by their feature descriptions and the verified
  maintainer comments in [the evidence map](REPORTER_CREDIT_AUDIT_2026-11-08.json).
  Where original notes omitted the feature entirely, restored a concise entry
  backed by those comments (#10 PDF export, #13 shared preferences, #20 headless
  Homebrew registration). Attribution-only early CHANGELOG sections now contain
  the corresponding concise feature entry rather than a separate credits list.
- CHANGELOG has two historical v1.20.261 sections. #15's credit is now attached
  to the actual Mermaid file-support item in the first section, not the unrelated
  newline/zoom items in the second. Existing feature prose and ordering remain.

## Verification

- No standalone Acknowledgments/Acknowledgements/致谢 headings remain in the
  edited release bodies, full CHANGELOG or any Sparkle description.
- Every migrated reporter is attached to an entry containing the matching issue
  reference; HTML credits retain complete handles and clickable profile links.
- All 69 appcast items retain their exact non-description XML: item order,
  versions, release dates, download URLs, sizes and signatures are unchanged.
- Release artwork references and all pre-existing reporter handles are retained.
- Four generator integration tests and five publication tests pass, together
  with internal Markdown links, release-manifest integrity and diff checks.
- Every GitHub Release write is guarded by a fresh comparison against its saved
  original body, then read back. Asset identity/digests and release metadata must
  remain unchanged. Raw snapshots, exact edit plans and entry-level placement
  records remain under ignored `build/release-credit-inline/`.

All 23 GitHub Release edits were read back exactly, with assets and release
metadata unchanged. A fresh scan of all 71 public release bodies confirmed zero
standalone acknowledgment headings. The complete local CHANGELOG and all 69
Sparkle descriptions also pass the zero-heading scan. After the direct master push, both GitHub master source and the actual public
`https://raw.githubusercontent.com/xykong/flux-markdown/master/appcast.xml`
response matched the corrected feed byte-for-byte. SHA-256:
`9f23a49a6ddef49761811a0645568f30593344f97ff982e2964f23cd0b052095`.
The public Sparkle feed therefore also contains zero standalone credit headings.
