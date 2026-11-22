const deadline=performance.now()+15000;
while(typeof window.renderMarkdown!=='function' && performance.now()<deadline)await new Promise(r=>setTimeout(r,30));
await window.renderMarkdown(source,{context:'app',showCopyButtons:true,theme:'light',fontSize:18,uiLanguage:'en'});
await window.waitForExportReady();
await new Promise(resolve=>setTimeout(resolve,300));
return Array.from(document.querySelectorAll('div.flux-math-source')).map(math=>({formulaY:math.querySelector('mjx-container').getBoundingClientRect().top,hostY:math.parentElement.getBoundingClientRect().top}));
