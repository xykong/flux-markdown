const input = JSON.parse(source);
const assert = (ok, message) => { if (!ok) throw new Error(message); };
for (let i=0; i<150 && typeof window.renderMarkdown !== 'function'; i++) await new Promise(r=>setTimeout(r,20));
const root = document.getElementById('markdown-preview');
const wide = '$$\n' + Array.from({length:40},(_,i)=>'x_{'+i+'}').join('+') + '\n$$';
const results = [];
window.setFeedbackGeneration("issue64-layout");
const theme = probeTheme === 'system' ? 'light' : probeTheme;
for (const uiLanguage of ['en','ar']) {
    await window.renderMarkdown(input.valid + '\n\n' + wide, {context:'app',uiLanguage,theme,showCopyButtons:true});
    root.setAttribute('dir',uiLanguage==='ar'?'rtl':'ltr');
    await window.waitForExportReady();
    const background=getComputedStyle(root).backgroundColor;
    const rgb=background.match(/\d+/g).slice(0,3).map(Number);
    assert(theme==='dark' ? Math.max(...rgb)<100 : Math.min(...rgb)>200,'Native appearance and mathematical document colors disagree');
    const formulas = [...root.querySelectorAll('.flux-math-source')];
    assert(formulas.length===13 && root.querySelectorAll('mjx-container').length===13 && !root.querySelector('.math-error'), 'Mathematical layout lost output');
    assert(formulas.every(node=>getComputedStyle(node).direction==='ltr'), 'Math inherited RTL ordering');
    assert(document.documentElement.scrollWidth <= window.innerWidth+1, 'Mathematics causes whole-page horizontal overflow: '+JSON.stringify({width:innerWidth,scroll:document.documentElement.scrollWidth,uiLanguage,theme,zoom:probeZoom}));
    const last=formulas[formulas.length-1];
    const scrolling=[last,...last.querySelectorAll('mjx-container')].filter(node=>node.scrollWidth>node.clientWidth+1 && ['auto','scroll'].includes(getComputedStyle(node).overflowX));
    assert(scrolling.length>0,'Wide formula has no local scrolling surface');
    const link=root.querySelector('a.math-reference-link');
    assert(link && link.getAttribute('aria-label')==='(1)' && document.getElementById(decodeURIComponent(link.getAttribute('href').slice(1))), 'Numbered reference lost target');
    for(const formula of formulas) {
        const svg=formula.querySelector('svg');
        const rect=svg.getBoundingClientRect();
        assert(rect.width>0 && rect.height>0,'Invisible mathematical output');
        assert(getComputedStyle(svg).color===getComputedStyle(svg.closest('a') || root).color,'Formula color does not follow document appearance');
    }
    const firstWidth=formulas[0].querySelector('svg').getBoundingClientRect().width;
    const buttons=[...root.querySelectorAll('.block-copy-tools > button')];
    assert(buttons.length===13,'Mathematical copy controls missing');
    for(const button of buttons){button.focus();const rect=button.getBoundingClientRect();assert(rect.width>=20 && rect.left>=-1 && rect.right<=innerWidth+1,'Copy action escaped the viewport');}
    results.push({width:innerWidth,uiLanguage,theme,zoom:probeZoom,formulas:13,localScroll:true,referenceValid:true,copyControls:buttons.length,firstFormulaWidth:firstWidth,documentDirection:root.dir});
}
return {cases:results};
