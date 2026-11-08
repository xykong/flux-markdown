import pathlib,subprocess,json,time,math
p=pathlib.Path(__file__).parent
out={'method':{'coldSamples':20,'warmup':5,'warmSamples':30,'viewport':[960,900],'fontReadiness':'force layout, await font readiness, reflow and verify no loading fonts; no throttled setTimeout','coldMeaning':'new process and nonpersistent WebKit data store; OS disk cache not flushed'},'engines':{}}
for engine in ['svg','chtml']:
    cold=[]
    for i in range(20):
        t=time.monotonic();r=subprocess.run([str(p/'probe-traced'),f'flux-renderer://bundle/{engine}.html?cold=1',str(p),str(p/'compare.js'),str(p/'cases.json'),'25'],capture_output=True,text=True,check=True,timeout=30)
        v=json.loads(r.stdout)
        assert 'JS: CSP' not in r.stderr
        assert v['sample']['assistiveCount']==13 and v['sample']['mathCount']==13 and v['sample']['errors']==1
        assert not any(f['status']=='loading' for f in v['sample']['fontStatus'])
        assets=[{'bytes':int(line.split(' ',2)[1]),'url':line.split(' ',2)[2]} for line in r.stderr.splitlines() if line.startswith('ASSET ')]
        cold.append({'startupMs':v['startupMs'],'firstMs':v['firstMs'],'processWallMs':round((time.monotonic()-t)*1000,3)})
    r=subprocess.run([str(p/'probe-traced'),f'flux-renderer://bundle/{engine}.html',str(p),str(p/'compare.js'),str(p/'cases.json'),'175'],capture_output=True,text=True,check=True,timeout=180)
    assert 'JS: CSP' not in r.stderr
    v=json.loads(r.stdout)
    out['engines'][engine]={'cold':cold,'firstRequestAssets':assets,'sample':v['sample'],'warm':v['measurements']}
    print(engine,'complete',flush=True)
(p/'design-comparison.json').write_text(json.dumps(out,indent=2)+'\n')
