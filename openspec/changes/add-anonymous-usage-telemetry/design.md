## Approved design

Default-on, user-disableable usage statistics. The user selected an independent
Rust service on micro-services (Ubuntu 24.04, Tokyo, 1 GiB RAM, 50 GiB local disk).
HTTPS: https://t.xykong.cc/v2/snapshots. All raw data and analysis stay in local
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
