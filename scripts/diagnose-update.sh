#!/bin/bash
# Standalone, stock-macOS collector. No install, upload, sudo, or service wake-up.
set -u
umask 077
export LC_ALL=C
VERSION=1
summarize() {
  /usr/bin/awk -v allowed="${2:-}" -v app="${3:-}" '
  BEGIN { print "format=1\noutcome=unconfirmed\nattribution=process-name candidates; correlate with private PID/job evidence" }
  {
    if ($1 !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ || $2 !~ /^[0-9:.]+$/) { unknown++; next }
    related=($0 ~ / (Autoupdate|Updater|FluxMarkdown|launchd|amfid|syspolicyd|sandboxd|taskgated-helper)\[/)
    if (!related) { unknown++; next }
    # Live exports require a PID observed at the expected executable/job, or an
    # explicit app job identifier. Standalone replay remains candidate evidence.
    if (allowed != "") {
      pid=$0; sub(/^.* (Autoupdate|Updater|FluxMarkdown)\[/,"",pid); sub(/:.*/,"",pid)
      if (index(allowed,"," pid ",") == 0 && index($0,"com.xykong.Markdown-sparkle-") == 0 && !(app != "" && index($0,app) > 0)) { unknown++; next }
    }
    if ($0 ~ / launchd\[/) launch++
    if ($0 ~ / Updater\[/) agent++
    category=""
    if (index($0,"OK: EdDSA signature is correct")) category="archiveSignatureAccepted"
    if (index($0,"Code signature of the new version doesn")) category="identityMismatchWarning"
    if (index($0,"Timeout: agent connection was never initiated")) category="agentConnectionTimeout"
    if (index($0,"Timeout: installation data was never received")) category="installationDataTimeout"
    if (index($0,"Agent Invalidating without having the chance to reply to installer")) category="agentInvalidated"
    if (index($0,"pending spawn, domain in on-demand-only mode:") && index($0,"com.xykong.Markdown-sparkle-")) category="onDemandPending"
    if (index($0,"No space left on device")) category="diskFullObservation"
    if (index($0,"Permission denied") || index($0,"Operation not permitted")) category="permissionDeniedObservation"
    if (index($0,"EdDSA signature is invalid") || index($0,"EdDSA signature verification failed")) category="archiveSignatureRejectedObservation"
    if (category != "") {
      counts[category]++
      if (shown++ < 200) print $1 "T" $2 " category=" category
    } else unknown++
  }
  END { print "launchdRecords=" launch+0; print "updaterRecords=" agent+0; print "unclassifiedRecords=" unknown+0
    print "eventTruncation=" (shown>200 ? "yes" : "no")
    print "absenceDoesNotProveNonexistence=true"
  }' "$1"
}
if [ "${1:-}" = --summarize ]; then
  [ "$#" = 2 ] && [ -f "$2" ] || exit 2
  summarize "$2"
  exit
fi
duration=180
app=/Applications/FluxMarkdown.app
parent=.
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help) cat <<'HELP'
Usage: bash diagnose-update.sh [--duration 180] [--app /Applications/FluxMarkdown.app] [--output DIR]
Starts live observation BEFORE you attempt ONE normal in-app update.
Automatically finishes after 1–900 seconds; Ctrl+C finishes early and keeps partial evidence.
No sudo, third-party runtime, upload, service wake-up or app changes.
Only share the generated shareable.zip. Raw evidence stays in a private raw/ directory
and may contain private paths and unrelated Sparkle activity. Do not attach raw/ by default.
HELP
      exit 0 ;;
    --duration|--app|--output)
      [ "$#" -ge 2 ] || exit 2
      case "$1" in --duration) duration=$2;; --app) app=$2;; --output) parent=$2;; esac
      shift 2 ;;
    *) echo 'Unknown option; use --help.' >&2; exit 2 ;;
  esac
