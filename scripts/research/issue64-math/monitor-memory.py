import json
import os
from pathlib import Path
import subprocess
import sys
import time
from process_identity import web_content_pid

root = Path(__file__).resolve().parents[3]
out = Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
bundle = Path(sys.argv[3]) if len(sys.argv) > 3 else root / 'web-renderer/dist'
workload = Path(sys.argv[4]) if len(sys.argv) > 4 else root / 'scripts/research/issue64-math/memory-cycle.js'

def processes():
    rows = subprocess.check_output(['ps', '-eo', 'pid=,rss=,stat=,comm='], text=True).splitlines()
    return {int(parts[0]): {'rssKiB': int(parts[1]), 'state': parts[2], 'executable': parts[3]}
            for row in rows if len(parts := row.split(None, 3)) == 4}

samples = []
with (out / 'stdout.json').open('w') as stdout, (out / 'stderr.log').open('w') as stderr:
    env = dict(os.environ, FLUX_MATH_PROBE_REPORT_PROCESS='1')
    env.pop('FLUX_MATH_PROBE_WINDOW', None)
    p = subprocess.Popen([sys.argv[1], 'flux-renderer://bundle/index.html', str(bundle), str(workload),
                          str(root / 'Tests/fixtures/issues/64/markdown-preview-test.md'), '175'],
                         stdout=stdout, stderr=stderr, env=env)
    start = time.monotonic(); webpid = None
    try:
        while p.poll() is None:
            trace = (out / 'stderr.log').read_text()
            reported = web_content_pid(trace)
            procs = processes()
            if p.poll() is not None:
                break
            if reported is not None:
                if webpid is not None and reported != webpid:
                    raise RuntimeError('WebContent process changed')
                if reported in procs and not procs[reported]['state'].startswith('Z') and 'com.apple.WebKit.WebContent.xpc/Contents/MacOS/com.apple.WebKit.WebContent' not in procs[reported]['executable']:
                    raise RuntimeError('Reported PID is not a WebContent executable')
                webpid = reported
                if not (out / 'process-identity.json').exists():
                    (out / 'process-identity.json').write_text(json.dumps({
                        'probePid': p.pid, 'webContentPid': webpid, 'source': 'owned WKWebView SPI',
                        'startedAt': subprocess.check_output(['ps', '-p', str(webpid), '-o', 'lstart='], text=True).strip(),
                        'selectedFromNewProcesses': False}, indent=2) + '\n')
            phases = [line for line in trace.splitlines() if 'MEMPHASE' in line]
            if webpid is not None:
                samples.append({'seconds': round(time.monotonic() - start, 2),
                                'rssKiB': procs[webpid]['rssKiB'] if webpid in procs else 0,
                                'processExists': webpid in procs, 'phase': phases[-1] if phases else 'startup'})
            time.sleep(1)
        if webpid is None:
            raise RuntimeError('Owned WebContent identity was not established')
        print('exit', p.returncode, 'webpid', webpid)
        (out / 'samples.json').write_text(json.dumps({'exit': p.returncode, 'webpid': webpid,
            'bundle': str(bundle), 'workload': str(workload), 'samples': samples}, indent=2))
    finally:
        if p.poll() is None:
            p.terminate()
            p.wait(timeout=10)
