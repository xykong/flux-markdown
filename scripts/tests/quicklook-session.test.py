"""Evidence attribution/privacy tests; Python is a development-only dependency."""
from pathlib import Path
import json, subprocess, tempfile, unittest, plistlib, os, signal, time, zipfile
ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / 'scripts/diagnose-quicklook-session.sh'
SELF = '11111111-1111-4111-8111-111111111111'
FINDER = '22222222-2222-4222-8222-222222222222'
EXE = '/Applications/FluxMarkdown.app/Contents/PlugIns/MarkdownPreview.appex/Contents/MacOS/MarkdownPreview'

def event(stage, token=FINDER, path=EXE, version='1.44.761', build='761', error='none', code='0', attempt='33333333-3333-4333-8333-333333333333', context='quicklook'):
    return {'subsystem':'com.markdownquicklook.app', 'processImagePath':path, 'processID':42,
            'eventMessage':f'FluxQuickLookStage schema=2 token={token} version={version} build={build} attempt={attempt} context={context} stage={stage} error={error} code={code}'}

class EvidenceTests(unittest.TestCase):
    def summarize(self, entries, **changes):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);(p/'events.json').write_text(entries if isinstance(entries,str) else json.dumps(entries))
            cfg={'expectedExecutable':EXE,'version':'1.44.761','build':'761','selfToken':SELF,'finderToken':FINDER,'observed':'not-reported','stream':'completed','selfTest':'unconfirmed'}
            cfg.update(changes);(p/'config.json').write_text(json.dumps(cfg))
            r=subprocess.run(['bash',str(TOOL),'--summarize',str(p/'events.json'),str(p/'config.json')],capture_output=True,text=True)
            self.assertEqual(r.returncode,0,r.stderr)
            return json.loads(r.stdout)
    def test_success_and_hosts_stay_separate(self):
        x=self.summarize([event('rendered',token=SELF)])
        self.assertEqual(x['selfTest']['status'],'rendered')
        self.assertEqual(x['finder']['status'],'unconfirmed')
        x=self.summarize([event(s) for s in ['prepared','fileRead','handshake','renderStarted','rendered']],observed='rendered')
        self.assertEqual(x['finder']['status'],'rendered')
        self.assertEqual(x['finder']['lastStage'],'rendered')
    def test_compact_and_full_attempts_are_not_combined(self):
        x=self.summarize([event('rendered',context='compact'),event('prepared',attempt='44444444-4444-4444-8444-444444444444')])
        self.assertEqual(x['finder']['status'],'multiple-attempts')
        self.assertEqual(x['finder']['attempts'][0]['context'],'compact')
        self.assertEqual(x['finder']['attempts'][0]['status'],'rendered')
        self.assertEqual(x['finder']['attempts'][1]['status'],'unconfirmed')
        self.assertEqual(x['finder']['actualHost'],'not-verified')
    def test_other_copy_version_build_and_unrelated_token(self):
        for e in [event('rendered',path='/tmp/secret/FluxMarkdown.app/Contents/PlugIns/MarkdownPreview.appex/Contents/MacOS/MarkdownPreview'),event('rendered',build='762'),event('rendered',version='old')]:
            x=self.summarize([e]);self.assertEqual(x['finder']['status'],'identity-mismatch');self.assertNotIn('secret',json.dumps(x))
        x=self.summarize([event('rendered',token='33333333-3333-4333-8333-333333333333')]);self.assertEqual(x['finder']['status'],'unconfirmed')
    def test_explicit_failures_not_inferred_from_absence(self):
        for stage in ['fileReadFailed','handshakeTimeout','rendererFailed','renderUnverified','sourceMode']:
            x=self.summarize([event(stage,error='NSCocoaErrorDomain',code='513')]);self.assertEqual(x['finder']['lastStage'],stage);self.assertNotEqual(x['finder']['status'],'rendered')
        x=self.summarize([],stream='unavailable');self.assertEqual(x['finder']['status'],'unconfirmed');self.assertEqual(x['capture']['stream'],'unavailable')
    def test_unknown_private_fields_and_legacy_records_not_exported(self):
        e=event('prepared');e['private']='PASSWORD SECRET /Users/private/doc.md'
        x=self.summarize([e,{'eventMessage':'Failed /Users/private/doc.md password=SECRET'},event('rendered',error='SECRET')])
        self.assertNotIn('SECRET',json.dumps(x));self.assertNotIn('/Users/',json.dumps(x));self.assertEqual(x['finder']['lastStage'],'prepared')
    def test_malformed_fields_and_order_do_not_claim_success(self):
        x=self.summarize([event('rendered',code='0\nSECRET'),event('prepared'),event('rendererFailed')])
        self.assertEqual(x['finder']['lastStage'],'rendererFailed')
        x=self.summarize([event('rendered'),event('prepared')]);self.assertNotEqual(x['finder']['status'],'rendered')
    def test_user_outcome_cannot_override_evidence(self):
        x=self.summarize([],observed='rendered');self.assertEqual(x['finder']['status'],'unconfirmed');self.assertEqual(x['observed'],'rendered')
        x=self.summarize([event('rendered')],observed='blank');self.assertEqual(x['finder']['status'],'rendered');self.assertTrue(x['visibleOutcomeMismatch'])
    def test_ndjson_corruption_and_file_limit(self):
        x=self.summarize('not-json\n'+json.dumps(event('prepared'))+'\n'+json.dumps(event('rendered'))+'\n')
        self.assertEqual(x['finder']['status'],'rendered');self.assertEqual(x['capture']['invalidRecords'],1)
        x=self.summarize('x'*4194305);self.assertEqual(x['capture']['logRead'],'size-limit');self.assertEqual(x['finder']['status'],'unconfirmed')
    def test_bounds_and_unknown_metadata(self):
        x=self.summarize([event('prepared')]*1100,observed='SECRET',stream='SECRET')
        self.assertTrue(x['capture']['eventLimitReached']);self.assertNotIn('SECRET',json.dumps(x));self.assertLess(len(json.dumps(x)),30000)

