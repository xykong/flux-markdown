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
