for(let i=0;i<150&&typeof window.renderMarkdown!=='function';i++)await new Promise(r=>setTimeout(r,20));
const results=[];
for(const context of ['app','quicklook','finder']) {
 const spacer=Array(35).fill('Spacer paragraph.').join('\n\n');
 await window.renderMarkdown(String.raw`\(\eqref{target}\)`+'\n\n'+spacer+'\n\n'+String.raw`\[a^2+b^2=c^2\tag{1}\label{target}\]`+'\n\n'+spacer,{context,showCopyButtons:false});
 const link=document.querySelector('a.math-reference-link');
 const target=document.getElementById(decodeURIComponent(link.hash.slice(1)));
 const formula=target.closest('.flux-math-source');
 link.click();
 let stable=0,previous=Infinity;
 const until=performance.now()+3000;
 while(stable<5&&performance.now()<until){await new Promise(r=>setTimeout(r,30));const top=formula.getBoundingClientRect().top;stable=Math.abs(previous-top)<.5?stable+1:0;previous=top;}
 const rect=formula.getBoundingClientRect();
 const controls=document.getElementById('reading-controls');
 const clearance=controls&&getComputedStyle(controls).display!=='none'?controls.getBoundingClientRect().bottom:0;
 if(rect.top<clearance || rect.bottom>innerHeight)throw new Error(JSON.stringify({context,top:rect.top,bottom:rect.bottom,clearance,height:innerHeight}));
 results.push({context,top:rect.top,bottom:rect.bottom,toolbarBottom:clearance,viewportHeight:innerHeight});
}
return {cases:results};
