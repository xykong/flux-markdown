## Approved design

Default-on, user-disableable usage statistics. The user selected an independent
Rust service on micro-services (Ubuntu 24.04, Tokyo, 1 GiB RAM, 50 GiB local disk).
HTTPS: https://t.xykong.cc/v3/snapshots. All raw data and analysis stay in local
SQLite. No company analytics, external database, or Python ingestion runtime.

## Counter semantics

Each installation generates random UUIDs. Counters partition by UTC calendar day,
app version, macOS version and source (app or quicklook). A random bucket ID and
monotonically increasing sequence identify each cumulative snapshot. Restart and
upgrade preserve counters. Read-only file operations do not expose file identities.
A successful visible document opening counts once; same-document rerender does not.
Same-source overlapping activity is coalesced at persistence. Seconds measure visible
reading-window activity; hidden windows, sleep and timer gaps are excluded. This
is an estimate of usage, not proof of human attention. Time is checkpointed every
15 seconds; abrupt termination can lose up to one checkpoint per live session.

Counters accumulate forever within a retained daily bucket; successful upload does
not zero them. Server stores every distinct accepted snapshot, advances a bucket's
high-water mark only for a larger sequence, rejects regressions/conflicts and retains
late snapshots without counting them twice. Daily analysis sums high-water marks,
not raw snapshot counts. Environment changes produce separate buckets.

## Scheduling and privacy

Only dirty buckets upload. A shared persisted lease permits at most one attempt per
hour across app and Quick Look, including retries. No background launch or system
wake. Failures retain cumulative values and retry on later activity. Batches contain
at most 50 buckets / 64 KiB; local storage retains 90 days / at most 720 buckets.
Remote raw snapshots and daily counters expire after 180 days. These retention
bounds are explicit; usage older than the local bound cannot be recovered offline.

Default-on disclosure appears nonmodally at first visible reading, with direct
opt-out. Settings provide the same switch. Opt-out clears local counters, rotates
identity, stops new snapshots and cancels local in-flight uploads where possible.
An already transmitted request cannot be recalled and historical server records
are not deleted by opt-out. Re-enable starts a fresh identity and excludes disabled
usage. Payloads contain only UUIDs, versions, date, architecture, channel (unknown
unless reliably known), source, sequence and cumulative seconds/views. No names,
paths, URLs, document contents, hardware serials, account identity or raw logs.

## Local architecture

State lives in ~/Library/Application Support/FluxMarkdown/Telemetry/ with directory
mode 0700 and files 0600, atomic writes and flock across processes. This is
permission-protected local storage, not an encrypted database. Corrupt/unavailable
state fails closed. Only the dedicated Telemetry directory receives a home-relative
Quick Look sandbox write exception; no document write access is added. Network and
counter writes run on a utility queue. Disclosure/preference reads are short locked
transactions; later performance improvements can cache them with invalidation.

## Server and operations

A 1.9 MiB-class Rust executable, SQLite WAL, systemd with 128 MiB memory cap,
nginx TLS/body/rate/connection limits; no public read API. TLS auto-renewal and
retention timers run locally. SQL reports are SSH-only. Administrative deletion by
installation ID is available. Public submissions are pseudonymous and untrusted;
statistics describe participating installations, not exact people or all users.

## Validation

Counter rollover, restart persistence, concurrent writers, stale acknowledgement,
opt-out/re-enable, bounded offline storage and hourly lease tests precede acceptance.
Server tests cover retry, ordering, partitioning, regression and atomic validation.
Verify the production protocol with synthetic records and remove only those records.
Native checks cover settings, sandbox access and app/Quick Look lifecycle integration.

## Global time representation (2026-10-20)

New uploads use schema v3 with integer Unix seconds: envelope `timestamp` for
snapshot preparation and per-counter `day_start_timestamp` for UTC midnight.
No date/time strings or UTC offset strings are sent by new clients. These are
absolute instants, not local clock values; unit is seconds, never milliseconds.
The server preserves numeric client timestamps separately from numeric receipt
timestamps and validates units, freshness and UTC-midnight alignment. Retry
identity remains installation/bucket/sequence, independent of upload timestamp.
Legacy v2 remains supported; local persisted bucket keys/IDs and server daily
report labels remain compatible. SQLite migration backfills numeric bucket starts
from explicitly UTC legacy dates; unknown historical client timestamps stay null.
The daily basis is still UTC, not the viewer's local day; already aggregated UTC
buckets must not be relabelled as local-day totals.

## Approved three-field time model

Each v3 batch adds optional `timezone_id` (system IANA identifier); each daily bucket
keeps `day_start_timestamp`, and envelope `timestamp` remains Unix seconds. No
`utc_offset_seconds` or per-bucket timezone is sent. Unknown fixed-offset identifiers
are omitted; old v3 requests without timezone remain valid. The server validates
against its OS-maintained IANA TZif database and records timezone observations
transactionally with counters, keyed by installation/client timestamp. Same-timestamp
conflicting metadata is rejected, exact retries deduplicate. Late arrivals do not
replace newer client-time observations. SSH `timezones START END` uses [start,end)
and the last observation per installation, grouping unknown separately. Old v1/v2
clients without observations are outside this report's coverage. Retention and
installation deletion include observations. Timezone describes the current upload,
not the location or local day of historical counters included in that upload.

## Quick Look transport repair (2026-10-26)

The preview host sandbox can reject direct URLSession DNS even with network.client.
The installed extension therefore persists counters and sends a parameterless
`flushUsage` request to its existing authenticated XPC helper. The helper alone
reads the shared state, checks opt-out, reserves the hourly lease, uploads to the
fixed HTTPS endpoint and acknowledges counters. Main-app launch is not required.
The helper retains App Sandbox and existing peer signature/path validation, with
only network.client and the dedicated Telemetry directory added to its permissions.
No arbitrary URL, request body, document path or secrets are accepted over this call.
Failed XPC wakeup does not reserve the hourly lease; wakeups are limited to once per
minute while eligible preview activity exists. Actual network attempts still use
the shared hourly limit, including failures. There is no scheduled/background app
launch; the on-demand XPC helper may live through a short request to persist its ack.
