"""Sample physical footprint after the fixed workload clears its document.

Usage: python3 profile-footprint.py PROBE_EXECUTABLE OUTPUT_DIRECTORY BUNDLE [WORKLOAD]
The output directory must be new. Only the monitor's WKWebView-reported WebContent
process is inspected, with its start time checked before each diagnostic. Raw diagnostics omit allocation content and stack traces.
"""
import json
from pathlib import Path
import subprocess
import sys
import time
from diagnostic_summary import leak_summary

here = Path(__file__).resolve().parent
out = Path(sys.argv[2]).resolve()
out.mkdir(parents=True, exist_ok=False)
with (out / 'monitor.log').open('w') as log:
    workload = sys.argv[4] if len(sys.argv) > 4 else str(here / 'memory-footprint.js')
    monitor = subprocess.Popen([sys.executable, str(here / 'monitor-memory.py'), sys.argv[1], str(out), sys.argv[3], workload], stdout=log, stderr=log)
    try:
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            trace = out / 'stderr.log'
            if trace.exists() and 'MEMPHASE cleared-0' in trace.read_text():
                break
            if monitor.poll() is not None:
                raise RuntimeError('Workload ended before the clear phase')
            time.sleep(0.25)
        else:
            raise TimeoutError('Clear phase not observed')
        time.sleep(10)
        identity = json.loads((out / 'process-identity.json').read_text())
        pid = identity['webContentPid']
        results = {}
        for tool, args in [('vmmap', ['-summary']), ('leaks', ['--noContent', '--nostacks'])]:
            if monitor.poll() is not None:
                raise RuntimeError('Workload ended before diagnostics completed')
            current_start = subprocess.check_output(['ps', '-p', str(pid), '-o', 'lstart='], text=True).strip()
            if not identity.get('startedAt') or current_start != identity['startedAt']:
                raise RuntimeError('WebContent process identity expired or PID was reused')
            with (out / (tool + '.txt')).open('w') as capture:
                run = subprocess.run(['/usr/bin/' + tool, *args, str(pid)], stdout=capture, stderr=subprocess.STDOUT, timeout=30)
            results[tool] = run.returncode
            captured = (out / (tool + '.txt')).read_text()
            if tool == 'vmmap' and (run.returncode != 0 or 'Physical footprint:' not in captured):
                raise RuntimeError('Physical-footprint capture failed')
            if tool == 'leaks':
                summary = leak_summary(captured)
                if summary is None or summary['pid'] != pid:
                    raise RuntimeError('Leak diagnostic did not identify the selected process')
                results['leakSummary'] = summary
        # leaks returns 1 for reported leaks; preserve that result, never label it a pass.
        (out / 'diagnostic-status.json').write_text(json.dumps(results, indent=2) + '\n')
        monitor.wait(timeout=120)
        samples = json.loads((out / 'samples.json').read_text())
        if monitor.returncode != 0 or samples['exit'] != 0 or samples['webpid'] != pid:
            raise RuntimeError('Workload failed or selected process changed')
        print(out)
    finally:
        if monitor.poll() is None:
            # Stop the owned probe before its monitor, so no child workload is orphaned.
            identity_file = out / 'process-identity.json'
            if identity_file.exists():
                import os
                import signal
                try:
                    os.kill(json.loads(identity_file.read_text())['probePid'], signal.SIGTERM)
                except ProcessLookupError:
                    pass
            monitor.terminate()
            monitor.wait(timeout=10)
