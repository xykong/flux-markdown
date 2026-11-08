# One Quick Look diagnostic session (#58; historical #49)

Use this when registration/reinstallation did not explain a plain-text or blank
Finder preview. Do not repeat repairs or clear caches before collecting.

The collector is `scripts/diagnose-quicklook-session.sh`. It uses only macOS tools
(Bash, JXA, Unified Logging and ZIP); reporters do not need Python, Node or Xcode.
A current app with `diagnosticSessionSchema: 2` supplies complete structured stages.
**The published v1.44.761 does not include these new stages.** They are presently
in the local diagnostic build. Older versions are accepted, but the report will
explicitly lack correlated stages; a command's self-test result is kept separate
from verified stage evidence. Do not describe an older-version run as complete.

## Reporter steps

1. Save the supplied script locally. Open Terminal and run it, replacing the script
   path with the saved file (dragging the script into Terminal can insert its path):

   ```sh
   bash /path/to/diagnose-quicklook-session.sh --output "$HOME/Desktop"
   ```

2. The tool starts capture, runs one self-test and reveals a generated, non-private
   Markdown file. In Finder, select that file and press Space **once**.
3. Return to Terminal and type one number: **1** rendered, **2** plain text,
   **3** blank, **4** error, **5** not checked. It stops automatically after 90
   seconds of observation; Ctrl+C also preserves partial evidence.
4. Inspect `shareable/report.json`, `collection-health.txt` and the README. Attach
   only `shareable.zip` to the existing issue. GitHub needs sign-in and the final
   submission is yours; the tool does not send anything.

If Finder does not reveal the file, use the path printed by the tool. If the app or
output directory is missing, pass an existing location with `--app` / `--output`.
If ZIP creation fails, the inspected files remain in `shareable/`; attach those
files or rerun the tool. A failed log capture does not prevent sharing the other
results. Do not upload the whole session directory or `raw/`.

## Included data and boundaries

The ZIP contains only allowlisted app/macOS versions and architecture, registration
status/counts, process-presence booleans, anonymous fixture/request UUIDs, stages,
preview context, error-domain/code allowlists, capture-health states, and the
selected visible outcome. ZIP metadata/resource forks are excluded. No private
document content, document paths, arbitrary error descriptions or credentials are
included. Raw filtered logs and command output remain in a permission-restricted
local folder; they may contain paths and should not be shared by default.

The tool does not install software, change editor associations, repair registrations,
clear caches, modify a private document or upload anything. The normal self-test
updates its stored result/time and may display a window; Finder reveals a new test
file. All session files remain available until the user removes that session folder.

The 90-second limit covers the Finder observation interval. Baseline, self-test and
reveal commands have separate 8/40/5-second limits. Capture files are size bounded;
partial/denied/truncated results are labelled. The collector terminates only its
own helper processes, never a pre-existing app, Finder or extension process.

## Interpreting the report

- `selfTest` and `finder` refer to different generated fixture UUIDs. `finder` is
  the **intended Finder test**, not a verified host identity. `actualHost` stays
  `not-verified`; the same file could be previewed by another host.
- Selecting a file can start Finder's compact preview before Space is pressed.
  Inspect each `attempt` and its `context` (`compact`, `quicklook`, `unknown`);
  never combine one attempt's preparation with another's completion.
- `rendered` means the matching extension completed a current render and verified
  the expected visible DOM. It does not prove physical screen presentation.
  Compare the independently supplied `observed` outcome; a discrepancy is evidence
  to investigate, not a reason to overwrite the user's observation.
- `identity-mismatch` records another executable/version/build; no private path is
  exported. `multiple-attempts` requires looking at the separate attempt results.
- `explicit-failure` has an actual stage/error event. `unconfirmed` can mean missing
  capture, unsupported instrumentation, no attempt or a failure before extension
  invocation; it does not distinguish those possibilities by itself.
- Process presence, registered/enabled state and system-related record counts do
  not identify the selected provider or prove a cause. System candidate messages
  remain private; their count alone is not a rejection diagnosis.
- An earlier completed attempt in an interrupted/truncated capture is historical
  evidence, not proof of the final state. Inspect `capture` and collection health.

## Maintainer workflow

Use one investigation/tooling track, with #58 as the active report. #49 was closed
NOT_PLANNED on 2026-11-06 for more than one calendar month without a reporter reply;
it is not a confirmed fix or proven duplicate. Preserve its separate Sequoia context.
#58's latest reporter reply is 2026-10-22; on this review date it is not inactive.
Apply the inactivity rule during later reviews; no automatic scheduled closer was
created. New evidence may justify reopening a closed report.

Do not request another reporter run until an inspectable collector and suitable
instrumented build are actually available to that reporter. Current local validation
and publication status are recorded in `docs/debug/DEBUG_QUICKLOOK_DIAGNOSTIC_SESSION.md`.
