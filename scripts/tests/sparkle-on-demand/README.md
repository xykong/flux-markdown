# Sparkle on-demand progress-agent regression (#61)

These diagnostic sources do not enter any product target. `Host.m` uses Sparkle's
public standard user driver, automatically accepts the feed update, then installs
and relaunches it. The real EdDSA and application signature checks remain enabled.
`OnDemand.m` changes only the progress job's `RunAtLoad` to false, keeping its Mach
service. This models a registered agent that needs an explicit demand to launch;
it does not emulate all macOS 26 launchd policies.

Run only in a developer login session with no other FluxMarkdown update underway.
The disposable bundles use the real bundle ID to validate a real published target;
user defaults, Sparkle caches and job labels are therefore shared. Do not run two
controls concurrently or change the installed application. The test host is
intentionally re-signed and is not an unmodified release reproduction.

Prepare separate output directories using an old official application (with its
original feed/public key), SDK framework with Headers, and selected runtime:

```sh
python3 scripts/tests/sparkle-on-demand/prepare.py \
  /path/to/old/FluxMarkdown.app /path/to/sdk/Sparkle.framework \
  /path/to/runtime/Sparkle.framework build/sparkle-control
```

Start a filtered Sparkle/Autoupdate/Updater log capture before each attempt. Run
one prepared host directly (absolute dylib path required):

```sh
DYLD_INSERT_LIBRARIES="$PWD/build/sparkle-control/OnDemand.dylib" \
  build/sparkle-control/FluxMarkdown.app/Contents/MacOS/FluxMarkdown
```

Capture `launchctl print gui/$(id -u)/com.xykong.Markdown-sparkle-progress` during
the attempt. The old framework must log the injection, show a registered job with
`runs = 0`, and fail with 4005 → 10 / agent connection timeout. With 2.9.3, the same
host executable and injection must start Updater and reach `TEST ready to install`.
Verify the actual replacement version, deep strict code signature and relaunched
process path, rather than treating the callback as installation success. The
120-second host deadline is a test timeout, not a product setting.

A timed-out old attempt leaves its dormant progress job registered. A subsequent
updater's initial probe can wake that orphan and report 1004 (failed to resume).
Record that outcome separately; wait until both test-owned jobs are gone before
starting the next independent attempt. Never remove a job belonging to an actual
user update. Finally run a fresh old-framework host without the injection as the
positive control: it must install successfully, establishing that the fault
injection, rather than the host/archive, causes the old failure.

Private runtime evidence and the exact recorded matrix are documented in
`docs/debug/DEBUG_ISSUE_61_SPARKLE_UPDATE.md`. Do not upload raw system logs.
