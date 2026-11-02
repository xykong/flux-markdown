#!/bin/bash
# Read-only, local-only Sparkle investigation. Never uploads diagnostics.
set -eu
umask 077
if [ "${1:-}" = "--live" ]; then
  shift
  exec /bin/bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/diagnose-update.sh" "$@"
fi
if [ "${1:-}" = "--help" ]; then
  cat <<'HELP'
Usage: bash scripts/collect-update-evidence.sh [APP_PATH] [OUTPUT_PARENT]
       bash scripts/collect-update-evidence.sh --live [--duration 180] [--app APP_PATH] [--output DIR]
For ONE new reproduction, prefer --live: observation starts before the attempt and
creates an allowlisted shareable.zip, with raw evidence kept separate locally.
Run immediately after ONE failed in-app update, before reinstalling or clearing caches.
Defaults: /Applications/FluxMarkdown.app and the current directory.
Creates a private, uniquely named directory; reads the last 10 minutes of logs.
Does not change the app, settings, quarantine, caches, or signing, and does not upload.
Raw logs may contain private paths, URLs and other apps' Sparkle activity.
Review/redact locally before sharing. No sudo required; denied checks are recorded.
HELP
  exit 0
fi
if [ "$#" -gt 2 ]; then
  echo 'Too many arguments. Use --help.' >&2
  exit 2
fi
app_path=${1:-/Applications/FluxMarkdown.app}
output_parent=${2:-.}
if [ ! -f "$app_path/Contents/Info.plist" ]; then
  echo 'Application Info.plist not found; supply an installed FluxMarkdown.app.' >&2
  exit 2
fi
if [ ! -d "$output_parent" ]; then
  echo 'Output parent must be an existing directory.' >&2
  exit 2
fi
output_dir=$(mktemp -d "$output_parent/flux-update-evidence.XXXXXX")
capture() {
  local label=$1
  shift
  local status=0
  "$@" > "$output_dir/$label.txt" 2>&1 || status=$?
  printf '%s exit=%s\n' "$label" "$status" >> "$output_dir/checks.txt"
}
cat > "$output_dir/README.txt" <<'NOTE'
LOCAL RAW EVIDENCE — NOT READY TO UPLOAD
No files have been sent. Review/redact paths, URLs and unrelated app activity before sharing.
The log window is the 10 minutes preceding collection, not proof of one incident.
Record the failure time/timezone, source/target versions and visible error separately.
Nonzero checks can mean denied access or missing optional components, not a root cause.
No cache deletion, quarantine removal, re-signing, settings changes or installation performed.
Crash reports are not copied automatically: inspect DiagnosticReports locally if needed.
NOTE
capture time /bin/date -u '+%Y-%m-%dT%H:%M:%SZ'
capture system /usr/bin/sw_vers
capture architecture /usr/bin/uname -m
for key in CFBundleIdentifier CFBundleShortVersionString CFBundleVersion SUFeedURL SUPublicEDKey SUEnableInstallerLauncherService SUEnableInstallerConnectionService SUVerifyUpdateBeforeExtraction; do
  capture "app-$key" /usr/libexec/PlistBuddy -c "Print :$key" "$app_path/Contents/Info.plist"
done
capture bundle-verification /usr/bin/codesign --verify --deep --strict --verbose=4 "$app_path"
capture app-attributes /bin/ls -ldeO@ "$app_path"
capture quarantine /usr/bin/xattr -p com.apple.quarantine "$app_path"
framework="$app_path/Contents/Frameworks/Sparkle.framework"
capture sparkle-version /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$framework/Resources/Info.plist"
paths=("$app_path" "$framework" "$framework/Versions/B/Autoupdate" "$framework/Versions/B/Updater.app" "$framework/Versions/B/XPCServices/Installer.xpc" "$framework/Versions/B/XPCServices/Downloader.xpc")
i=0
for component in "${paths[@]}"; do
  capture "component-$i-signature" /usr/bin/codesign -dvvv -r- "$component"
  capture "component-$i-entitlements" /usr/bin/codesign -d --entitlements :- "$component"
  i=$((i + 1))
done
capture processes /usr/bin/pgrep -fl 'FluxMarkdown|Autoupdate|org.sparkle-project|/Updater.app/'
# Include narrowly filtered system rejection messages alongside Sparkle lifecycle logs.
predicate='subsystem == "org.sparkle-project.Sparkle" OR process == "Autoupdate" OR process == "Updater" OR process == "FluxMarkdown" OR ((process == "amfid" OR process == "syspolicyd" OR process == "launchd" OR process == "taskgated-helper" OR process == "sandboxd") AND (eventMessage CONTAINS[c] "FluxMarkdown" OR eventMessage CONTAINS[c] "com.xykong.Markdown" OR eventMessage CONTAINS[c] "org.sparkle-project" OR eventMessage CONTAINS[c] "Autoupdate"))'
capture update-log /usr/bin/log show --last 10m --style compact --info --debug --predicate "$predicate"
printf 'Evidence saved locally: %s\nReview README.txt and checks.txt before sharing.\n' "$output_dir"
