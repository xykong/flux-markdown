#!/bin/bash
# Stock macOS only. No installation, registration repair, cache reset or upload.
set -u
umask 077
export LC_ALL=C
summarize() {
/usr/bin/osascript -l JavaScript - "$1" "$2" <<'JXA'
ObjC.import('Foundation');
function readLimited(path) {
    var f=$.NSFileHandle.fileHandleForReadingAtPath(path);
    if (!f || f.isNil()) return {text:'', state:'unavailable'};
    var data=f.readDataOfLength(4194305); f.closeFile;
    var n=Number(data.length);
    if(n>4194304)return {text:'',state:'size-limit'};
    var s=$.NSString.alloc.initWithDataEncoding(data,$.NSUTF8StringEncoding);
    if(!s || s.isNil())return {text:'',state:'invalid-encoding'};
    return {text:ObjC.unwrap(s),state:'read'};
}
function canonical(p){return typeof p==='string' && p.charAt(0)==='/' ? ObjC.unwrap($(p).stringByResolvingSymlinksInPath.stringByStandardizingPath) : '';}
function choice(x,values,fallback){return values.indexOf(x)>=0?x:fallback;}
function run(args){
    var configRead=readLimited(args[1]), cfg=JSON.parse(configRead.text);
    var input=readLimited(args[0]), records=[], invalid=0;
    try { records=JSON.parse(input.text); if(!Array.isArray(records))records=[]; }
    catch(e){input.text.split('\n').forEach(function(line){if(!line.trim())return;try{records.push(JSON.parse(line));}catch(e){invalid++;}});}
    var uuid=/^[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}$/;
    if(!uuid.test(cfg.selfToken)||!uuid.test(cfg.finderToken)||cfg.selfToken===cfg.finderToken||!canonical(cfg.expectedExecutable))throw Error('Invalid session identity');
    function empty(){return {status:'unconfirmed',lastStage:null,identityMismatches:0,actualHost:'not-verified',attempts:[],events:[]};}
    var out={schema:1,selfTest:empty(),finder:empty(),observed:choice(cfg.observed,['rendered','plain-text','blank','error','not-checked'],'not-reported'),capture:{stream:choice(cfg.stream,['completed','stopped','unavailable','exited-early','output-limit'],'unknown'),logRead:input.state,invalidRecords:invalid,eventLimitReached:records.length>1000,selfTestCommand:choice(cfg.selfTest,['rendered','unconfirmed','failed','timed-out','skipped'],'unknown')},visibleOutcomeMismatch:false,absenceIsNotProof:true,systemCandidateRecords:0};
    var stages=['prepared','fileRead','fileReadFailed','handshake','handshakeTimeout','renderStarted','rendered','rendererFailed','renderUnverified','sourceMode'];
    var re=/^FluxQuickLookStage schema=2 token=([A-F0-9-]{36}) version=([A-Za-z0-9._-]{1,64}) build=([A-Za-z0-9._-]{1,32}) attempt=([A-F0-9-]{36}) context=(compact|quicklook|unknown) stage=([A-Za-z]+) error=(none|NSCocoaErrorDomain|NSPOSIXErrorDomain|NSURLErrorDomain|WKErrorDomain|other) code=(-?\d{1,10})$/;
    records.slice(0,1000).forEach(function(e){
        if(!e||typeof e!=='object')return;
        var m=typeof e.eventMessage==='string'?e.eventMessage.match(re):null;
        if(!m){if(typeof e.eventMessage==='string' && e.eventMessage.indexOf('com.xykong.Markdown')>=0 && /\/(pkd|sandboxd|amfid|syspolicyd)$/.test(e.processImagePath||''))out.systemCandidateRecords++;return;}
        if(e.subsystem!=='com.markdownquicklook.app'||stages.indexOf(m[6])<0||!uuid.test(m[4]))return;
        var target=m[1]===cfg.selfToken?out.selfTest:m[1]===cfg.finderToken?out.finder:null;
        if(!target)return;
        if(canonical(e.processImagePath)!==canonical(cfg.expectedExecutable)||m[2]!==cfg.version||m[3]!==cfg.build){target.identityMismatches++;target.status='identity-mismatch';return;}
        target.lastStage=m[6];target.status=m[6]==='rendered'?'rendered':m[6]==='renderUnverified'?'render-unverified':/Failed$|Timeout$/.test(m[6])?'explicit-failure':'unconfirmed';
        var attempt=target.attempts.filter(function(a){return a.id===m[4];})[0];
        if(!attempt && target.attempts.length<20){attempt={id:m[4]};target.attempts.push(attempt);}
        if(attempt){attempt.context=m[5];attempt.lastStage=m[6];attempt.status=target.status;}
        else out.capture.eventLimitReached=true;
        if(target.events.length<80)target.events.push({attempt:m[4],context:m[5],stage:m[6],errorDomain:m[7],errorCode:Number(m[8]),pid:Number.isInteger(e.processID)&&e.processID>0?e.processID:null});
        else out.capture.eventLimitReached=true;
    });
    [out.selfTest,out.finder].forEach(function(t){if(t.attempts.length>1)t.status='multiple-attempts';});
    if(out.capture.eventLimitReached||input.state!=='read'){
        [out.selfTest,out.finder].forEach(function(t){if(t.status==='rendered')t.status='unconfirmed-incomplete-capture';});
    }
    out.visibleOutcomeMismatch=out.finder.attempts.some(function(a){return a.status==='rendered';})&&['plain-text','blank','error'].indexOf(out.observed)>=0;
    out.baseline={};
    if(cfg.baselinePath){var b=readLimited(cfg.baselinePath);out.capture.baselineRead=b.state;b.text.split('\n').forEach(function(line){var m=line.match(/^- (installedCopyEnabled|installedCopyRegistered|registeredCopies|otherRegisteredCopies|signature|diagnosticSessionSchema|registrationQuery): (true|false|valid|invalid|failed|\d{1,5})$/);if(m)out.baseline[m[1]]=m[2];});}
    out.processEvidence={expectedExtensionObserved:false,otherExtensionObserved:false,finderObserved:false,quickLookHostObserved:false,samples:0};
    if(cfg.samplesPath){var p=readLimited(cfg.samplesPath);out.capture.samplesRead=p.state;p.text.split('\n').forEach(function(line){if(/^sample=\d+$/.test(line)){out.processEvidence.samples++;return;}var m=line.match(/^\s*(\d+)\s+(\/.*)$/);if(!m)return;var path=canonical(m[2]);if(path===canonical(cfg.expectedExecutable))out.processEvidence.expectedExtensionObserved=true;else if(/\/MarkdownPreview.appex\/Contents\/MacOS\/MarkdownPreview$/.test(path))out.processEvidence.otherExtensionObserved=true;if(path==='/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder')out.processEvidence.finderObserved=true;if(/\/QuickLookUIService.xpc\/Contents\/MacOS\/QuickLookUIService$/.test(path))out.processEvidence.quickLookHostObserved=true;});}
    out.environment={};
    ['version','build','macOS','architecture'].forEach(function(k){var v=cfg[k];if(typeof v==='string'&&/^(\d+(\.\d+){0,3}|arm64|x86_64)$/.test(v))out.environment[k]=v;});
    return JSON.stringify(out,null,2);
}
JXA
}
if [ "${1:-}" = --summarize ]; then [ "$#" = 3 ] || exit 2; summarize "$2" "$3"; exit; fi
if [ "${1:-}" = --help ]; then
cat <<'HELP'
Usage: bash diagnose-quicklook-session.sh [--duration 90] [--app /Applications/FluxMarkdown.app] [--output DIR]
Capture starts before one self-test and one Finder preview. Return to this Terminal
and choose 1 rendered / 2 plain text / 3 blank / 4 error / 5 not checked.
Ctrl+C or the time limit preserves partial results. Share only shareable.zip after
inspection. Raw logs stay private locally; never upload the entire session folder.
No sudo, Python, Node, repair, installation, editor changes or automatic upload.
Advanced: --no-ui skips self-test and Finder reveal; --observed VALUE records an
explicit supplied outcome. --duration is 1–300 seconds of Finder observation;
setup/self-test/packaging are separately bounded. Output directory must exist.
HELP
exit
fi
app=/Applications/FluxMarkdown.app
parent=.
duration=90
observed=not-reported
no_ui=false
while [ "$#" -gt 0 ]; do
 case "$1" in
 --app|--output|--duration|--observed)
  [ "$#" -ge 2 ] || { echo 'Missing option value; use --help.' >&2; exit 2; }
  case "$1" in --app) app=$2;; --output) parent=$2;; --duration) duration=$2;; --observed) observed=$2;; esac
  shift 2;;
 --no-ui) no_ui=true;shift;;
 *) echo 'Unknown option; use --help.' >&2;exit 2;;
 esac
