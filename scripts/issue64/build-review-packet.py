"""Build the offline human review page from the frozen oracle and actual App exports."""
from pathlib import Path
import base64
import hashlib
import html
import json

root = Path(__file__).resolve().parents[2]
out = root / 'output/pdf/issue64-review'
cases = json.loads((root / 'docs/research/issue64/math-cases.json').read_text())
checks = [
'E = mc²：等号与平方位置正确。', 'x > 0：不等号方向正确。', '根号覆盖 x²，右侧为 x；结合原文 x > 0 的条件理解。',
'a² + b² = c²：三个平方均为上标。', '积分上下限为负无穷、正无穷；指数为 −x²；右侧为 √π。',
'求和下限 k = 1、上限 n；右侧为 n(n+1)/2。', 'aligned 共三行，等号对齐；分式、极限和“条件概率”均完整。',
'矩阵为两行两列 [1,2;3,4]；分段函数为 x²（x≥0）和 −x（x<0）。',
'勾股公式右侧编号为 (1)，没有重复或缺失编号。', '引用文字为 (1)，在候选 PDF 或应用中点击可定位到 M09。',
'∇·粗体 E = ρ/ε₀，下标 0 完整。',
'故意无效命令应报错、保留源码和后文，并阻止完整成功导出；因此本项不在候选 PDF 中。',
'MathML 输入显示 x²+y²=z²；三个指数都是 2。此项按原始 XML 结构核对，独立 TeX PDF 未覆盖它。'
]
def uri(path, mime):
    return 'data:' + mime + ';base64,' + base64.b64encode(path.read_bytes()).decode()
def image(name, label):
    return f'<button class="page" data-caption="{html.escape(label)}"><img alt="{html.escape(label)}" src="{uri(out/name,"image/png")}"></button>'
rows = []
for case, check in zip(cases, checks):
    ident=case['id']; source=html.escape(case['tex'])
    rows.append(f'<article class="check"><label for="{ident}"><b>{ident}</b> · 原文第 {case["line"]} 行</label><p>{check}</p><select id="{ident}" aria-label="{ident} 复核结果"><option>未核对</option><option>通过</option><option>有问题</option></select><details><summary>查看原始输入</summary><pre>{source}</pre></details></article>')
