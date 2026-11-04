for(let i=0;i<100&&typeof window.renderMarkdown!=='function';i++)await new Promise(r=>setTimeout(r,20));
const plainText=Array.from({length:100},(_,i)=>'## Section '+i+'\n\nA paragraph with **bold**, `code`, and [a link](https://example.com).\n\n- First\n- Second').join('\n\n');
const samples=[];for(let i=0;i<35;i++) {const t=performance.now();await window.renderMarkdown(plainText,{context:'quicklook',showCopyButtons:false,showLineNumbers:false});await window.waitForExportReady();const elapsed=performance.now()-t;if(document.querySelectorAll('#markdown-preview h2').length!==100)throw Error('Lost headings');if(i>=5)samples.push(elapsed);}
return {samples,math:document.querySelectorAll('mjx-container,.katex').length,headings:document.querySelectorAll('#markdown-preview h2').length};
