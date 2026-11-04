import subprocess,time,json,pathlib,sys
root=pathlib.Path(__file__).resolve().parents[3];out=pathlib.Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
bundle=pathlib.Path(sys.argv[3]) if len(sys.argv)>3 else root/'web-renderer/dist'
workload=pathlib.Path(sys.argv[4]) if len(sys.argv)>4 else root/'scripts/research/issue64-math/memory-cycle.js'
def processes():
 rows=subprocess.check_output(['ps','-eo','pid=,rss=,command='],text=True).splitlines();return {int(r.split(None,2)[0]):{'rssKiB':int(r.split(None,2)[1]),'command':r.split(None,2)[2]} for r in rows if len(r.split(None,2))==3}
before=set(processes());samples=[]
with (out/'stdout.json').open('w') as stdout,(out/'stderr.log').open('w') as stderr:
 p=subprocess.Popen([sys.argv[1],'flux-renderer://bundle/index.html',str(bundle),str(workload),str(root/'Tests/fixtures/issues/64/markdown-preview-test.md'),'175'],stdout=stdout,stderr=stderr)
 start=time.monotonic();webpid=None
 while p.poll() is None:
  procs=processes()
  candidates=[pid for pid,data in procs.items() if pid not in before and 'com.apple.WebKit.WebContent.xpc/Contents/MacOS/com.apple.WebKit.WebContent' in data['command']]
  if webpid is None and len(candidates)==1:webpid=candidates[0]
  lines=(out/'stderr.log').read_text().splitlines();phases=[line for line in lines if 'MEMPHASE' in line]
  if webpid is not None:samples.append({'seconds':round(time.monotonic()-start,2),'rssKiB':procs[webpid]['rssKiB'] if webpid in procs else 0,'processExists':webpid in procs,'phase':phases[-1] if phases else 'startup'})
  time.sleep(1)
 print('exit',p.returncode,'webpid',webpid)
 (out/'samples.json').write_text(json.dumps({'exit':p.returncode,'webpid':webpid,'bundle':str(bundle),'workload':str(workload),'samples':samples},indent=2))
