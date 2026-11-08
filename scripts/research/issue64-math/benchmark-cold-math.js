for(let i=0;i<100&&typeof window.renderMarkdown!=='function';i++)await new Promise(r=>setTimeout(r,20));
const started=performance.now();await window.renderMarkdown(source,{context:'quicklook',showCopyButtons:false,showLineNumbers:false});await window.waitForExportReady();
return {elapsedMs:performance.now()-started,math:document.querySelectorAll('mjx-container').length,errors:document.querySelectorAll('.math-error').length};
