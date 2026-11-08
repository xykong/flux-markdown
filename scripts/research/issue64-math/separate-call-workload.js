for(let i=0;i<100&&typeof window.renderMarkdown!=='function';i++)await new Promise(r=>setTimeout(r,20));
if(invocation===0||invocation>=31){await window.renderMarkdown('# Plain',{showCopyButtons:false});return {math:document.querySelectorAll('mjx-container').length};}
const text=Array.from({length:1000},(_,i)=>'\\[\\frac{x_'+i+'^2+1}{\\sqrt{1+x_'+i+'}}\\]').join('\n\n');
await window.renderMarkdown(text,{context:'quicklook',showCopyButtons:false,showLineNumbers:false});await window.waitForExportReady();
const count=document.querySelectorAll('mjx-container').length;if(count!==1000)throw new Error('Lost math');return {count};