done
case "$duration" in ''|*[!0-9]*) exit 2;; esac
[ "${#duration}" -le 3 ] && [ "$duration" -ge 1 ] && [ "$duration" -le 900 ] || exit 2
[ -f "$app/Contents/Info.plist" ] && [ -d "$parent" ] || { echo 'App or output directory missing.' >&2; exit 2; }
# Reject a different application rather than inspecting arbitrary bundles.
app=$(cd "$app" && pwd -P) || exit 2
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist" 2>/dev/null)
[ "$bundle_id" = com.xykong.Markdown ] || { echo 'Expected FluxMarkdown bundle identifier.' >&2; exit 2; }
output=$(/usr/bin/mktemp -d "$parent/flux-update-session.XXXXXX") || exit 1
mkdir "$output/raw" "$output/shareable" || exit 1
raw="$output/raw"
safe="$output/shareable"
session=$(/usr/bin/uuidgen)
start=$SECONDS
start_epoch=$(/bin/date +%s)
stop_reason=duration
stream_pid=
stream_dead=0
baseline_pid=
finished=0
# Recursively stop only descendants owned by this collector. Never target app/helper PIDs.
stop_tree() {
  local pid=$1 child
  for child in $(/usr/bin/pgrep -P "$pid" 2>/dev/null); do stop_tree "$child"; done
  kill -KILL "$pid" 2>/dev/null || :
}
# Each capture has its own five-second watchdog and 32 KiB output cap.
# Both success and absence/denial are retained; exit 124 means a deadline fired.
process_snapshot() {
  /bin/ps -axo pid=,ppid=,etime=,comm= | /usr/bin/awk -v app="$app/Contents/" -v cache="$HOME/Library/Caches/com.xykong.Markdown/org.sparkle-project.Sparkle/Launcher/" 'index($0,app) || index($0,cache)'
}
capture() {
  local label=$1 pid guard status=0 began=$SECONDS
  shift
  printf '%s state=started sinceStart=%s\n' "$label" "$((SECONDS-start))" >> "$safe/checks.txt"
  (ulimit -f 32; "$@") <&0 > "$raw/$label.txt" 2>&1 & pid=$!
  (sleep 5; if kill -0 "$pid" 2>/dev/null; then
     : > "$raw/$label.timeout"
     stop_tree "$pid"
   fi) & guard=$!
  wait "$pid" 2>/dev/null || status=$?
  stop_tree "$guard"; wait "$guard" 2>/dev/null || :
  [ ! -f "$raw/$label.timeout" ] || status=124
  printf '%s exit=%s elapsed=%s bytes=%s\n' "$label" "$status" "$((SECONDS-began))" "$(/usr/bin/stat -f %z "$raw/$label.txt")" >> "$raw/checks.txt"
  # Labels are internal constants only. No arbitrary command output enters the manifest.
  printf '%s exit=%s elapsed=%s sinceStart=%s\n' "$label" "$status" "$((SECONDS-began))" "$((SECONDS-start))" >> "$safe/checks.txt"
  if [ "$(/usr/bin/stat -f %z "$raw/$label.txt")" -ge 32768 ]; then
    printf '%s outputPossiblyTruncated=true\n' "$label" >> "$safe/checks.txt"
  fi
  return "$status"
}
metadata() {
  local phase=$1 key value
  for key in CFBundleShortVersionString CFBundleVersion; do
    value=$(/usr/libexec/PlistBuddy -c "Print :$key" "$app/Contents/Info.plist" 2>/dev/null)
    if [[ "$value" =~ ^[0-9]+(\.[0-9]+){0,3}$ ]]; then
      printf '%s.%s=%s\n' "$phase" "$key" "$value" >> "$safe/session.txt"
    else printf '%s.%s=unknown\n' "$phase" "$key" >> "$safe/session.txt"; fi
  done
}
baseline() {
  local framework="$app/Contents/Frameworks/Sparkle.framework" component i=0
  capture system /usr/bin/sw_vers
  /usr/bin/awk '$1 ~ /^(ProductVersion:|BuildVersion:)$/ && $2 ~ /^[0-9A-Za-z.]+$/ { print $1 " " $2 }' "$raw/system.txt" >> "$safe/environment.txt"
  capture architecture /usr/bin/uname -m
  /usr/bin/awk '/^(arm64|x86_64)$/ { print "architecture=" $0 }' "$raw/architecture.txt" >> "$safe/environment.txt"
  capture disk /bin/df -k "$app"
  /usr/bin/awk 'NR==2 && $4 ~ /^[0-9]+$/ { print "diskAvailableKiB=" $4 }' "$raw/disk.txt" >> "$safe/environment.txt"
  capture attributes /bin/ls -ldeO@ "$app"
  capture quarantine /usr/bin/xattr -p com.apple.quarantine "$app"
  capture sparkle-version /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$framework/Resources/Info.plist"
  /usr/bin/awk '/^[0-9]+(\.[0-9]+){1,3}$/ { print "sparkleVersion=" $0 }' "$raw/sparkle-version.txt" >> "$safe/environment.txt"
  for component in "$app" "$framework" "$framework/Versions/B/Autoupdate" "$framework/Versions/B/Updater.app" "$framework/Versions/B/XPCServices/Installer.xpc"; do
    capture "signature-$i" /usr/bin/codesign -dvvv -r- "$component"
    /usr/bin/awk -v component="$i" '
      /^Signature=adhoc$/ { print "component=" component " signature=adhoc" }
      /^CDHash=[0-9a-f]+$/ { print "component=" component " " $0 }
      /^TeamIdentifier=[A-Za-z0-9]+$/ { print "component=" component " " $0 }
    ' "$raw/signature-$i.txt" >> "$safe/signatures.txt"
    capture "integrity-$i" /usr/bin/codesign --verify --strict "$component"
    capture "permissions-$i" /bin/ls -ldeO@ "$component"
    i=$((i+1))
  done
  capture entitlements /usr/bin/codesign -d --entitlements :- "$app"
  # Metadata only; no crash contents or arbitrary home-directory search.
  capture crash-index /usr/bin/find "$HOME/Library/Logs/DiagnosticReports" -maxdepth 1 -type f -mmin -10 \( -name 'Updater*' -o -name 'Autoupdate*' -o -name 'FluxMarkdown*' \) -exec /usr/bin/stat -f '%m %z %N' '{}' \;
  /usr/bin/awk 'END { print "recentCrashMetadataRecords=" NR }' "$raw/crash-index.txt" >> "$safe/environment.txt"
  : > "$raw/baseline.complete"
}
artifacts_and_crashes() {
  local candidate i=0 before after hash
  local cache_root="$HOME/Library/Caches/com.xykong.Markdown/org.sparkle-project.Sparkle"
  local crash_root="$HOME/Library/Logs/DiagnosticReports"
  capture archive-index /usr/bin/find "$HOME/Library/Caches/com.xykong.Markdown/org.sparkle-project.Sparkle" -maxdepth 6 -type f -mmin -10 \( -name '*.dmg' -o -name '*.zip' \) -print
  while IFS= read -r candidate && [ "$i" -lt 2 ]; do
    case "$candidate" in "$cache_root"/*) ;; *) continue;; esac
    [ -f "$candidate" ] && [ ! -L "$candidate" ] || continue
    before=$(/usr/bin/stat -f '%z:%m' "$candidate" 2>/dev/null) || continue
    # Never hash an unbounded file; a stable hash is still only a candidate archive.
    [ "${before%%:*}" -le 268435456 ] || continue
    if capture "archive-$i-hash" /usr/bin/shasum -a 256 "$candidate"; then
      after=$(/usr/bin/stat -f '%z:%m' "$candidate" 2>/dev/null)
      hash=$(/usr/bin/awk 'length($1)==64 && $1 ~ /^[0-9a-f]+$/ {print $1}' "$raw/archive-$i-hash.txt")
      if [ "$before" = "$after" ] && [ -n "$hash" ]; then
        printf 'candidate=%s bytes=%s sha256=%s completeness=unconfirmed ownership=app-cache\n' "$i" "${before%%:*}" "$hash" >> "$safe/artifacts.txt"
      fi
    fi
    i=$((i+1))
  done < "$raw/archive-index.txt"
  capture final-crash-index /usr/bin/find "$HOME/Library/Logs/DiagnosticReports" -maxdepth 1 -type f -mmin -10 \( -name 'Updater*.ips' -o -name 'Autoupdate*.ips' -o -name 'FluxMarkdown*.ips' -o -name 'Updater*.crash' -o -name 'Autoupdate*.crash' -o -name 'FluxMarkdown*.crash' \) -print
  i=0
  while IFS= read -r candidate && [ "$i" -lt 3 ]; do
    case "$candidate" in "$crash_root"/*) ;; *) continue;; esac
    [ -f "$candidate" ] && [ ! -L "$candidate" ] || continue
    capture "crash-$i-prefix" /usr/bin/head -c 30000 "$candidate"
    /usr/bin/awk -v candidate="$i" '
      match($0,/EXC_[A-Z_]+/) { x=substr($0,RSTART,RLENGTH); if (x ~ /^(EXC_BAD_ACCESS|EXC_BAD_INSTRUCTION|EXC_ARITHMETIC|EXC_EMULATION|EXC_SOFTWARE|EXC_BREAKPOINT|EXC_SYSCALL|EXC_MACH_SYSCALL|EXC_RPC_ALERT|EXC_CRASH|EXC_RESOURCE|EXC_GUARD|EXC_CORPSE_NOTIFY)$/) print "candidate=" candidate " exception=" x }
      /"namespace"[ ]*:/ { x=$0; sub(/^.*"namespace"[ ]*:[ ]*"/,"",x); sub(/".*$/,"",x); if (x ~ /^(SIGNAL|CODESIGNING|DYLD|WATCHDOG|RUNNINGBOARD|TCC)$/) print "candidate=" candidate " namespace=" x }
    ' "$raw/crash-$i-prefix.txt" >> "$safe/crashes.txt"
    i=$((i+1))
  done < "$raw/final-crash-index.txt"
}
finalize() {
  [ "$finished" = 0 ] || return
  finished=1
  trap '' INT TERM
  [ -z "$stream_pid" ] || [ "$stream_dead" = 1 ] || { stop_tree "$stream_pid"; wait "$stream_pid" 2>/dev/null || :; }
  [ -z "$baseline_pid" ] || { stop_tree "$baseline_pid"; wait "$baseline_pid" 2>/dev/null || :; }
  printf 'stop=%s\nelapsed=%s\nendUTC=%s\nbaselineComplete=%s\n' "$stop_reason" "$((SECONDS-start))" "$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)" "$([ -f "$raw/baseline.complete" ] && echo yes || echo no)" >> "$safe/session.txt"
  if [ -f "$raw/events.log" ] && [ "$(/usr/bin/stat -f %z "$raw/events.log")" -ge 8388608 ]; then
    echo 'streamOutputLimit=true' >> "$safe/session.txt"
  fi
  metadata final
  artifacts_and_crashes
  # JXA is supplied by macOS. Parse the existing incident store through a strict
  # allowlist, never copy the original report or command stderr to the shareable bundle.
  if capture incident-summary /usr/bin/osascript -l JavaScript - "$HOME/Library/Application Support/FluxMarkdown/error-incidents.json" "$start_epoch" <<'JXA'
ObjC.import('Foundation');
function run(args) {
  var path = $(args[0]);
  var attrs = $.NSFileManager.defaultManager.attributesOfItemAtPathError(path, null);
  if (!attrs || Number(ObjC.unwrap(attrs.objectForKey('NSFileSize'))) > 65536) throw Error('incident store unavailable or oversized');
  var data = $.NSData.dataWithContentsOfFile(path);
  if (!data) throw Error('incident store unavailable');
  var items = JSON.parse(ObjC.unwrap($.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding)));
  if (!Array.isArray(items) || items.length > 100) throw Error('invalid incident store');
  var domains=['SUSparkleErrorDomain','NSCocoaErrorDomain','NSPOSIXErrorDomain','NSURLErrorDomain','NSOSStatusErrorDomain','other'];
  var result = items.filter(function(x) {return x.kind==='update' && typeof x.date==='number' && isFinite(x.date) && x.date+978307200>=Number(args[1])-2 && x.date+978307200<=Date.now()/1000+2;}).map(function(x) {
    var out={timeUTC:new Date((x.date+978307200)*1000).toISOString()};
    if (typeof x.id==='string' && /^[0-9a-f-]{36}$/i.test(x.id)) out.incident=x.id;
    if (x.environment) ['appVersion','targetVersion','appBuild','macOS','macOSBuild','architecture'].forEach(function(k) {
      var v=x.environment[k];
      if (typeof v==='string' && v.length<=32 && /^(\d+(\.\d+){0,3}|\d+[A-Z]\d+[a-z]?|arm64|x86_64)$/.test(v)) out[k]=v;
    });
    out.codes=Array.isArray(x.codes) ? x.codes.slice(0,8).filter(function(c) {return domains.indexOf(c.domain)>=0 && typeof c.code==='number' && isFinite(c.code) && Math.floor(c.code)===c.code;}).map(function(c) {return {domain:c.domain,code:c.code};}) : [];
    if (x.updateSession && Array.isArray(x.updateSession.events)) {
      var stages=['observationStarted','checkStarted','appcastLoaded','updateFound','noUpdate','downloadStarted','downloadCompleted','downloadFailed','cancelled','extractionStarted','extractionCompleted','installHandoff','failed','cycleFinished'];
      out.stages=x.updateSession.events.slice(-32).filter(function(e) {
        return stages.indexOf(e.stage)>=0 && typeof e.elapsed==='number' && isFinite(e.elapsed) && e.elapsed>=0 && e.elapsed<=604800;
      }).map(function(e) { return {stage:e.stage,elapsed:e.elapsed}; });
    }
    return out;
  });
  return JSON.stringify({matchingIncidents:result});
}
JXA
  then /bin/cp "$raw/incident-summary.txt" "$safe/incidents.json"; fi
  capture final-integrity /usr/bin/codesign --verify --deep --strict "$app"
  capture final-processes process_snapshot
  allowed=","
  if [ -f "$raw/pids.txt" ]; then allowed=",$(/usr/bin/sort -un "$raw/pids.txt" | /usr/bin/tr '\n' ',')"; fi
  summarize "$raw/events.log" "$allowed" "$app" > "$safe/events.txt"
  printf 'artifactHash=see-artifacts-if-available-completeness-unconfirmed\nexpectedTarget=see-incidents-if-captured\ncrashCause=see-crash-candidates-if-available-not-proven-causal\n' >> "$safe/session.txt"
  cat > "$safe/README.txt" <<'NOTE'
No data was uploaded. This is an allowlisted summary; raw logs are excluded.
Event categories are process-name candidates, not proof of ownership or cause.
Inspect private raw process/job evidence locally to correlate helper PIDs with this app.
Missing records do not prove a process did not run. Nonzero checks can mean missing,
denied, failed or timed out; raw check output distinguishes these locally.
No explicit full install success is inferred. Compare initial/final version and verify
app launch/signature separately. Target version/archive/crash cause may be unavailable.
Only attach shareable.zip. Raw evidence requires a separate deliberate review/export.
NOTE
  # Explicitly label the private evidence directory; it is never in the zip.
  printf 'PRIVATE RAW DATA — do not attach by default. May contain paths, URLs and unrelated activity.\n' > "$raw/README.txt"
  # Unfinished checks are visible as missing completions; stream readiness never implies system-log access.
  if /usr/bin/ditto --norsrc --noextattr -c -k --keepParent "$safe" "$output/shareable.zip"; then
    printf '\nFinished. Attach only: %s/shareable.zip\nPrivate raw evidence: %s/raw (do not attach by default)\n' "$output" "$output"
  else echo "Packaging failed; safe files remain at $safe" >&2; fi
}
trap 'stop_reason=interrupted; exit 0' INT TERM
trap finalize EXIT
printf 'collector=%s\nsession=%s\nstartUTC=%s\nrequestedSeconds=%s\nlocation=%s\n' "$VERSION" "$session" "$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)" "$duration" "$([ "$app" = /Applications/FluxMarkdown.app ] && echo applications || echo other)" > "$safe/session.txt"
predicate='subsystem == "org.sparkle-project.Sparkle" OR (subsystem == "com.markdownquicklook.app" AND category == "Updater") OR process == "Autoupdate" OR process == "Updater" OR ((process == "launchd" OR process == "amfid" OR process == "syspolicyd" OR process == "taskgated-helper" OR process == "sandboxd") AND (eventMessage CONTAINS[c] "com.xykong.Markdown" OR eventMessage CONTAINS[c] "FluxMarkdown" OR eventMessage CONTAINS[c] "Autoupdate"))'
(ulimit -f 8192; exec /usr/bin/log stream --style compact --level debug --predicate "$predicate") > "$raw/events.log" 2>&1 & stream_pid=$!
metadata initial
baseline & baseline_pid=$!
sleep 1
if kill -0 "$stream_pid" 2>/dev/null; then
  echo 'stream=running-coverage-unconfirmed' >> "$safe/session.txt"
  echo "Observation running. Attempt ONE normal in-app update now. Auto-finish in $duration seconds; Ctrl+C finishes early."
else
  stream_status=0; wait "$stream_pid" || stream_status=$?
  stream_dead=1
  printf 'stream=failed\nstreamExit=%s\n' "$stream_status" >> "$safe/session.txt"
  echo 'Log stream unavailable; collecting degraded process/job evidence. Do not repeat an update solely for this capture.'
fi
uid=$(/usr/bin/id -u)
sample=0
while [ "$((SECONDS-start))" -lt "$duration" ]; do
  sample=$((sample+1))
  capture "sample-$sample-processes" process_snapshot
  # Match exact executable locations; unrelated Sparkle processes stay private.
  /usr/bin/awk -v sample="$sample" -v app="$app" -v cache="$HOME/Library/Caches/com.xykong.Markdown/org.sparkle-project.Sparkle/Launcher/" '
    { line=$0; sub(/^[ ]*[0-9]+[ ]+[0-9]+[ ]+[^ ]+[ ]+/,"",line)
      if (line == app "/Contents/MacOS/FluxMarkdown" ||
          line == app "/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" ||
          line == app "/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app/Contents/MacOS/Updater" || (index(line,cache)==1 && line ~ /\/Updater.app\/Contents\/MacOS\/Updater$/)) {
        print $1 >> pids
        print "sample=" sample " pid=" $1 " ppid=" $2 " elapsed=" $3 " component=" (line ~ /Autoupdate$/ ? "installer" : line ~ /Updater$/ ? "agent" : "host")
      }
    }' pids="$raw/pids.txt" "$raw/sample-$sample-processes.txt" >> "$safe/processes.txt"
  for domain in gui user; do
    for job in updater progress; do
      capture "sample-$sample-$domain-$job" /bin/launchctl print "$domain/$uid/com.xykong.Markdown-sparkle-$job"
      /usr/bin/awk -v sample="$sample" -v domain="$domain" -v job="$job" '
        $1 == "state" && $2 == "=" && $3 ~ /^(running|waiting|exited|spawn|not|pending)$/ { print "sample=" sample " domain=" domain " job=" job " state=" $3 }
        $1 == "pid" && $2 == "=" && $3 ~ /^[0-9]+$/ { print $3 >> pids; print "sample=" sample " domain=" domain " job=" job " pid=" $3 }
        $1 == "last" && $2 == "exit" && $3 == "code" && $4 == "=" && $5 ~ /^-?[0-9]+$/ { print "sample=" sample " domain=" domain " job=" job " lastExit=" $5 }
      ' pids="$raw/pids.txt" "$raw/sample-$sample-$domain-$job.txt" >> "$safe/jobs.txt"
    done
  done
  printf 'sample=%s elapsed=%s\n' "$sample" "$((SECONDS-start))" >> "$safe/session.txt"
  kb=$(/usr/bin/du -sk "$raw" | /usr/bin/awk '{print $1}')
  if [ "$kb" -ge 18000 ]; then stop_reason=sizeLimit; break; fi
  if [ "$stream_dead" = 0 ] && ! kill -0 "$stream_pid" 2>/dev/null; then
    stream_status=0; wait "$stream_pid" || stream_status=$?
    stream_dead=1
    printf 'streamExit=%s\n' "$stream_status" >> "$safe/session.txt"
    echo 'stream=exited-early-or-output-limit' >> "$safe/session.txt"
    # Keep sampling jobs even if the log stream failed.
  fi
  sleep 1
done
