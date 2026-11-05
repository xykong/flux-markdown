"""One item per row: independent reference, actual App output, reviewer feedback."""
from pathlib import Path
import base64
import hashlib
import html
import json
import fitz

root = Path(__file__).resolve().parents[2]
out = root / 'output/pdf/issue64-review'
items = out / 'items'; items.mkdir(exist_ok=True)
cases = json.loads((root / 'docs/research/issue64/math-cases.json').read_text())
reference_path = root / 'output/pdf/issue64-independent-reference.pdf'
reference = fitz.open(reference_path)
candidate = fitz.open(out / 'candidate.pdf')
export_evidence = json.loads((out / 'app-export-evidence.json').read_text())
assert export_evidence['invalidExport']['exitCode'] != 0 and not export_evidence['invalidExport']['outputCreated']
assert export_evidence['candidatePDFSha256'] == hashlib.sha256((out / 'candidate.pdf').read_bytes()).hexdigest()
# PDF-point viewports, checked against the original complete pages. No formula is re-typeset here.
reference_boxes = {
'M01': (64,157,114,176), 'M02': (64,196,99,214), 'M03': (64,230,114,251),
'M04': (64,267,129,289), 'M05': (248,309,346,350), 'M06': (252,380,342,423),
'M07': (185,451,410,548), 'M08': (201,571,394,620), 'M09': (265,650,532,678),
'M10': (64,699,84,718), 'M11': (267,744,327,780)}
candidate_boxes = {
'M01': (0,(169.8,305,242.2,332)), 'M02': (0,(357,307,409,331)), 'M03': (0,(442.8,303,514,332)),
'M04': (0,(186,347,285.5,373)), 'M05': (0,(218,431,378,484)), 'M06': (0,(222,540,372,599)),
'M07': (1,(113,118,485,271)), 'M08': (1,(134,325,460,381)), 'M09': (1,(244,432,540,465)),
'M10': (1,(170.5,476,193.2,503)), 'M11': (1,(247,558,348,605)), 'M13': (0,(53,200,163,229))}
names = ['能量公式','不等式','根号与上标','勾股公式','积分','求和','三行对齐与分式','矩阵与分段函数','公式编号','编号引用','数学代码块','故意错误的公式','MathML 公式']
hints = ['核对 c 的平方。','核对大于号方向。','根号应覆盖 x²。','三个平方均为上标。','核对上下限、负指数和根号。','核对上下限与分母 2。','应有三行；分式和“条件概率”完整。','矩阵两行两列，分段函数两行。','右侧编号应为 (1)。','显示为 (1)，并对应上一条公式。','E 为粗体，ε 的下标为 0。','故意写错的命令不应成功导出。','三个变量的指数均为 2。']
def uri(path, mime):
    return 'data:' + mime + ';base64,' + base64.b64encode(path.read_bytes()).decode()
def crop(document, page_number, box, filename, scale):
    path=items/filename
    document[page_number].get_pixmap(matrix=fitz.Matrix(3,3),clip=fitz.Rect(box),alpha=False).save(path)
    return f'<button type="button" class="formula-image" aria-label="放大公式"><img alt="公式图像" style="width:{(box[2]-box[0])*scale}px" src="{uri(path,"image/png")}"></button>'
rows=[]
for index,case in enumerate(cases):
    ident=case['id']
    if ident in reference_boxes:
        expected=crop(reference,0,reference_boxes[ident],ident+'-reference.png',2)
    elif ident=='M13':
        expected='<div class="native-math">'+case['tex']+'</div>'
    else:
        expected='<div class="behavior"><strong>应当报错，拒绝导出</strong><p>不能把无效命令显示成正常公式。</p></div>'
    if ident in candidate_boxes:
        p,box=candidate_boxes[ident];actual=crop(candidate,p,box,ident+'-app.png',1.35)
    else:
        actual='<div class="behavior actual"><strong>App 已拒绝导出</strong><p>未生成 PDF 文件。</p><small>来自实际 App 导出验证记录，不是错误界面截图。</small></div>'
    options=''.join(f'<label class="choice"><input type="radio" name="{ident}" value="{label}"><span>{label}</span></label>' for label in ['一致','不一致','内容一致，但排版有问题','无法判断'])
    rows.append(f'''<tr data-case="{ident}"><td><div class="item-label"><b>{ident}</b> {names[index]}</div><div class="visual">{expected}</div><p class="hint">{hints[index]}</p></td><td><div class="app-label">{names[index]}</div><div class="visual">{actual}</div></td><td class="feedback"><fieldset><legend class="sr-only">{ident} 的反馈</legend>{options}</fieldset><textarea aria-label="{ident} 补充说明" placeholder="补充说明（可不填）" rows="2"></textarea><details><summary>查看原始输入</summary><pre>{html.escape(case['tex'])}</pre></details></td></tr>''')