class LifecycleTests(unittest.TestCase):
    def app(self, p, body):
        app=p/'Mock.app';(app/'Contents/MacOS').mkdir(parents=True)
        (app/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'com.xykong.Markdown'}))
        exe=app/'Contents/MacOS/FluxMarkdown';exe.write_text('#!/bin/bash\n'+body);exe.chmod(0o700)
        ext=app/'Contents/PlugIns/MarkdownPreview.appex';(ext/'Contents/MacOS').mkdir(parents=True)
        (ext/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString':'1.44.761','CFBundleVersion':'761'}))
        (ext/'Contents/MacOS/MarkdownPreview').write_text('fixture');(ext/'Contents/MacOS/MarkdownPreview').chmod(0o700)
        return app
    def command(self,p,app,duration='1'):
        return ['bash',str(TOOL),'--no-ui','--duration',duration,'--app',str(app),'--output',str(p)]
    def check_zip(self,p):
        folders=list(p.glob('flux-quicklook-session.*'));self.assertEqual(len(folders),1);folder=folders[0]
        self.assertEqual(folder.stat().st_mode & 0o777,0o700)
        with zipfile.ZipFile(folder/'shareable.zip') as z:
            payload=''.join(z.read(n).decode() for n in z.namelist() if not n.endswith('/'))
            for private in ['SECRET','/Users/',str(p),'raw/stream.stderr']:
                self.assertNotIn(private,payload)
            self.assertFalse(any('/raw/' in n for n in z.namelist()))
        return folder,json.loads((folder/'shareable/report.json').read_text())
    def test_safe_archive_and_failed_baseline(self):
        with tempfile.TemporaryDirectory(prefix='SECRET-') as d:
            p=Path(d);a=self.app(p,'echo "SECRET /Users/private/file.md"; exit 7\n')
            r=subprocess.run(self.command(p,a),capture_output=True,text=True,timeout=15);self.assertEqual(r.returncode,0,r.stderr)
            folder,report=self.check_zip(p);self.assertEqual(report['finder']['status'],'unconfirmed')
            self.assertIn('baseline exit=7',(folder/'shareable/collection-health.txt').read_text())
    def test_interrupt_keeps_partial_report(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);a=self.app(p,'echo "- installedCopyEnabled: false"\n')
            proc=subprocess.Popen(self.command(p,a,'60'),stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,start_new_session=True)
            try:
                deadline=time.time()+10
                while not any('installedCopyEnabled' in f.read_text() for f in p.glob('flux-quicklook-session.*/raw/baseline.txt')) and time.time()<deadline:time.sleep(.05)
                proc.send_signal(signal.SIGINT);out,err=proc.communicate(timeout=10)
                self.assertEqual(proc.returncode,130,out+err)
                folder,report=self.check_zip(p);self.assertEqual(report['finder']['status'],'unconfirmed')
                self.assertEqual(report['baseline']['installedCopyEnabled'],'false')
                self.assertIn('stop=interrupted',(folder/'shareable/collection-health.txt').read_text())
            finally:
                if proc.poll() is None:os.killpg(proc.pid,signal.SIGKILL);proc.wait()
    def test_hanging_command_is_bounded(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);a=self.app(p,'sleep 60\n');start=time.time()
            r=subprocess.run(self.command(p,a),capture_output=True,text=True,timeout=18)
            self.assertEqual(r.returncode,0,r.stderr);self.assertLess(time.time()-start,15)
            folder,report=self.check_zip(p);self.assertIn('timeout=yes',(folder/'shareable/collection-health.txt').read_text())
    def test_invalid_duration_does_not_start_session(self):
        r=subprocess.run(['bash',str(TOOL),'--duration','9999'],capture_output=True,timeout=3);self.assertEqual(r.returncode,2)

if __name__=='__main__':unittest.main()
