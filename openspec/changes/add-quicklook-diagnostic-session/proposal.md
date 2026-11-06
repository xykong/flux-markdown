# Change: Capture one Quick Look diagnostic session

## Why
#49 and #58 lack runtime evidence distinguishing provider selection, startup, file access and rendering. The user approved the preceding one-session proposal on 2026-11-06 and directed implementation; this document records that authorized scope.

## What Changes
- A standalone stock-macOS Bash/JXA collector runs bounded observation before one self-test and Finder attempt, creates a non-private fixture, accepts an observed outcome and writes a local allowlisted shareable ZIP.
- UUID-correlated stage markers identify preparation, file read, handshake, render start, verified completion and explicit failures for dedicated diagnostic fixtures only.
- Expected extension path/version/build and separate self-test/Finder tokens prevent unrelated activity from being treated as proof.
- Missing/denied/truncated evidence remains unknown; no automatic repair, upload or root-cause claim.
- #49 is closed for reporter inactivity; #58 remains the active report. Shared tooling does not establish a shared cause.

## Impact
- scripts/diagnose-quicklook-session.sh and tests.
- QuickLookProbeEvidence, QuickLookSelfTest, app CLI and extension stage instrumentation.
- Support instructions, diagnostic coverage and issue workflow policy.
