#!/bin/bash
# Deploy a previously tested x86_64 Linux binary. Does not open a public port.
set -euo pipefail
cd "$(dirname "$0")"
binary=${1:?Usage: deploy.sh PATH_TO_LINUX_BINARY}
file "$binary" | grep -q 'ELF 64-bit.*x86-64' || { echo 'Expected x86_64 Linux binary' >&2; exit 1; }
remote=ubuntu@168.110.10.104
identity='/Users/xykong/.ssh/xy.kong@gmail.com'
stage=$(ssh -i "$identity" -o BatchMode=yes "$remote" 'mktemp -d /tmp/flux-telemetry.XXXXXX')
scp -i "$identity" "$binary" "$remote:$stage/flux-telemetry"
scp -i "$identity" flux-telemetry.service flux-telemetry-prune.service flux-telemetry-prune.timer "$remote:$stage/"
ssh -i "$identity" -o BatchMode=yes "$remote" bash -s -- "$stage" <<'REMOTE'
set -euo pipefail
stage=$1
id flux-telemetry >/dev/null 2>&1 || sudo useradd --system --home /var/lib/flux-telemetry --shell /usr/sbin/nologin flux-telemetry
sudo install -d -m 755 /opt/flux-telemetry
sudo install -d -m 700 -o flux-telemetry -g flux-telemetry /var/lib/flux-telemetry
if [ -f /opt/flux-telemetry/flux-telemetry ]; then
    sudo cp /opt/flux-telemetry/flux-telemetry /opt/flux-telemetry/flux-telemetry.previous
fi
sudo install -m 755 "$stage/flux-telemetry" /opt/flux-telemetry/flux-telemetry.new
sudo mv /opt/flux-telemetry/flux-telemetry.new /opt/flux-telemetry/flux-telemetry
sudo install -m 644 "$stage"/*.service "$stage"/*.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable flux-telemetry.service flux-telemetry-prune.timer
sudo systemctl restart flux-telemetry.service flux-telemetry-prune.timer
curl --retry 5 --retry-connrefused --retry-delay 1 -fsS http://127.0.0.1:8765/healthz
sudo systemctl show flux-telemetry.service -p ActiveState -p MemoryCurrent -p MemoryMax
REMOTE
