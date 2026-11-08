await MathJax.startup.promise;
const startupMs=performance.now();
const cases=JSON.parse(source),root=document.getElementById('root'),engine=MathJax.config.startup.output;
async function render(items) {
  MathJax.typesetClear([root]); MathJax.texReset(); root.replaceChildren();
  for(const item of items){const el=document.createElement('section');el.id=item.id;if(item.kind==='mathml')el.innerHTML=item.tex;else el.textContent=(item.display?'\\[':'\\(')+item.tex+(item.display?'\\]':'\\)');root.append(el);}
  const start=performance.now();await MathJax.typesetPromise([root]); for(let pass=0;pass<6;pass++){root.getBoundingClientRect();await document.fonts.ready;root.getBoundingClientRect();if(![...document.fonts].some(f=>f.status==='loading'))break;}
  if([...document.fonts].some(f=>f.status==='loading'))throw new Error('Font loading did not settle');
  const elapsed=performance.now()-start;
  if(root.querySelectorAll('mjx-container').length!==items.length)throw new Error('Mathematical items were lost during benchmarking');
  const errors=root.querySelectorAll('[data-mml-node="merror"],mjx-merror').length;
  if(errors!==items.filter(item=>item.expect==='error').length)throw new Error('Unexpected math error count during benchmarking');
  return elapsed;
}
const firstMs=await render(cases);
const sample={domBytes:new TextEncoder().encode(root.innerHTML).length,assistiveCount:root.querySelectorAll('mjx-assistive-mml math').length,mathCount:root.querySelectorAll('mjx-container').length,errors:root.querySelectorAll('[data-mml-node="merror"],mjx-merror').length,fontStatus:[...document.fonts].map(f=>({family:f.family,status:f.status})),glyphUses:root.querySelectorAll('use').length,refs:[...root.querySelectorAll('a[data-mjx-href],a[href]')].map(a=>Object.fromEntries([...a.attributes].map(v=>[v.name,v.value])))};
const measurements={};
if(!location.search.includes('cold')) {
 for(const size of [13,100,1000]) {
  const items=size===13?cases:Array.from({length:size},(_,i)=>({id:'stress-'+i,tex:'\\frac{x_'+i+'^2+1}{\\sqrt{1+x_'+i+'}}',display:true}));
  for(let i=0;i<5;i++) await render(items);
  const samples=[];for(let i=0;i<30;i++)samples.push(await render(items));
  measurements[size]={samplesMs:samples,domBytes:new TextEncoder().encode(root.innerHTML).length};
 }
}
return {engine,version:MathJax.version,startupMs,firstMs,sample,measurements,workerEnabled:MathJax.startup.document.options.enableSpeech,assistiveEnabled:MathJax.startup.document.options.enableAssistiveMml};
