# Usage statistics

FluxMarkdown usage statistics are enabled by default. The first reading view
explains this and offers **Turn Off Usage Statistics**. You can also turn off
**Share Usage Statistics** in Settings. This applies to the app and Quick Look.

We collect random installation and counter identifiers, app/macOS versions,
CPU architecture, system IANA timezone identifier, installation channel if known, and daily cumulative reading
seconds and document-view counts, separately for the app and Quick Look.
We do not send document names, paths, contents, URLs, account identifiers,
hardware serial numbers or raw diagnostic logs. A repeated opening counts again;
a refresh does not. We do not identify or count distinct files.

Days use UTC. Uploads represent preparation time and UTC day starts as integer Unix timestamps in seconds, with no local date/time strings or offsets. UTC daily totals are not users’ local-calendar-day totals. Time estimates visible reading-window activity, excluding hidden
windows, sleep and long scheduling gaps. It does not measure attention. A crash
can lose up to 15 seconds since the last checkpoint.

With new usage, the client attempts HTTPS upload to **t.xykong.cc** at most once
per hour while running. It never wakes the computer or launches just to upload.
Offline counters remain for up to 90 days, subject to a 720-bucket limit. Data is
stored locally with restrictive filesystem permissions, not application-level
encryption. Server records are stored on our Tokyo server for up to 180 days.
No external analytics provider or remote database is used. HTTPS necessarily
exposes the connection IP to network infrastructure; it is not stored in usage
records, and request access logs are disabled.

Turning statistics off clears unsent local counters and rotates the random
identity. Re-enabling starts a new counter identity; disabled usage is not collected.
An already transmitted request may still arrive. Opt-out does not erase historical
server records; administrators can delete records for a supplied installation ID.
The random ID is stored in the local Telemetry/counters.json file. Do not post
that file publicly. Error reports are a separate, user-initiated feature.

These records are **pseudonymous**, since multiple snapshots share an installation
identifier. Installation counts are not people counts; reinstalls, opt-out and
network failures affect coverage. The purpose is deciding OS support and improving
the product based on actual usage.


The system timezone is sent once per batch as `timezone_id`, not on every daily
counter. No UTC offset is sent; it can be derived from the IANA timezone rules and
Unix timestamp if needed. A timezone describes the device setting, not verified
location or nationality. Unknown/non-IANA fixed-offset settings are omitted rather
than guessed. Timezone reports count each installation once using its latest
reported timezone in the selected Unix-time interval; unavailable metadata is
reported as unknown. Historical UTC daily totals are not reassigned to local days.