page=r'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Issue 64 · 逐项公式对比</title>
<style>*{box-sizing:border-box}body{margin:0;background:#f4f6fa;color:#17212e;font:16px/1.55 system-ui,sans-serif}main{max-width:1680px;margin:auto;padding:24px}h1{font-size:28px;margin:0 0 8px}.intro{margin:0 0 18px;color:#4b586a}.table-wrap{overflow:visible;border:1px solid #d8e0ea;border-radius:12px;background:white}table{border-collapse:collapse;width:100%;min-width:1050px;table-layout:fixed}col.compare{width:37%}col.feedback-col{width:26%}th{background:#eaf0f8;text-align:left;padding:16px 20px;font-size:18px;position:sticky;top:0;z-index:1}tr{scroll-margin-top:72px}td{vertical-align:top;padding:20px;border-top:1px solid #dce3ed}td+td{border-left:1px solid #e5eaf1}.item-label,.app-label{font-size:15px;margin-bottom:16px}.item-label b{color:#1c5cac;margin-right:8px}.app-label{color:#66758a}.visual{min-height:90px;display:flex;align-items:center;justify-content:center;padding:10px 0}.formula-image{border:0;padding:0;background:white;cursor:zoom-in;max-width:100%}.formula-image img{display:block;max-width:100%;height:auto}.hint{font-size:14px;color:#637087;margin:12px 0 0}.native-math{font-size:25px}.behavior{width:100%;background:#f7f8fa;padding:16px;border-radius:8px;font-size:15px}.behavior p{margin:6px 0}.behavior small{color:#66758a}.actual{background:#fff5e4}fieldset{border:0;margin:0;padding:0}.choice{display:flex;align-items:flex-start;gap:8px;padding:6px 0;cursor:pointer;font-size:15px}.choice input{margin-top:5px;accent-color:#155dcc}.feedback textarea{width:100%;margin-top:8px;border:1px solid #c8d2df;border-radius:6px;padding:8px;font:14px/1.5 system-ui;resize:vertical}details{font-size:13px;color:#69768a;margin-top:10px}summary{cursor:pointer}pre{white-space:pre-wrap;overflow-wrap:anywhere;font-size:12px}.sr-only{position:absolute;clip:rect(0,0,0,0);width:1px;height:1px;overflow:hidden}.footer{margin-top:20px;padding:20px;background:white;border:1px solid #dce3ed;border-radius:12px}.footer p{margin:0 0 12px}.primary{background:#155dcc;color:white;border:0;border-radius:7px;padding:10px 18px;font:16px system-ui;cursor:pointer}.progress{font-size:14px;color:#526075;margin-left:12px}#report{display:block;width:100%;min-height:180px;margin-top:14px;padding:12px;font:14px/1.6 system-ui;border:1px solid #c8d2df;border-radius:6px}#report[hidden]{display:none}.sources a{display:inline-block;margin:6px 20px 6px 0;color:#155dcc}dialog{max-width:94vw;max-height:92vh;border:1px solid #9ca8b7;border-radius:10px;padding:20px}dialog::backdrop{background:#0008}dialog img{display:block;max-width:85vw;max-height:75vh;width:auto;height:auto}dialog button{float:right;margin-bottom:12px;padding:6px 12px}tr.done{background:#fbfdff}@media(max-width:1100px){.table-wrap{overflow-x:auto}main{padding:12px}h1{font-size:24px}}@media print{.feedback,.footer{display:none}table{min-width:0}th,td{position:static}}</style>
<main><h1>逐项公式对比</h1><p class="intro">每行只看一项：对比左、中两列，在右侧选择。字体和字号不同可以接受；重点看公式内容、结构和编号。</p>
<div class="table-wrap"><table><colgroup><col class="compare"><col class="compare"><col class="feedback-col"></colgroup><thead><tr><th>① 正确参照</th><th>② App 实际输出</th><th>③ 你的判断</th></tr></thead><tbody>__ROWS__</tbody></table></div>
<section class="footer"><p>选完后点击下面的按钮，把生成的文字复制回聊天。不确定的项目选“无法判断”即可。</p><button class="primary" id="generate">生成反馈摘要</button><span class="progress" id="progress" aria-live="polite">已判断 0 / 13 项</span><textarea id="report" hidden readonly aria-label="复制回聊天的反馈摘要"></textarea>
<details class="sources"><summary>参照来源与完整 PDF（无需先看）</summary><p>左侧 M01–M11 截自独立 TeX 编译参照，M13 使用浏览器原生 MathML；中间有效公式截自候选 App 的实际 PDF。M12 比较错误导出行为。图片仅裁取对应区域，没有重新绘制公式。此页不自动上传反馈。</p>__LINKS__<p>候选实现：868237a。点击公式图片可放大。编号跳转可在候选 PDF 中点击 (1) 检查。</p></details></section></main>
<dialog id="zoom"><button type="button" id="closeZoom">关闭</button><img id="zoomImage" alt="放大的公式"></dialog>
<script>const rows=[...document.querySelectorAll('tr[data-case]')],dialog=document.getElementById('zoom');function update(){const n=rows.filter(r=>r.querySelector('input:checked')).length;document.getElementById('progress').textContent='已判断 '+n+' / 13 项';rows.forEach(r=>r.classList.toggle('done',!!r.querySelector('input:checked')));}document.querySelectorAll('input[type=radio]').forEach(i=>i.onchange=update);document.querySelectorAll('.formula-image').forEach(b=>b.onclick=()=>{document.getElementById('zoomImage').src=b.querySelector('img').src;dialog.showModal();});document.getElementById('closeZoom').onclick=()=>dialog.close();document.getElementById('generate').onclick=()=>{const lines=rows.map(r=>{const selected=r.querySelector('input:checked');const note=r.querySelector('textarea').value.trim();return r.dataset.case+'：'+(selected?selected.value:'未核对')+(note?'；'+note:'');});const report=document.getElementById('report');report.value='Issue 64 公式复核\n'+lines.join('\n');report.hidden=false;report.focus();report.select();};</script></html>'''
links=[]
for path,label,name in [(reference_path,'独立参照 PDF','reference.pdf'),(out/'candidate.pdf','App 输出 PDF','candidate.pdf'),(out/'numbering-contracts.pdf','补充编号案例 PDF','numbering-contracts.pdf')]:
    links.append(f'<a download="{name}" href="{uri(path,"application/pdf")}">{label}</a>')
page=page.replace('__ROWS__',''.join(rows)).replace('__LINKS__',''.join(links))
(out/'index.html').write_text(page)
manifest={'layout':'one item per row; reference / actual output / feedback','candidateCommit':'868237a','reviewerSignOff':False,'originalCases':len(cases),'referencePDF':str(reference_path.relative_to(root)),'referenceCropBoxes':reference_boxes,'candidateCropBoxes':candidate_boxes,'files':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [reference_path,out/'candidate.pdf',out/'app-export-evidence.json',out/'index.html',*sorted(items.glob('*.png'))]}}
receipt_path = out / 'human-review.json'
if receipt_path.exists():
    receipt = json.loads(receipt_path.read_text())
    if receipt.get('reviewedPageSha256') == hashlib.sha256((out / 'index.html').read_bytes()).hexdigest():
        manifest['reviewerSignOff'] = True
        manifest['reviewScope'] = receipt['scope']
        manifest['reviewReceipt'] = str(receipt_path.relative_to(root))
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(out/'index.html')
