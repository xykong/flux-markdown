# Historical release reporter-credit repair — 2026-11-08

> Formatting follow-up: the maintainer rejected standalone acknowledgment
> sections. All such sections in the releases, CHANGELOG and Sparkle feed are
> now moved into their corresponding feature/fix entries. See
> [the inline-credit verification](REPORTER_CREDIT_INLINE_2026-11-08.md).

## Scope and evidence

Audited all 71 GitHub releases, 69 existing Sparkle items, CHANGELOG, GitHub issue
authors and maintainer release-confirmation comments. The reconciliation maps
45 issues to 35 reporters. It adds missing credit in 24 release bodies and 24
CHANGELOG sections and repairs 29 existing appcast descriptions, including lost
implementation-contributor names.

[Machine-readable attribution and evidence](REPORTER_CREDIT_AUDIT_2026-11-08.json)
records each issue, current reporter login, release association and source link.
Links to maintainer comments support early releases that omitted issue numbers.
An association means the release notes or maintainer discussed that report; it
is not a new claim that an unresolved report is fixed.

- Existing prose, artwork, implementation credits and troubleshooting caveats
  are retained. The initial backfill appended acknowledgment sections; the subsequent
  formatting correction embeds all those credits in their corresponding entries.
- #38 now credits reporter @hynek as well as the existing implementer @timokox.
- #24's historical `@rebelporg` attribution is updated to the verified current
  issue-author login `@zackmezera`. The former profile returned 404; no claim is
  made about whether this was a rename or an earlier attribution mistake.
- Early v1.5.87 and v1.12.136 have no existing appcast item. Their GitHub notes
  and CHANGELOG credits are repaired; obsolete update items/signatures are not
  fabricated. Three missing early CHANGELOG sections contain attribution and
  links to their full historical GitHub release notes.
- Reports with no verified release association are not assigned to a guessed
  version. Superseded/partial investigations retain their original qualifications.

## Generator repair and verification

The generator now uses the existing locked markdown-it parser, including profile
links, and passes rendered content as data to a validating Python item writer.
It no longer evaluates release prose as Perl code or truncates it at 50 lines.
Replacing an older item preserves all other versions.

Four integration tests pass: handles/links/literals/HTML escaping; replacement
of an older item; decline-without-writing; and credits after line 50. Three failed
against the original script. Five publication tests, shell syntax, internal
Markdown links, release-manifest integrity and diff whitespace checks also pass.
CI runs the new tests after installing the existing renderer dependencies.

Local backfill verification checks all 69 items: only selected descriptions may
differ. Item order, versions, dates, enclosure URLs, signatures and lengths are
identical. Every mapped reporter has a complete handle and clickable profile in
each existing matching appcast item. Broken `thanks -Alb`, `thanks )` and empty
profile-label patterns are absent. No application package or signed asset is
rebuilt, replaced or re-signed, and no new version is released.

Remote publication verifies each release body immediately before editing and
again afterward, checking asset IDs/names/sizes/digests and release metadata.
Public update-feed verification is recorded below after the final push.
Raw snapshots and resumable edit plans remain in ignored
`build/release-credit-audit/`.

## Reconciled releases

“Unchanged” means the existing credit was sufficient on that surface. All rows
remain traceable to the evidence JSON, including the issue-comment associations.

