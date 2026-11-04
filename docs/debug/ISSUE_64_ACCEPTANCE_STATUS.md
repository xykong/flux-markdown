# Issue 64 acceptance status

Date: 2026-11-04. Latest complete renderer regression uses base commit `33ece88` plus the recorded responsive inline-math layout implementation; earlier evidence retains its own source revision. **The requested full objective is not complete.**

Update after user resumption: the user explicitly requested continued improvement and set the goal active. The blocking audit below records the earlier stop; it is not the current execution status. Continue available implementation/profiling/validation work while preserving unresolved external gates.

## Requirement audit

| Requirement | Authoritative evidence | Status and limits |
| --- | --- | --- |
| Original math corpus and intentional error | Original fixture hashes, math-compatibility tests, full-document-checkpoint.json | Original 11 valid TeX + MathML covered; intentional error isolated. Parenthesis escape/math syntax ambiguity explicitly documented. |
| Delimiters, fences, containers and source preservation | math-syntax, math-copy and math-compatibility tests; CRLF/table regression commits | Implemented/tested on current renderer. These are not claims about all Markdown dialects. |
| Numbering, labels and references | math-identity tests compared with independent TeX oracle; math-engine fault tests | Forward/backward, AMS/tag-star, missing/failed targets, reserved keys, Unicode and post-sanitizer references checked. |
| Session isolation and cancellation | generation/source-mode regression tests, engine cancellation/cleanup tests, native new-render-wins | Cooperative cancellation and DOM cleanup checked; synchronous execution cannot be preempted by a Promise timer. |
| Safe/offline mathematical output | shared math sanitizer tests, dynamic glyph native probe, restricted-CSP HTML reopening | Required corpus/glyph path verified locally; this does not substitute for every supported platform's resource closure. |
| Reading/search/copy/navigation | math-search/copy/reference tests; native keyboard/pasteboard case; actual App screenshot/tree | Current native renderer keyboard, clipboard and local arrow-key scrolling verified; 16 geometry/appearance cases cover native 1x/2x zoom at 320/960 points. Actual App background numbered-link activation was not proven; test window disappeared before retry. |
| Shared feedback and preferences | error-feedback integration/inventory, Swift bridge/store tests, production-e2e-report.json resourceFailure | 18 native WebKit cases verify six-language actions across three renderer contexts, fixed diagnostic transport, incident identity, stale-control rejection and recovery. Actual native host recovery/report execution and VoiceOver remain unproven. |
| Export | current actual CLI valid/invalid export, two-page reviewed PDF, product-export-runner-report.json, standalone HTML offline reopening, readiness/race tests | Specified corpus visually checked; final refreshed full-host matrix still needed. Current refreshed PDF has an internal GoTo annotation to the numbered equation; viewer interaction still needs its own check. |
| Current-machine regression | 535 Jest tests, 29 native WebKit cases; production-e2e-report.json. Earlier 22 targeted Swift tests: current-native-validation.json | Passed within recorded scopes on macOS 27.0.1 arm64, local native target override 12.0 for the app build. |
| Production module/resource closure | production-e2e-report.json, scripts/issue64/asset-closure.* | All 165 Vite manifest entries checked; all 40 SVG dynamic glyph modules loaded by native WebKit; deliberately deleted double-struck module rejected by static and native checks; bundled attribution hashes match. Does not prove every glyph's visual correctness or older platforms. |
| Time/assets/DOM budget | inline-overflow-benchmark.json and cold-and-plain-benchmark.json | Reference-machine measured limits passed: plain p95 10ms, cold math 130ms, 1000 warm math 833ms, math module ~1.39MB, DOM ~8.8MB. |
| Memory budget/recovery | memory-release-comparison.json; physical-footprint-comparison.json | **Not accepted:** RSS is higher, but a fresh 10-render diagnostic measures post-clear physical footprint 58.0 MiB current vs 77.7 MiB release, with the same 1664-byte leak report. Rounded physical peak remains higher (1.6 GiB vs 1.1 GiB). Peak/budget acceptance and repeated physical-footprint measurements remain open; high RSS alone is not a multi-GiB retained-object leak. |
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

## Historical blocking audit (superseded by resumption)

The earlier stop cited the unresolved actual-provider/installation authorization and minimum-platform requests. The user then explicitly resumed work, and additional local implementation and validation work continued. Those external gates remain unproven, but this historical audit is not an instruction to stop current work or change the active goal to blocked. Do not call the objective complete or silently waive requirements.
