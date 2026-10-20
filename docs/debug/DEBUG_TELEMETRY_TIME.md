# Telemetry timestamp correction

The existing daily counter keys explicitly use UTC but the wire format sends a
YYYY-MM-DD string and omits the snapshot preparation timestamp. Replace the new
client wire format with v3 numeric Unix seconds: envelope `timestamp` and each
bucket's `day_start_timestamp` (UTC midnight, divisible by 86400). Keep persisted
local keys and existing server v2 records compatible; no counter reset or new IDs.

UTC daily totals remain UTC daily totals: epoch timestamps do not reconstruct
users' local calendar days from already aggregated UTC buckets. Analytics must
label the daily basis explicitly. No local timezone is inferred from IP/location.

Acceptance: same instant produces identical timestamps under UTC-12, UTC+14 and
DST locales; UTC midnight remains 86400 seconds apart across DST changes. Reject
milliseconds, fractional/string timestamps, future/stale uploads and non-midnight
bucket starts. Existing v2 uploads and retries stay compatible with v3 for the same
bucket/sequence; changing an upload timestamp must not duplicate counts. Migrate
SQLite with existing data intact, validate HTTPS with synthetic data, then remove
only the synthetic records.

## Verification completed

- Regression tests failed against the old string-day protocol before implementation.
- 362 native functional tests passed (including 11 telemetry tests). Tests switch
  default timezone across UTC-12, UTC+14, America/New_York and Asia/Shanghai and
  cover spring-forward, fall-back and UTC midnight. Wire values remain Unix seconds.
- 9 Rust tests passed, including epoch-unit/type validation, midnight alignment,
  legacy-schema migration and retry timestamps that differ without duplication.
- Production migration was performed with the writer and retention job stopped,
  after a private backup. HTTPS v3 first upload and later-timestamp retry returned
  200; v2 retry of the same bucket/sequence also returned 200; advancing v3 counters
  produced exactly 2 views / 20 seconds. Milliseconds returned 400.
- Only the synthetic installation was deleted after verification; the temporary
  migration backup was removed. No general dataset deletion was performed.
- Deployed Linux executable matches local SHA256:
  `1aac7421d06ced5e468150efe1f159d385db148a0d694792a87a25001496fd49`.
- Existing persisted local day keys and IDs are preserved. Historical client
  timestamps cannot be recovered and stay NULL; receipt timestamps retain their
  original meaning. Old raw payloads and report date labels are not rewritten.
- Local native checks use the required Xcode 27 diagnostic target override (12.0);
  product minimum remains macOS 11. No new app installation/release was performed.

Operational note: the pre-migration executable used positional INSERTs and must
not be restored against the migrated table. API v2 remains supported by the new
executable; API compatibility does not imply old-binary/database compatibility.

## Timezone metadata extension

Add optional batch-level IANA `timezone_id` to v3. Do not add a transmitted UTC
offset, put a timezone on each bucket, change UTC day boundaries, or reset counters.
Preserve compatibility with earlier clients lacking the new field. Unknown/fixed
non-IANA system zones are omitted, never guessed from IP. Store an independent
observation per installation/upload timestamp (including no-new-counter retries),
with idempotency and transactional counter validation. Retain 180 days and include
these observations in installation deletion. SSH-only interval reports assign each
installation to its latest client timestamp within [start,end), not arrival order.
Report unknown metadata separately; this is installation count, not people/location.

Timezone extension verification (2026-10-20):
- New regression first failed against the missing field. A process-default timezone
  override is not a system-zone change; tests inject zone snapshots while production
  uses `TimeZone.autoupdatingCurrent`, resolving its identifier per upload.
- 363 native functional tests passed, including 12 telemetry tests. The wire contains
  timezone_id only at batch scope, never utc_offset_seconds or per-counter timezone;
  a zone change preserves bucket ID and sequence.
- 11 Rust tests passed, covering IANA TZif validation, unknown old clients, conflicting
  same-time metadata, retry deduplication and latest-client-time interval grouping.
- Production HTTPS accepted Shanghai, then newer New York, then late London, then
  duplicate New York. Invalid Asia/Invalid was rejected with 400. The report counted
  one New York installation; excluding its timestamp with the half-open end boundary
  returned one London installation. Synthetic installation deletion removed its
  observations; the verification interval returned no groups afterward.
- Deployed binary SHA256 matches the local Linux build:
  `40d5f8dac58f9e3ac7c15942dd609b99a4429d4f46d809b009d0180986f8e21e`.
- Receiver and retention timer are active. Client changes remain source/build work;
  no app release or replacement of the installed app was performed.
