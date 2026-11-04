for(let i=0;i<100&&typeof window.renderMarkdown!=='function';i++)await new Promise(r=>setTimeout(r,20));
const root=document.getElementById('markdown-preview');const results={};
for(const count of [100,1000]) {
 const text=Array.from({length:count},(_,i)=>'\\[\\frac{x_'+i+'^2+1}{\\sqrt{1+x_'+i+'}}\\]').join('\n\n');
 const samples=[];
 for(let i=0;i<35;i++){
  const start=performance.now();await window.renderMarkdown(text,{context:'quicklook',showCopyButtons:false,showLineNumbers:false});await window.waitForExportReady();
  const elapsed=performance.now()-start;
  if(root.querySelectorAll('mjx-container').length!==count||root.querySelector('.math-error'))throw new Error('Incorrect benchmark output');
  if(i>=5)samples.push(elapsed);
 }
 results[count]={samples,domBytes:new TextEncoder().encode(root.innerHTML).length};
}
return results;