done
case "$duration" in ''|*[!0-9]*) echo 'Duration must be 1–300 seconds.' >&2;exit 2;; esac
[ "${#duration}" -le 3 ] && [ "$duration" -ge 1 ] && [ "$duration" -le 300 ] || exit 2
case "$observed" in not-reported|rendered|plain-text|blank|error|not-checked) :;; *) echo 'Invalid observed outcome; use --help.' >&2;exit 2;; esac
[ -d "$app" ] && [ -d "$parent" ] || { echo 'Choose an existing app and output folder with --app / --output.' >&2;exit 2; }
app=$(cd "$app" && pwd -P) || exit 2
bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist" 2>/dev/null)
[ "$bundle" = com.xykong.Markdown ] || { echo 'Choose the FluxMarkdown application with --app.' >&2;exit 2; }
exe="$app/Contents/MacOS/FluxMarkdown"
ext="$app/Contents/PlugIns/MarkdownPreview.appex/Contents/MacOS/MarkdownPreview"
[ -x "$exe" ] && [ -x "$ext" ] || { echo 'Application is incomplete; install the current DMG before this diagnostic.' >&2;exit 2; }
output=$(/usr/bin/mktemp -d "$parent/flux-quicklook-session.XXXXXX") || { echo 'Cannot create session folder; choose another --output directory.' >&2;exit 1; }
output=$(cd "$output" && pwd -P)
raw="$output/raw";safe="$output/shareable"
mkdir "$raw" "$safe" || exit 1
self_token=$(/usr/bin/uuidgen);finder_token=$(/usr/bin/uuidgen)
fixture="$output/flux-quicklook-probe-$finder_token.md"
printf '# FluxMarkdown Quick Look Test\n\n**Rendered Markdown** confirms the extension was selected.\n\nThis temporary document contains no personal data.\n' > "$fixture"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/PlugIns/MarkdownPreview.appex/Contents/Info.plist" 2>/dev/null || echo unknown)
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/PlugIns/MarkdownPreview.appex/Contents/Info.plist" 2>/dev/null || echo unknown)
stream_state=unavailable;self_state=skipped;stream_pid=;samples_pid=;capture_pid=;watchdog_pid=;finished=0;stop_reason=duration
stop_tree(){ local child; for child in $(/usr/bin/pgrep -P "$1" 2>/dev/null); do stop_tree "$child"; done; if kill -TERM "$1" 2>/dev/null;then sleep 0.1;kill -KILL "$1" 2>/dev/null || :;fi; }
capture(){
 local name=$1 limit=$2;shift 2
 (ulimit -f 128;exec "$@") > "$raw/$name.txt" 2> "$raw/$name.stderr" & capture_pid=$!
 (sleep "$limit"; if kill -0 "$capture_pid" 2>/dev/null; then touch "$raw/$name.timeout";stop_tree "$capture_pid";fi) 2>/dev/null & watchdog_pid=$!
 local status=0;wait "$capture_pid" 2>/dev/null || status=$?
 stop_tree "$watchdog_pid";wait "$watchdog_pid" 2>/dev/null || :
 capture_pid=;watchdog_pid=
 printf '%s exit=%s timeout=%s output-limit=%s\n' "$name" "$status" "$([ -f "$raw/$name.timeout" ] && echo yes || echo no)" "$([ "$status" = 153 ] && echo yes || echo no)" >> "$safe/collection-health.txt"
 return "$status"
}
finish(){
 [ "$finished" = 0 ] || return;finished=1
 trap '' INT TERM
 if [ -n "$capture_pid" ];then stop_tree "$capture_pid";wait "$capture_pid" 2>/dev/null || :;fi
 if [ -n "$watchdog_pid" ];then stop_tree "$watchdog_pid";wait "$watchdog_pid" 2>/dev/null || :;fi
 if [ -n "$samples_pid" ];then
  sample_state=stopped;kill -0 "$samples_pid" 2>/dev/null || sample_state=exited-early
  stop_tree "$samples_pid";wait "$samples_pid" 2>/dev/null || :
  printf 'process-sampling=%s\n' "$sample_state" >> "$safe/collection-health.txt"
 fi
 if [ -n "$stream_pid" ];then
  if kill -0 "$stream_pid" 2>/dev/null;then stop_tree "$stream_pid";stream_state=stopped;else stream_state=exited-early;fi
  stream_exit=0;wait "$stream_pid" 2>/dev/null || stream_exit=$?
  if [ "$stream_state" = exited-early ] && [ "$stream_exit" != 0 ];then stream_state=unavailable;fi
  [ "$stream_exit" != 153 ] || stream_state=output-limit
  printf 'stream exit=%s\n' "$stream_exit" >> "$safe/collection-health.txt"
 fi
 [ -f "$raw/events.jsonl" ] || : > "$raw/events.jsonl"
 bytes=$(/usr/bin/stat -f %z "$raw/events.jsonl" 2>/dev/null || echo 0)
 [ "$bytes" -lt 4194304 ] || stream_state=output-limit
 capture config 8 /usr/bin/osascript -l JavaScript -e 'function run(a){return JSON.stringify({expectedExecutable:a[0],version:a[1],build:a[2],selfToken:a[3],finderToken:a[4],observed:a[5],stream:a[6],selfTest:a[7],baselinePath:a[8],samplesPath:a[9],macOS:a[10],architecture:a[11]});}' "$ext" "$version" "$build" "$self_token" "$finder_token" "$observed" "$stream_state" "$self_state" "$raw/baseline.txt" "$raw/processes.txt" "$(/usr/bin/sw_vers -productVersion)" "$(/usr/bin/uname -m)" || :
 if capture summary 10 /bin/bash "$0" --summarize "$raw/events.jsonl" "$raw/config.txt";then
  /bin/cp "$raw/summary.txt" "$safe/report.json"
 else
  printf '{"schema":1,"status":"summary-unavailable","absenceIsNotProof":true}\n' > "$safe/report.json"
  echo 'Summary failed; retain this folder. You can share collection-health.txt or rerun the tool.' >&2
 fi
 printf 'stop=%s\nstream=%s\n' "$stop_reason" "$stream_state" >> "$safe/collection-health.txt"
 cat > "$safe/README.txt" <<'TXT'
Review report.json and collection-health.txt before sharing this archive in your existing GitHub issue.
This archive contains allowlisted environment, registration, process-presence and UUID-correlated stage evidence only.
Self-test and the intended Finder fixture are independent. The fixture UUID does not identify its host: Finder may invoke a compact preview before Space. Inspect each attempt/context separately. Process presence and absent logs do not establish provider selection or root cause.
A rendered stage verifies fixture DOM, not physical screen presentation; the observed outcome is recorded separately.
Raw logs, paths, document content and credentials are excluded. Raw evidence remains in the local raw folder; do not upload it.
No report has been sent. GitHub requires sign-in and a final user submission. Keep this folder if upload fails and retry attaching the same ZIP.
TXT
 if capture archive 8 /usr/bin/zip -q -X -j "$output/shareable.zip" "$safe/report.json" "$safe/collection-health.txt" "$safe/README.txt";then
  printf '\nPrepared, not sent: %s/shareable.zip\nInspect %s/shareable before attaching it. Do not upload raw/.\n' "$output" "$output"
 else
  /bin/rm -f "$output/shareable.zip"
  printf '\nZIP creation failed. Share the inspected files in %s instead; the report is preserved.\n' "$safe" >&2
 fi
}
trap 'stop_reason=interrupted;finish;exit 130' INT
trap 'stop_reason=terminated;finish;exit 143' TERM
trap finish EXIT
predicate="(subsystem == 'com.markdownquicklook.app' AND (eventMessage CONTAINS '$self_token' OR eventMessage CONTAINS '$finder_token')) OR ((process == 'pkd' OR process == 'sandboxd' OR process == 'amfid' OR process == 'syspolicyd') AND eventMessage CONTAINS 'com.xykong.Markdown')"
(ulimit -f 4096;exec /usr/bin/log stream --style ndjson --level debug --predicate "$predicate") > "$raw/events.jsonl" 2> "$raw/stream.stderr" & stream_pid=$!
(
 ulimit -f 1024
 sample=0
 while :;do
  sample=$((sample+1));printf 'sample=%s\n' "$sample"
  for name in MarkdownPreview QuickLookUIService Finder;do
   for pid in $(/usr/bin/pgrep -x "$name" 2>/dev/null);do /bin/ps -p "$pid" -o pid=,comm= 2>/dev/null || :;done
  done
  sleep 2
 done
) > "$raw/processes.txt" 2> "$raw/processes.stderr" & samples_pid=$!
capture baseline 8 "$exe" --quicklook-diagnostics || :
if ! /usr/bin/grep -qx -- '- diagnosticSessionSchema: 2' "$raw/baseline.txt";then
 echo 'This app does not advertise stage tracing. Missing stages will remain unconfirmed; no repair is needed just to collect.'
