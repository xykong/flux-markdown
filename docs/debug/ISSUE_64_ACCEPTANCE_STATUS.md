# Issue 64 acceptance status

Date: 2026-11-04. Implementation source: `e457b87`; later commits record validation. **The requested full objective is not complete.**

Update after user resumption: the user explicitly requested continued improvement and set the goal active. The blocking audit below records the earlier stop; it is not the current execution status. Continue available implementation/profiling/validation work while preserving unresolved external gates.

## Requirement audit

| Requirement | Authoritative evidence | Status and limits |
| --- | --- | --- |
| Original math corpus and intentional error | Original fixture hashes, math-compatibility tests, full-document-checkpoint.json | Original 11 valid TeX + MathML covered; intentional error isolated. Parenthesis escape/math syntax ambiguity explicitly documented. |
| Delimiters, fences, containers and source preservation | math-syntax, math-copy and math-compatibility tests; CRLF/table regression commits | Implemented/tested on current renderer. These are not claims about all Markdown dialects. |
| Numbering, labels and references | math-identity tests compared with independent TeX oracle; math-engine fault tests | Forward/backward, AMS/tag-star, missing/failed targets, reserved keys, Unicode and post-sanitizer references checked. |
| Session isolation and cancellation | generation/source-mode regression tests, engine cancellation/cleanup tests, native new-render-wins | Cooperative cancellation and DOM cleanup checked; synchronous execution cannot be preempted by a Promise timer. |
| Safe/offline mathematical output | shared math sanitizer tests, dynamic glyph native probe, restricted-CSP HTML reopening | Required corpus/glyph path verified locally; this does not substitute for every supported platform's resource closure. |
| Reading/search/copy/navigation | math-search/copy/reference tests; native keyboard/pasteboard case; actual App screenshot/tree | Current native renderer keyboard and clipboard verified. Actual App background numbered-link activation was not proven; test window disappeared before retry. |
| Shared feedback and preferences | error-feedback integration/inventory, six validated locales, Swift bridge/store tests | Code integrated; actual math error recovery/report activation in all hosts/languages not fully witnessed. |
| Export | actual CLI valid/invalid export, three-page reviewed PDF, standalone HTML offline reopening, readiness/race tests | Specified corpus visually checked; final refreshed full-host matrix still needed. PDF print output has no clickable link annotations; documented limitation. |
| Current-machine regression | 527 Jest tests, 29 native WebKit cases, 22 targeted Swift tests; current-native-validation.json | Passed within recorded scopes on macOS 27.0.1 arm64, local native target override 12.0. |
| Time/assets/DOM budget | production-direct-path-benchmark.json and cold-and-plain-benchmark.json | Reference-machine measured limits passed: plain p95 10ms, cold math 130ms, 1000 warm math 1416ms, math module ~1.39MB, DOM ~8.8MB. |
| Memory budget/recovery | memory-release-comparison.json and controlled experiment records | **Not accepted:** common stress corpus third-cycle RSS ~2131MiB vs release ~1520MiB (+612MiB). RSS differs from physical footprint; no agreed memory limit or independent acceptance. |
| Actual new QuickLook/Finder extension | process executable checks and quicklook-host-validation.json | **Blocked on maintenance authorization:** system selects `/Applications/FluxMarkdown.app`, not current Debug. Registry refresh did not change actual provider. |
| Minimum macOS 11 / Intel | host facts and CI configuration | **Environment missing:** local machine is macOS 27 arm64; CI macOS 15 cannot prove minimum runtime. API-removal simulation is narrower evidence. |
| VoiceOver and independent human review | existing AX tree and independent TeX artifact | **Not completed:** AX observation/keyboard tests are not speech exploration; oracle generation is not human sign-off. |

## Ready work and required external steps

1. The current candidate and untouched original installation backup are prepared under `build/issue64-host-validation/`; both pass strict signature verification. Candidate renderer index matches current production dist. Replacement has **not** been performed. After a maintenance window is authorized, revalidate the hashes, test the actual selected extension/App/Finder, then restore the original installation.
   Refresh verification caught stale resources from overlay-copying into the previous candidate. The overlay was isolated, a fresh empty-directory copy was made, and both the source app and fresh candidate passed deep strict verification. Only task-owned staging directories changed.
2. Obtain an available macOS 11/Intel execution environment or a person who can run the supplied checks. This request is pending; automatic goal continuations are not answers.
3. Schedule actual VoiceOver/host interaction verification and independent review of the expectation manifest/TeX reference. Do not mark them passed from DOM structure alone.
4. Resolve the measured memory tradeoff with an explicit reviewed budget or an approved further architectural change, then repeat the fixed workload. Do not retroactively loosen a limit merely to pass.
5. After those conditions are resolved, refresh the final build/export/native matrix and close the OpenSpec acceptance checklist only for proven items. No release, GitHub issue reply or `done` label has been made.

## Blocking audit

The same actual-provider/installation authorization condition has remained unresolved across more than three consecutive goal turns since `e464ac0`; the minimum-platform request also remains unanswered. In the intervening turns, available independent implementation fixes and local validations were completed and recorded. Current revalidation still selects the old installation and still reports only macOS 27 arm64 locally. At this acceptance stage, repeating the same local checks cannot establish the missing external gates. Preserve the complete goal and mark it blocked pending the required inputs; do not call it complete or silently waive requirements.
