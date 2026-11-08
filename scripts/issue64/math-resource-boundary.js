const assert=(ok,message)=>{if(!ok)throw new Error(message);};
const resourceURL=JSON.parse(source).mathResourceURL || 'issue64-forbidden-math-glyph.svg';
for(let i=0;i<150&&typeof window.renderMarkdown!=='function';i++)await new Promise(r=>setTimeout(r,20));
window.setFeedbackGeneration('math-resource-boundary');
const cases=[];
for(const body of [
    '<mglyph src="issue64-forbidden-math-glyph.svg" width="10px" height="10px"/>',
    '<mtext><svg xmlns="http://www.w3.org/2000/svg"><image href="issue64-forbidden-math-glyph.svg" width="10" height="10"/></svg></mtext>',
    '<mtext><img src="issue64-forbidden-math-glyph.svg" alt="glyph"/></mtext>',
]) {
    const markup=body.split('issue64-forbidden-math-glyph.svg').join(resourceURL);
    await window.renderMarkdown('<math xmlns="http://www.w3.org/1998/Math/MathML">'+markup+'</math>\n\n$x=1$\n\n# After',{context:'app',uiLanguage:'en'});
    const root=document.getElementById('markdown-preview');
    await new Promise(resolve=>setTimeout(resolve,100));
    assert(root.querySelectorAll('.math-error').length===1,'Resource-bearing MathML appeared successful');
    assert(!root.querySelector('mglyph,svg image,img') && root.querySelectorAll('mjx-container').length===1,'Resource node survived or following formula failed');
    assert(root.textContent.includes('issue64-forbidden-math-glyph.svg') && root.textContent.includes('After'),'Original source or following content lost');
    assert(root.querySelector('.math-resource-unsupported') && root.querySelector('.error-feedback-controls')?.textContent.includes('image resource'),'Mathematical image error lacks specific recovery guidance');
    let rejected=false;try{await window.waitForExportReady();}catch{rejected=true;}
    assert(rejected,'Incomplete mathematics allowed export');
    cases.push({sourcePreserved:true,followingFormulaRendered:true,exportRejected:true});
}
await window.renderMarkdown('$y=2$',{context:'app',uiLanguage:'en'});await window.waitForExportReady();
assert(!document.querySelector('.math-error'),'Next document did not recover');
return {cases,recovered:true};