reference=root/'output/pdf/issue64-independent-reference.pdf'
page=r'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Issue 64 公式人工复核</title>
<style>body{margin:0;background:#f4f6fa;color:#17212e;font:16px/1.6 system-ui,sans-serif}main{max-width:1440px;margin:auto;padding:28px}h1{font-size:32px;margin:0}h2{margin-top:30px}p{max-width:1000px}.note{background:#fff8e3;border-left:4px solid #b77a08;padding:14px 18px}.grid{display:grid;grid-template-columns:1fr 1fr;gap:20px}.panel,.check{background:white;padding:18px;border:1px solid #dce2eb;border-radius:12px}.panel h3{margin-top:0}.page{display:block;width:100%;border:0;background:white;padding:0;cursor:zoom-in}.page img{width:100%;height:auto;display:block}.checks{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}.check p{margin:8px 0}select,button,textarea{font:inherit}select{padding:6px;max-width:100%}pre{white-space:pre-wrap;overflow-wrap:anywhere;font-size:13px}a{color:#1454c0}textarea{box-sizing:border-box;width:100%;min-height:160px;padding:12px}dialog{max-width:94vw;max-height:94vh;padding:12px;border:1px solid #8793a3;border-radius:10px}dialog img{display:block;max-width:88vw;height:auto}dialog button{position:sticky;top:0;float:right}dialog::backdrop{background:#0009}.actions{display:flex;gap:16px;flex-wrap:wrap}#generate{padding:9px 18px;background:#155dcc;color:white;border:0;border-radius:8px;margin:10px 0}@media(max-width:900px){.grid,.checks{grid-template-columns:1fr}main{padding:16px}}@media print{select,#generate,dialog{display:none}.grid{display:block}}</style>
<main><h1>Issue 64 · 公式人工复核</h1><p>请核对符号、上下标、分式、矩阵行列、编号与引用。点击任一页面图片可放大；字体、字号和分页可以不同，不要求像素相同。</p>
<div class="note">共 12 个有效数学项和 1 个故意错误项。左侧由独立 Tectonic / XeTeX + amsmath 编译，右侧来自候选 App 的实际 PDF 导出。M12 不应成功导出；M13 的 MathML 结构另行核对。当前未替你填写任何“通过”。</div>
<div class="actions">__LINKS__</div><h2>原始数学语料</h2><div class="grid"><section class="panel"><h3>独立 TeX 参照 · M01–M11</h3>__REF__</section><section class="panel"><h3>候选 App · 12 个有效项</h3><p>M13 在第一页最上方；M01–M06 在第一页，M07–M11 在第二页。</p>__CURRENT__</section></div>
<h2>逐项核对</h2><div class="checks">__CHECKS__</div>
<h2>补充：前向引用、自动编号与 tag*</h2><p>检查前向引用 (A)、后向引用 A、自动编号 (1)、align 首行 (2)、无编号次行，以及 tag* 的 B / (B)。右侧输入直接取自左侧参照的对应段落。</p><div class="grid"><section class="panel"><h3>独立 TeX 参照</h3>__REF2__</section><section class="panel"><h3>候选 App 实际导出</h3>__CONTRACT__</section></div>
<h2>反馈给我</h2><p>请勾选已核对的项目，并写出有问题的 ID 和现象。本页不上传数据；生成后把摘要发回聊天即可。未核对项不会计作通过。</p><label for="notes">补充意见（可选）</label><textarea id="notes" placeholder="例如：M08 的第二行……；补充编号案例已核对……"></textarea><button id="generate">生成复核摘要</button><textarea id="report" readonly aria-label="可复制的复核摘要"></textarea>
<p>参照来源：issue 64 原附件；实现前冻结的 acceptance-expectations.json。候选实现：868237a。此页供人工复核，不替代 VoiceOver、实际宿主或内存验收。</p></main>
<dialog id="zoom"><button id="closeZoom">关闭放大图</button><h2 id="caption"></h2><img id="zoomImage" alt=""></dialog>
<script>const dialog=document.getElementById('zoom');document.querySelectorAll('.page').forEach(button=>button.onclick=()=>{const source=button.querySelector('img');const image=document.getElementById('zoomImage');image.src=source.src;image.alt=source.alt;document.getElementById('caption').textContent=button.dataset.caption;dialog.showModal();});document.getElementById('closeZoom').onclick=()=>dialog.close();document.getElementById('generate').onclick=()=>{const lines=[...document.querySelectorAll('.check select')].map(select=>select.id+'：'+select.value);document.getElementById('report').value='Issue 64 人工复核\n'+lines.join('\n')+'\n补充：'+document.getElementById('notes').value;};</script></html>'''
links=[]
for path,label,name in [(reference,'下载独立参照 PDF','reference.pdf'),(out/'candidate.pdf','下载候选原始语料 PDF','candidate.pdf'),(out/'numbering-contracts.pdf','下载补充编号 PDF','numbering-contracts.pdf')]:
    links.append(f'<a download="{name}" href="{uri(path,"application/pdf")}">{label}</a>')
for key,value in {'__LINKS__':' '.join(links),'__REF__':image('reference-1.png','独立参照：原始语料'),'__CURRENT__':image('candidate-1.png','候选 App：第 1 页')+image('candidate-2.png','候选 App：第 2 页'),'__CHECKS__':''.join(rows),'__REF2__':image('reference-2.png','独立参照：补充编号'),'__CONTRACT__':image('contracts-1.png','候选 App：补充编号')}.items():page=page.replace(key,value)
(out/'index.html').write_text(page)
manifest={'candidateCommit':'868237a','reviewerSignOff':False,'files':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [reference,out/'candidate.pdf',out/'numbering-contracts.pdf',out/'index.html']},'originalCases':len(cases),'expectations':'docs/research/issue64/acceptance-expectations.json'}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(out/'index.html')
