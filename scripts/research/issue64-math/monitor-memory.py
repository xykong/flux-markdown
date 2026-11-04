import subprocess,time,json,pathlib,sys
root=pathlib.Path(__file__).resolve().parents[3];out=pathlib.Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
def processes():
 rows=subprocess.check_output(['ps','-eo','pid=,rss=,command='],text=True).splitlines();return {int(r.split(None,2)[0]):{'rssKiB':int(r.split(None,2)[1]),'command':r.split(None,2)[2]} for r in rows if len(r.split(None,2))==3}
before=set(processes());samples=[]
with (out/'stdout.json').open('w') as stdout,(out/'stderr.log').open('w') as stderr:
 p=subprocess.Popen([sys.argv[1],'flux-renderer://bundle/index.html',str(root/'web-renderer/dist'),str(root/'scripts/research/issue64-math/memory-cycle.js'),str(root/'Tests/fixtures/issues/64/markdown-preview-test.md'),'175'],stdout=stdout,stderr=stderr)
 start=time.monotonic();webpid=None
 while p.poll() is None:
  procs=processes()
  candidates=[pid for pid,data in procs.items() if pid not in before and 'com.apple.WebKit.WebContent.xpc/Contents/MacOS/com.apple.WebKit.WebContent' in data['command']]
  if webpid is None and len(candidates)==1:webpid=candidates[0]
  lines=(out/'stderr.log').read_text().splitlines();phases=[line for line in lines if 'MEMPHASE' in line]
  if webpid in procs:samples.append({'seconds':round(time.monotonic()-start,2),'rssKiB':procs[webpid]['rssKiB'],'phase':phases[-1] if phases else 'startup'})
  time.sleep(1)
 print('exit',p.returncode,'webpid',webpid)
 (out/'samples.json').write_text(json.dumps({'exit':p.returncode,'webpid':webpid,'samples':samples},indent=2))
