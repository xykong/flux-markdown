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
We operate the usage-statistics service and its database ourselves. HTTPS
necessarily exposes the connection IP to network infrastructure. Request access
logs are disabled, and we do not save source IP addresses in usage records.

To estimate country, region and city, our server uses a local IP database and may
send the connection IP over HTTPS to [IPWhois](https://ipwhois.io/privacy),
[IP2Location.io](https://www.ip2location.io/privacy-policy) and
[IPLocate](https://www.iplocate.io/legal/privacy). These queries do not include
installation identifiers, document counts, reading times or document information.
The providers process the queried IP under their own privacy policies. Source IPs
may remain temporarily in our server's bounded in-memory lookup queue or cache
(for up to six hours); they are not persisted in our database or request logs.

Local IP-derived country/region observations follow the 180-day retention above.
Online lookup results and source-comparison metadata are kept separately for no
more than seven days and excluded from long-term telemetry backups. Country,
region and city estimates can disagree and do not establish a person's residence.
Where IP data is missing, internal reports may separately label country estimates
inferred from a reported system timezone; no province or city is inferred from
that timezone. Turning usage statistics off prevents subsequent telemetry-driven
IP lookups, except for a request already in flight.

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

## Optional promotion source association

Supporting clients also record the first effective use of a new statistics identity:
its random event identifier, Unix timestamp, app or Quick Look source, and whether
the identity is fresh, upgraded from an older state, or reset after opting back in.
Opening an association dialog is not effective use. Older states do not invent a
first-use date, and reset identities are not counted as newly acquired installations.
This lifecycle fact is acknowledged independently of daily counters and shares the
same hourly upload lease and 90-day local retention limit.

When available on a promotion landing page, you may explicitly prepare a short-lived
source link and open FluxMarkdown to confirm it. Confirmation sends the one-time
code, random claim ID, installation ID and app version to the fixed HTTPS endpoint
`t.xykong.cc/v1/claims`. The code expires after ten minutes and is kept only in app
memory. Retrying uses the same claim ID. No document information, browser history,
hardware identifier or arbitrary callback URL is sent. The page cannot tell whether
the app is installed or whether you completed confirmation. Skipping association
never blocks downloading or reading. Statistics must be enabled; association does
not silently enable them. Opt-out cancels pending local association work, although
an already transmitted request may still reach the service.

The service joins confirmed promotion evidence to eligible first effective use and
UTC activity days to report source coverage and D1/D7 return activity. Website clicks
are not completed downloads, installs, people or proof of causal growth. Unknown
sources remain unknown. Existing installations and opt-in resets are not presented
as new acquisition. Distribution channel (such as Homebrew) is separate from the
promotion source. No IP fingerprint or cross-device identity matching is used for
this association.

Raw promotion page events and touches are retained for up to 30 days. Optional
browser association contexts expire after seven days; the current page's explicit
association flow does not require such a cookie. Redeemed minimal association
records are retained for up to 180 days. Turning statistics off does not erase
previously received records; the installation-ID deletion process described above
also applies to associated facts. Server-side feature availability can be disabled
independently while downloads and ordinary usage continue to work.
