"""Verify mathematical image suppression against a functioning local image server."""
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import threading, subprocess, json, sys
root=Path(__file__).resolve().parents[2]
if len(sys.argv)!=4:raise SystemExit('Usage: verify-math-resource-http.py PROBE BUNDLE NEW_OUTPUT_DIRECTORY')
probe=Path(sys.argv[1]);bundle=Path(sys.argv[2]);out=Path(sys.argv[3]);out.mkdir(parents=True,exist_ok=False);requests=[]
class Handler(BaseHTTPRequestHandler):
 def do_GET(self):
  requests.append(self.path)
  body=b'<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"><rect width="1" height="1"/></svg>'
  self.send_response(200);self.send_header('Content-Type','image/svg+xml');self.send_header('Content-Length',str(len(body)));self.send_header('Cache-Control','no-store');self.end_headers();self.wfile.write(body)
 def log_message(self,*args):pass
server=ThreadingHTTPServer(('127.0.0.1',0),Handler);thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
try:
 origin=f'http://127.0.0.1:{server.server_port}'
 control=out/'control.js';control.write_text("const input=JSON.parse(source); for(let i=0;i<150&&typeof window.renderMarkdown!=='function';i++)await new Promise(r=>setTimeout(r,20)); await window.renderMarkdown('![control]('+input.url+')',{context:'app'}); await window.waitForExportReady(); if(document.querySelector('#markdown-preview img').naturalWidth!==1)throw new Error('Control image did not load'); return {loaded:true};")
 for name,script,data in [('control',control,{'url':origin+'/control.svg'}),('math',root/'scripts/issue64/math-resource-boundary.js',{'mathResourceURL':origin+'/issue64-forbidden-math-glyph.svg'})]:
  (out/(name+'.json')).write_text(json.dumps(data))
  result=subprocess.run([str(probe),'flux-renderer://bundle/index.html',str(bundle),str(script),str(out/(name+'.json')),'45'],capture_output=True,text=True,timeout=50)
  (out/(name+'-result.json')).write_text(result.stdout);(out/(name+'.log')).write_text(result.stderr)
  assert result.returncode==0,(name,str(out))
 assert '/control.svg' in requests,requests
 assert not any('forbidden-math-glyph' in path for path in requests),requests
 print('PASS HTTP control loaded; zero mathematical image requests:',out)
 (out/'requests.json').write_text(json.dumps(requests))
 (out/'report.json').write_text(json.dumps({'ordinaryImageLoaded':True,'ordinaryImageRequests':requests.count('/control.svg'),'mathematicalImageRequests':sum('forbidden-math-glyph' in path for path in requests),'mathCases':json.loads((out/'math-result.json').read_text()),'transport':'HTTP on 127.0.0.1 only'},indent=2)+'\n')
finally:
 server.shutdown();server.server_close();thread.join(timeout=2)
