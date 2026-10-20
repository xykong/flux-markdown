# FluxMarkdown telemetry service

Deployment: micro-services, Ubuntu 24.04, Tokyo, 168.110.10.104.
This service stores pseudonymous installation events, not identifiable users.
No company statistics service, remote database, Docker, or external event storage is used.

## Layout and access

- Code: `/opt/flux-telemetry` (root-owned).
- Runtime: single Rust binary (Axum/Tokio + bundled SQLite); no Python runtime dependency.
- Raw records: `/var/lib/flux-telemetry/events.sqlite3`, SQLite WAL, service-user-only directory.
- Ingestion: `POST /v1/events`, loopback `127.0.0.1:8765` only until HTTPS is provisioned.
- Health: `GET /healthz` (process health only, does not claim database readiness).
- systemd: `flux-telemetry.service`, 128 MiB memory cap, single async runtime thread.
- Daily timer: `flux-telemetry-prune.timer`, 180-day provisional raw retention based on server receipt time.

No request access logs are enabled. Responses never echo invalid submitted values.
SQLite keeps each accepted record, with received time and original validated fields;
identical event retries acknowledge without creating another record. Conflicting IDs
return 409; invalid batches return 400 without partial insertion. At most 50 events
and 64 KiB per request. SQLite database is capped at approximately 4 GiB (1,048,576 pages); storage failures return 503.

Legacy v1 usage counters are **deltas** (new clients use v2 below) since the previous checkpoint; a final summary must
only contain the remaining delta. Event IDs must remain stable during retry. The
seven-day timestamp window bounds stale queue replay. Versions are numeric;
installation channel may be `unknown` rather than guessed. Each session carries
`source: app|quicklook`; no file identifier is allowed.

## Operations (on server)

```sh
sudo systemctl status flux-telemetry
sudo -u flux-telemetry env TELEMETRY_DB=/var/lib/flux-telemetry/events.sqlite3 \
  /opt/flux-telemetry/flux-telemetry summary
sudo systemctl start flux-telemetry-prune.service
```

Summary counts installations, not people. Reinstalls and opt-out bias estimates.
Only SSH administrators can read results. Data deletion can be performed by an
administrator using SQLite and a supplied installation ID. No public deletion API
or client deletion control has been implemented yet.

## Verification

`cargo test --manifest-path services/telemetry/Cargo.toml`
Tests use temporary databases, never production records. Deployment smoke checks
must likewise run an isolated service/database; health checks may use production.

## Public ingress and remaining client work

HTTPS ingestion is deployed at `https://t.xykong.cc/v1/events`. Nginx terminates
TLS and enforces 64 KiB bodies, per-IP request/connection limits and timeouts.
Request access/error logs are disabled. Let's Encrypt certbot.timer renews the
certificate; a deployment hook reloads nginx. Certbot is an administration tool,
not the ingestion service. OCI uses a dedicated `micro-services-telemetry` NSG
attached only to this instance, permitting TCP 80 (ACME challenge) and 443.
The system firewall persists matching rules in `/etc/iptables/rules.v4`.

- Client collection, default-on disclosure and opt-out are implemented in source; no app release has been published.
- Raw retention is 180 days, documented in the client privacy notice.
- Anonymous ingestion cannot prove a genuine app install. Do not embed shared
  administrative credentials in clients; event statistics are untrusted input.
- There is no automated backup. SQLite file space is reusable after deletion;
  offline compaction and online SQLite backup can be scheduled if needed.

This deployment does not enable telemetry in any released client.

## Build and deployment

Build on a development machine, never on the 1 GiB production host:

```sh
cargo test --locked
# In services/telemetry, using an x86_64 Linux build environment:
cargo build --release --locked
./deploy.sh target/release/flux-telemetry
```

For cross-platform Docker builds, mount this directory at `/work`, use a Rust
Debian bookworm image with `--platform linux/amd64`, and set
`CARGO_TARGET_DIR=/work/target-linux`. The production server needs neither Docker,
Rust toolchains nor Python packages for this service. Cargo.lock is committed.
The deploy script retains the previous binary when replacing an existing install.
Public ingress configuration is a template only until DNS/certificate validation.

## Build verification

Rust unit tests cover idempotent retries/conflicting IDs, rejection of private extra
fields and invalid types, and atomic rejection of invalid batches. Linux x86_64
release build uses bundled SQLite; binary size is approximately 1.9 MiB.

