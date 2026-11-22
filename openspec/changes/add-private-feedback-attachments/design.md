## Protocol and data
v2 receipt includes schema_version=2, visibility private|public and optional URL. Missing upload visibility defaults private; invalid values rejected. Private receipt returns no URL and validates committed BLOB against SHA, size. Client refuses downgrade or a different visibility. A private upload/status/delete capability never authorizes a read.

Existing legacy rows migrate as public (previously disclosed consent); newly inserted rows default private. Rename storage table to feedback_objects and provide a read-only compatibility view attachments exposing only public rows. This prevents old binary rollback from reading private rows by published ID; old write/prune operations fail closed. Migration is transactional and retains legacy public IDs as their download tokens. New public objects use separate random tokens.

Public GET/HEAD explicitly selects public visibility by download token; private ids/keys always404. No public maintainer route. SSH-authenticated maintenance CLI runs under the private service account, writes a new0600 output file (never overwrite/symlink), and logs reference/operator/time/action in a separate audit table without content or credentials. CLI/export errors do not print private data.

Private identification in GitHub uses exact FM-id plus frozen incident UUID for association; public association accepts the exact public URL. Daily reconciliation remains independent of app/reminder state. Private linked blobs expire after30days and unclaimed after7days. Private expiration applies to maintainer export as well. Backup copies expire after7days.

## Client
Persist explicit sharing choice with upload job and compare it on every retry; new drafts always private. Private success populates only reference; public success retains full download hash verification. Never substitute diagnostic SHA, filename or private URL for the public reference. Both incident and reference must survive6000-byte URL budget. Resuming a legacy public job requires explicit consent matching, or deletion and reupload; no automatic publication.

## Verification and rollout
Red/green tests cover anonymous GET/HEAD, uploader capabilities, fake admin paths, receipt corruption, privacy conflicts, legacy rows/view rollback, private retention, export permissions/audit, default checkbox/native report, crash recovery, public regressions. Build Linux off production, test isolated databases. Deploy preserves backup/schema compatibility; verify private upload, denied public reads, authenticated SSH export digest/unzip, deletion, public flow and actual GitHub reference-only page. No real Issue publication for tests. Install local signed development App; Intel real-client validation where available.
