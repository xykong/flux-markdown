"""Black-box coverage/privacy tests for the distributable, stock-macOS collector."""
from pathlib import Path
import subprocess
import tempfile
import plistlib
import os
import signal
import time
import zipfile
import json
from concurrent.futures import ThreadPoolExecutor
import re
import hashlib
import unittest

ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / 'scripts/diagnose-update.sh'

class DiagnosticsTests(unittest.TestCase):
    def summarize(self, text):
        with tempfile.TemporaryDirectory() as d:
            log = Path(d) / 'events.log'
            log.write_text(text)
            result = subprocess.run(['bash', str(TOOL), '--summarize', str(log)], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            return result.stdout

    def test_timeout_does_not_invent_launchd_cause(self):
        output = self.summarize('''2026-11-02 19:32:42.759 Df Autoupdate[77103:1] [org.sparkle-project.Sparkle:Sparkle] OK: EdDSA signature is correct
2026-11-02 19:32:42.795 E Autoupdate[77103:1] [org.sparkle-project.Sparkle:Sparkle] Code signature of the new version doesn't match the old version
2026-11-02 19:33:01.089 E Autoupdate[77103:1] [org.sparkle-project.Sparkle:Sparkle] Error: Timeout: agent connection was never initiated
''')
        self.assertIn('agentConnectionTimeout', output)
        self.assertIn('archiveSignatureAccepted', output)
        self.assertIn('launchdRecords=0', output)
        self.assertIn('updaterRecords=0', output)
        self.assertNotIn('cause=signature', output)
        self.assertNotIn('onDemandPending', output)

    def test_private_and_unknown_lines_never_exported(self):
        output = self.summarize('''2026-11-02 19:33:01.089 E Autoupdate[1:1] Error: Timeout: agent connection was never initiated /Users/secret/file.md https://private.test/?token=secret
unknown arbitrary text password=hunter2
2026-11-02 19:33:01.090 Df OtherApp[22:1] OK: EdDSA signature is correct
''')
        for value in ['secret', 'private.test', 'hunter2', 'OtherApp', 'archiveSignatureAccepted']:
            self.assertNotIn(value, output)
        self.assertIn('unclassifiedRecords=', output)

    def test_signature_warning_is_not_timeout(self):
        output = self.summarize("2026-11-02 19:32:42.795 E Autoupdate[77103:1] Code signature of the new version doesn't match the old version\n")
        self.assertNotIn('agentConnectionTimeout', output)
        self.assertIn('outcome=unconfirmed', output)

    def test_other_terminal_branches(self):
        for raw, category in [('Timeout: installation data was never received', 'installationDataTimeout'), ('Agent Invalidating without having the chance to reply to installer', 'agentInvalidated'), ('pending spawn, domain in on-demand-only mode: com.xykong.Markdown-sparkle-progress', 'onDemandPending')]:
            self.assertIn(category, self.summarize('2026-11-02 19:33:01.089 E launchd[1:1] ' + raw + '\n'))

    def run_session(self, *, fail_stream=False, hang=False, interrupt=False, waiting=False, flood=False):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            app = root / 'Private User' / 'FluxMarkdown.app'
            (app / 'Contents').mkdir(parents=True)
            (app / 'Contents/Info.plist').write_bytes(plistlib.dumps({
                'CFBundleIdentifier':'com.xykong.Markdown', 'CFBundleShortVersionString':'1.38.608', 'CFBundleVersion':'608'}))
            # Substitute only in a disposable test copy. Production has no executable override.
            script = TOOL.read_text().replace('sleep 5;', 'sleep 1;')
            incident = root / 'incidents.json'
            incident.write_text(json.dumps([{'kind':'update', 'date':time.time()-978307200,
                'environment':{'appVersion':'1.38.608','targetVersion':'1.42.645','private':'secret'},
                'codes':[{'domain':'SUSparkleErrorDomain','code':4005}], 'notes':'/Users/secret'}]))
            script = script.replace('$HOME/Library/Application Support/FluxMarkdown/error-incidents.json', str(incident))
            cache = root / 'private-cache'
            cache.mkdir()
            (cache / 'private-update.dmg').write_bytes(b'test archive')
            crashes = root / 'private-crashes'
            crashes.mkdir()
            (crashes / 'Updater-secret.ips').write_text('{"exception":{"type":"EXC_BAD_ACCESS"},"namespace":"SIGNAL","private":"/Users/secret"}\n')
            script = script.replace('$HOME/Library/Caches/com.xykong.Markdown/org.sparkle-project.Sparkle', str(cache))
            script = script.replace('$HOME/Library/Logs/DiagnosticReports', str(crashes))
            commands = {
                '/usr/bin/log': 'exit 77' if fail_stream else 'while true; do echo "2026-11-02 19:33:01.089 E Autoupdate[123:1] Error: Timeout: agent connection was never initiated /Users/secret"; sleep 0.1; done',
                '/bin/launchctl': 'echo "state = waiting"' if waiting else 'echo "state = running"; echo "pid = 123"; echo "last exit code = 0"',
                '/usr/bin/codesign': 'sleep 30' if hang else 'exit 0',
            }
            if flood:
                commands['/usr/bin/log'] = '/usr/bin/yes "private raw flood /Users/secret"'
            for i, (command, body) in enumerate(commands.items()):
                shim = root / ('shim' + str(i))
                shim.write_text('#!/bin/bash\n' + body + '\n')
                shim.chmod(0o700)
                script = script.replace(command, str(shim))
            tool = root / 'diagnose.sh'
            tool.write_text(script)
            proc = subprocess.Popen(['bash', str(tool), '--duration', '4', '--app', str(app), '--output', str(root)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
            if interrupt:
                time.sleep(1.5)
                os.kill(proc.pid, signal.SIGTERM)
            stdout, stderr = proc.communicate(timeout=18)
            self.assertEqual(proc.returncode, 0, stderr.decode())
            directory = next(root.glob('flux-update-session.*'))
            self.assertEqual(directory.stat().st_mode & 0o777, 0o700)
            with zipfile.ZipFile(directory / 'shareable.zip') as z:
                self.assertFalse(any('/raw/' in name for name in z.namelist()))
                exported = '\n'.join(z.read(name).decode() for name in z.namelist() if not name.endswith('/'))
                self.assertNotIn('/Users/secret', exported)
                self.assertNotIn('Private User', exported)
                self.assertLess(sum(i.file_size for i in z.infolist()), 2*1024*1024)
            # The collector owns only children; all must be gone after finalization.
            descendants = subprocess.run(['pgrep', '-f', str(root / 'shim')], capture_output=True)
            self.assertNotEqual(descendants.returncode, 0, descendants.stdout)
            return exported

    def test_live_job_evidence_and_private_bundle(self):
        out = self.run_session()
        self.assertIn('job=progress pid=123', out)
        self.assertIn('agentConnectionTimeout', out)
        self.assertIn('stop=duration', out)
        self.assertIn('1.42.645', out)
        self.assertIn(hashlib.sha256(b'test archive').hexdigest(), out)
        self.assertIn('exception=EXC_BAD_ACCESS', out)
        self.assertNotIn('private-update', out)
        self.assertNotIn('private-crashes', out)

    def test_denied_stream_and_hung_check_preserve_partial_evidence(self):
        out = self.run_session(fail_stream=True, hang=True)
        self.assertIn('stream=failed', out)
        self.assertIn('exit=124', out)
        self.assertIn('absenceDoesNotProveNonexistence=true', out)

    def test_interruption_cleans_up_and_packages(self):
        self.assertIn('stop=interrupted', self.run_session(interrupt=True))

    def test_waiting_agent_is_observed_without_inventing_a_pid(self):
        out = self.run_session(waiting=True)
        self.assertIn('job=progress state=waiting', out)
        self.assertNotIn('job=progress pid=', out)
        self.assertNotIn('agentConnectionTimeout', out)  # uncorrelated log PID excluded

    def test_stream_output_cap_and_parallel_session_isolation(self):
        with ThreadPoolExecutor(max_workers=2) as pool:
            first = pool.submit(self.run_session, flood=True)
            second = pool.submit(self.run_session)
            a, b = first.result(), second.result()
        self.assertIn('streamOutputLimit=true', a)
        self.assertNotEqual(re.search(r'session=([^\n]+)', a)[1], re.search(r'session=([^\n]+)', b)[1])

    def test_bad_arguments_do_not_collect(self):
        for args in [['--duration', '0'], ['--duration', '901'], ['--duration', 'oops']]:
            result = subprocess.run(['bash', str(TOOL), *args], capture_output=True)
            self.assertEqual(result.returncode, 2)

if __name__ == '__main__':
    unittest.main()
