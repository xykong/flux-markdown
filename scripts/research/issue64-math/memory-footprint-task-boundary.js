const channel = new MessageChannel();
const yieldTask = () => new Promise(resolve => {channel.port1.onmessage = resolve; channel.port2.postMessage(null);});
for(let i=0;i<100&&typeof window.renderMarkdown!=='function';i++)await new Promise(r=>setTimeout(r,20));
const root=document.getElementById('markdown-preview');const report=phase=>console.warn('MEMPHASE '+phase+' '+JSON.stringify({nodes:document.querySelectorAll('*').length,math:root.querySelectorAll('mjx-container,.katex').length,stages:document.querySelectorAll('[data-math-measurement]').length}));
await window.renderMarkdown('# Baseline');report('baseline');await new Promise(r=>setTimeout(r,2000));
const text=Array.from({length:1000},(_,i)=>'$$\n\\frac{x_'+i+'^2+1}{\\sqrt{1+x_'+i+'}}\n$$').join('\n\n');
for(let cycle=0;cycle<1;cycle++) {
 for(let i=0;i<10;i++) {await window.renderMarkdown(text,{context:'quicklook',showCopyButtons:false,showLineNumbers:false});await window.waitForExportReady();if(root.querySelectorAll('mjx-container,.katex').length!==1000)throw Error('Lost math');await yieldTask();}
 report('loaded-'+cycle);await window.renderMarkdown('# Cleared',{showCopyButtons:false,showLineNumbers:false});report('cleared-'+cycle);
 await new Promise(r=>setTimeout(r,60000));report('idle-'+cycle);
}
channel.port1.close();channel.port2.close();return {done:true};