| Version | Related reporters / issues | Release | CHANGELOG | Sparkle |
| --- | --- | --- | --- | --- |
| [v1.46.779](https://github.com/xykong/flux-markdown/releases/tag/v1.46.779) | @lgsoltek #68 | Unchanged | Unchanged | Unchanged |
| [v1.45.774](https://github.com/xykong/flux-markdown/releases/tag/v1.45.774) | @ajeantt12 #49, @DevJayHay #58, @MxJ24 #64 | Updated | Updated | Updated |
| [v1.44.761](https://github.com/xykong/flux-markdown/releases/tag/v1.44.761) | @aFakeRobot #61 | Updated | Updated | Updated |
| [v1.43.755](https://github.com/xykong/flux-markdown/releases/tag/v1.43.755) | @MxJ24 #64 | Updated | Updated | Updated |
| [v1.42.645](https://github.com/xykong/flux-markdown/releases/tag/v1.42.645) | @angedell #65 | Unchanged | Unchanged | Updated |
| [v1.40.622](https://github.com/xykong/flux-markdown/releases/tag/v1.40.622) | Restore existing contributor credit | Unchanged | Unchanged | Updated |
| [v1.39.614](https://github.com/xykong/flux-markdown/releases/tag/v1.39.614) | @zhengcan #63 | Updated | Updated | Updated |
| [v1.38.608](https://github.com/xykong/flux-markdown/releases/tag/v1.38.608) | @aFakeRobot #61 | Updated | Updated | Updated |
| [v1.36.582](https://github.com/xykong/flux-markdown/releases/tag/v1.36.582) | @ziadulhuq #60 | Unchanged | Unchanged | Updated |
| [v1.36.568](https://github.com/xykong/flux-markdown/releases/tag/v1.36.568) | @ajeantt12 #49, @DevJayHay #58, @ziadulhuq #59 | Updated | Updated | Updated |
| [v1.35.525](https://github.com/xykong/flux-markdown/releases/tag/v1.35.525) | @marshalfevzi #53, @dlaporte #55 | Updated | Updated | Updated |
| [v1.35.521](https://github.com/xykong/flux-markdown/releases/tag/v1.35.521) | @ajeantt12 #49, @dethpickle #50, @arman29-dev #51, @Baggydawg #52, @marshalfevzi #53, @milstev #54, @dlaporte #55 | Updated | Updated | Updated |
| [v1.34.459](https://github.com/xykong/flux-markdown/releases/tag/v1.34.459) | @hynek #38, @hzt384232274 #44 | Updated | Updated | Updated |
| [v1.34.449](https://github.com/xykong/flux-markdown/releases/tag/v1.34.449) | @patro85 #40, @hzt384232274 #44, @hzt384232274 #45, @vnl #46, @t-hayash #47, @echoparkbaby #48 | Updated | Updated | Updated |
| [v1.34.445](https://github.com/xykong/flux-markdown/releases/tag/v1.34.445) | @marko-cancar #41 | Unchanged | Unchanged | Unchanged |
| [v1.32.427](https://github.com/xykong/flux-markdown/releases/tag/v1.32.427) | @Killer545537 #36 | Unchanged | Unchanged | Unchanged |
| [v1.31.402](https://github.com/xykong/flux-markdown/releases/tag/v1.31.402) | Restore existing contributor credit | Unchanged | Unchanged | Updated |
| [v1.31.398](https://github.com/xykong/flux-markdown/releases/tag/v1.31.398) | Restore existing contributor credit | Unchanged | Unchanged | Updated |
| [v1.30.391](https://github.com/xykong/flux-markdown/releases/tag/v1.30.391) | @aFakeRobot #30 | Updated | Updated | Updated |
| [v1.28.360](https://github.com/xykong/flux-markdown/releases/tag/v1.28.360) | @Ctrl-Alb #27 | Updated | Updated | Updated |
| [v1.27.349](https://github.com/xykong/flux-markdown/releases/tag/v1.27.349) | @Ctrl-Alb #26, @Ctrl-Alb #27 | Unchanged | Unchanged | Updated |
| [v1.26.343](https://github.com/xykong/flux-markdown/releases/tag/v1.26.343) | @Ctrl-Alb #26, @Ctrl-Alb #27 | Unchanged | Unchanged | Updated |
| [v1.25.310](https://github.com/xykong/flux-markdown/releases/tag/v1.25.310) | @qns7 #21, @ramysami #22, @3mrr4dy #23, @zackmezera #24 | Updated | Updated | Updated |
| [v1.24.303](https://github.com/xykong/flux-markdown/releases/tag/v1.24.303) | @TheChasman #19, @jwadamson #20 | Updated | Updated | Updated |
| [v1.23.297](https://github.com/xykong/flux-markdown/releases/tag/v1.23.297) | @MxJ24 #10, @joergp #17, @MxJ24 #18 | Updated | Updated | Updated |
| [v1.21.266](https://github.com/xykong/flux-markdown/releases/tag/v1.21.266) | @Zhijian-Git #13, @aFakeRobot #16 | Updated | Updated | Updated |
| [v1.20.261](https://github.com/xykong/flux-markdown/releases/tag/v1.20.261) | @h31105 #15 | Updated | Updated | Updated |
| [v1.19.250](https://github.com/xykong/flux-markdown/releases/tag/v1.19.250) | @upliftspice666 #12 | Updated | Updated | Updated |
| [v1.16.231](https://github.com/xykong/flux-markdown/releases/tag/v1.16.231) | @upliftspice666 #11 | Updated | Updated | Updated |
| [v1.16.204](https://github.com/xykong/flux-markdown/releases/tag/v1.16.204) | @MxJ24 #10 | Updated | Updated | Updated |
| [v1.16.195](https://github.com/xykong/flux-markdown/releases/tag/v1.16.195) | @upliftspice666 #8, @MxJ24 #10 | Updated | Updated | Updated |
| [v1.12.136](https://github.com/xykong/flux-markdown/releases/tag/v1.12.136) | @csaper #7 | Updated | Updated | No existing item |
| [v1.10.119](https://github.com/xykong/flux-markdown/releases/tag/v1.10.119) | @sxmad #6 | Updated | Updated | Updated |
| [v1.5.87](https://github.com/xykong/flux-markdown/releases/tag/v1.5.87) | @aFakeRobot #4 | Updated | Updated | No existing item |

## Publication outcome

All 24 GitHub release edits were read back exactly. Asset IDs, names, sizes and
digests, tag names, release titles, publication dates and draft/prerelease state
were unchanged. No PR was created. GitHub master source and the public raw URL pinned to commit
`e39d5976f304373306b4b3da0f75745bc58ce35b` match the repaired feed byte-for-byte.
SHA-256: `4b2313b0bdb9c36046c149a29bc2fcc0444a242677ccd16dc77aeaf632aaef9d`.
The unpinned `master/appcast.xml` URL initially returned the prior CDN-cached
feed (`max-age=300`); after refresh its public response also matched the repaired
feed byte-for-byte. The actual URL used by Sparkle is therefore verified.

CI's docs/renderer/generator job passed. The initial native job stopped before
compilation/tests while SwiftPM downloaded Sparkle 2.9.3: its artifact cache
reported an existing destination (exit 74). Only the failed job was rerun on a
fresh runner; no dependency or product code was changed to bypass the failure.

The failed-job retry encountered the same SwiftPM artifact destination error
before native compilation/tests. The [CI run](https://github.com/xykong/flux-markdown/actions/runs/42466219122)
is therefore not wholly green: docs/renderer/generator and production WebKit
checks passed, but native tests did not start. This external dependency-fetch
failure is recorded rather than bypassed; it does not change the verified
historical note/asset comparisons or the nine passing publication/generator
regression tests. No native product source was changed in this repair.

## Final CI follow-up

The [subsequent CI run on 965d2ca](https://github.com/xykong/flux-markdown/actions/runs/42466748626)
passed both jobs. It includes 591 renderer tests, all 33 production WebKit cases,
5 publication tests, 4 appcast-generation tests, and 389 native tests (one skipped,
zero failures). The earlier SwiftPM download blocker is resolved; the failure
records above remain as history, not an outstanding repair limitation.