Server smoke verification passed using a separate temporary database: duplicate
HTTP uploads were acknowledged twice but stored once; counters were 30 seconds,
2 documents, 1 event after process exit. Production data remained empty. Public
HTTPS checks returned 400 for invalid batches, 413 for oversized bodies and 429
under a request burst. Observed systemd memory after checks: Rust ~0.6 MiB,
nginx ~4.6 MiB (idle measurements, not a sustained-load benchmark).

Certificate issuance succeeded and `certbot renew --dry-run
--no-random-sleep-on-renew --run-deploy-hooks` passed on 2026-10-19. The systemd
retention timer and certificate renewal timer are enabled. TLS keys stay on the
server and are never committed. The service does not require a user login or a
client-held repository/API secret.

## Cumulative protocol v2

`POST /v2/snapshots` supersedes delta events for new clients. The v1 route remains
available for compatibility. Each request includes schema_version=2,
installation_id, architecture, channel and snapshots (up to 50). Each snapshot has
bucket_id, UTC day, app_version, os_version, source, sequence, active_seconds and
documents_viewed. Counters persist across uploads and normal restarts.

Raw snapshots are keyed by installation/bucket/sequence. The `counters` table
maintains high-water marks, rejects decreasing counters and conflicting metadata,
and ignores late snapshots for totals. `daily` reports group by day/version/OS/source.
Distinct installations per group must not be summed across groups to infer users.

```sh
sudo -u flux-telemetry env TELEMETRY_DB=/var/lib/flux-telemetry/events.sqlite3 \
  /opt/flux-telemetry/flux-telemetry daily
sudo -u flux-telemetry env TELEMETRY_DB=/var/lib/flux-telemetry/events.sqlite3 \
  /opt/flux-telemetry/flux-telemetry delete-installation INSTALLATION_UUID
```

Client state is permission-protected and bounded (90 days / 720 buckets); normal
network attempts are shared and limited to one/hour, including failures. Server
accepts dates within 90 days; server raw and counter retention is 180 days.


## Unix-second protocol v3

New clients POST `/v3/snapshots` with `schema_version: 3`, integer `timestamp`
(preparation time, seconds since 1970-01-01T00:00:00Z), and integer
`day_start_timestamp` in each snapshot instead of the `day` string. UTC daily
starts must be divisible by 86400. All other cumulative counter fields and
acknowledgements are unchanged. v2 remains available for existing clients.

SQLite snapshots additionally store `client_timestamp` and
`bucket_start_timestamp` as INTEGER, alongside existing INTEGER `received_at`.
Migration preserves existing payloads and counters, backfills legacy UTC starts,
and leaves unknown historical client times NULL. Timestamp changes on retries do
not change deduplication identity. Daily reports label dates in UTC; they cannot
reconstruct local-day totals by shifting already aggregated buckets.


## Timezone metadata and installation distribution

v3 optionally carries one batch-level `timezone_id` (IANA, such as Asia/Shanghai).
No UTC offset is transmitted or duplicated on daily buckets. The current system
setting is sampled when preparing the batch; this is not geographic location.
Older v3 clients without the field remain accepted and are recorded as unknown.
New `timezone_observations` rows are keyed by installation/client timestamp,
independent of bucket sequence, so a changed timezone on a later retry can be
observed without counting usage again. Exact retries deduplicate, conflicting
same-timestamp metadata is rejected, and late arrivals do not override newer time.
Observations share the 180-day retention and installation-deletion operation.

```sh
sudo -u flux-telemetry env TELEMETRY_DB=/var/lib/flux-telemetry/events.sqlite3 \
  /opt/flux-telemetry/flux-telemetry timezones START_UNIX_SECONDS END_UNIX_SECONDS
```

The interval is [start,end). Each participating installation appears once in its
latest timezone within that interval; missing metadata appears as `unknown`.
Legacy v1/v2 data and pre-extension v3 requests with no observation records are
outside this report's coverage. Counts are installations, not people or countries.
Timezone aliases are retained as reported rather than inferred from IP or offsets.
The service validates identifiers against `/usr/share/zoneinfo` TZif files; keep the
Ubuntu tzdata package updated. macOS client identifiers not recognized as IANA are
omitted rather than replaced with a guessed timezone.