fi
printf 'Session ready: %s\nCollection is local. Do not reinstall or repair during this attempt.\n' "$output"
if [ "$no_ui" = false ];then
 echo 'Running one self-test before the Finder comparison...'
 if capture self-test 40 "$exe" --quicklook-self-test --probe-token "$self_token";then
  if /usr/bin/grep -qx 'quicklook_preview=rendered' "$raw/self-test.txt";then self_state=rendered;else self_state=unconfirmed;fi
 else
  self_state=failed
  if /usr/bin/grep -qx 'quicklook_preview=unconfirmed' "$raw/self-test.txt";then self_state=unconfirmed;fi
  [ ! -f "$raw/self-test.timeout" ] || self_state=timed-out
 fi
 capture reveal 5 /usr/bin/open -R "$fixture" || echo "Finder reveal failed. Select this test file manually: $fixture"
 echo 'In Finder select the revealed test file, press Space ONCE, then return here.'
fi
printf 'Observation: %ss. Choose 1 rendered / 2 plain text / 3 blank / 4 error / 5 not checked (Ctrl+C keeps partial evidence).\n' "$duration"
start=$SECONDS
while [ $((SECONDS-start)) -lt "$duration" ];do
 if [ -t 0 ] && read -r -n 1 -t 1 answer;then
  case "$answer" in 1) observed=rendered;;2) observed=plain-text;;3) observed=blank;;4) observed=error;;5) observed=not-checked;;*) continue;;esac
  stop_reason=user-finished;break
 else sleep 1;fi
done
finish
