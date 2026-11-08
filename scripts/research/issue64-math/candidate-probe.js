for(let i=0;i<200&&!window.MathJax?.startup?.promise;i++) await new Promise(r=>setTimeout(r,100));
await MathJax.startup.promise;
const cases=JSON.parse(source),root=document.getElementById('root');
const errors=[];
async function render(cases) {
  MathJax.typesetClear([root]);
  MathJax.texReset();
  root.replaceChildren();
  for(const item of cases) {
    const node=document.createElement('section'); node.id=item.id;
    if(item.kind==='mathml') node.innerHTML=item.tex;
    else node.textContent=(item.display?'\\[':'\\(')+item.tex+(item.display?'\\]':'\\)');
    root.append(node);
  }
  const start=performance.now();
  await MathJax.typesetPromise([root]);
  return {elapsedMs:performance.now()-start,labels:MathJax.startup.document.inputJax[0].parseOptions.tags.allLabels,items:cases.map(c=>{
    const node=document.getElementById(c.id),box=node.getBoundingClientRect();
    return {id:c.id,expect:c.expect,svgCount:node.querySelectorAll('mjx-container > svg').length,
    errorCount:node.querySelectorAll('[data-mml-node="merror"]').length,
    errorText:[...node.querySelectorAll('[data-mml-node="merror"]')].map(n=>n.textContent),
    refs:[...node.querySelectorAll('a')].map(n=>({mathJaxTargetExists:!!document.getElementById(decodeURIComponent((n.getAttribute('data-mjx-href')||'').replace(/^#/,''))),attrs:Object.fromEntries([...n.attributes].map(a=>[a.name,a.value])),href:n.getAttribute('href')||n.getAttribute('xlink:href'),text:n.textContent,nativeHrefTargetExists:!!document.getElementById(decodeURIComponent((n.getAttribute('href')||n.getAttribute('xlink:href')||'').replace(/^#/,'')))})),
    width:box.width,height:box.height,visibleText:[...node.querySelectorAll('text')].map(n=>n.textContent)}
  })};
}
const full=await render(cases);
const edge=await render([
{id:'forward',tex:'\\eqref{eq:forward}',display:false},
{id:'definition',tex:'y=x+1\\tag{A}\\label{eq:forward}',display:true},
{id:'duplicate',tex:'z=x+2\\tag{B}\\label{eq:forward}',display:true},
{id:'missing',tex:'\\eqref{eq:missing}',display:false}]);
const repeat=await render(cases);
return {version:MathJax.version,full,edge,repeat,resources:performance.getEntriesByType('resource').map(r=>r.name)};
