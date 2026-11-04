jest.mock('mermaid',()=>({initialize:jest.fn(),render:jest.fn()}));
import '../src/index';

beforeEach(()=>{document.body.innerHTML='<div id="markdown-preview"></div>';});

test('formula references expose a named keyboard link outside hidden visual output',async()=>{
    await window.renderMarkdown(String.raw`\(\eqref{x}\)`+'\n\n'+String.raw`\[x=1\tag{A}\label{x}\]`,{showCopyButtons:false});
    const links=Array.from(document.querySelectorAll<HTMLElement>('#markdown-preview a[href^="#"]'));
    const accessible=links.filter(link=>!link.closest('[aria-hidden="true"]') && link.getAttribute('tabindex')!=='-1');
    expect(accessible.length).toBeGreaterThan(0);
    expect(accessible.some(link=>(link.getAttribute('aria-label')||link.textContent||'').includes('A'))).toBe(true);
    const exported=new DOMParser().parseFromString(window.exportHTML(),'text/html');
    expect(Array.from(exported.querySelectorAll('a[href^="#"]')).some(link=>!link.closest('[aria-hidden="true"]'))).toBe(true);
});

test('a formula inside an ordinary Markdown link does not create nested anchors',async()=>{
    await window.renderMarkdown(String.raw`[See $\eqref{x}$](https://example.com)`+'\n\n'+String.raw`\[x=1\tag{A}\label{x}\]`,{showCopyButtons:false});
    const root=document.getElementById('markdown-preview')!;
    expect(root.querySelector('a[href="https://example.com"]')).not.toBeNull();
    expect(Array.from(root.querySelectorAll('a')).some(link=>link.parentElement?.closest('a'))).toBe(false);
    const reference=root.querySelector('a[href^="#"]');
    expect(reference).not.toBeNull();
    const href=reference!.getAttribute('href')!;
    expect(document.getElementById(decodeURIComponent(href.slice(1)))).not.toBeNull();
});
test('keeps the external destination when the enclosing link contains only a formula',async()=>{
    await window.renderMarkdown(String.raw`[$\eqref{x}$](https://example.com)`+'\n\n'+String.raw`\[x=1\tag{A}\label{x}\]`,{showCopyButtons:false});
    expect(document.querySelector('#markdown-preview a[href="https://example.com"]')).not.toBeNull();
    expect(document.querySelector('#markdown-preview a[href^="#"]')).not.toBeNull();
});
test('complex formulas expose each distinct reference outside the hidden SVG',async()=>{
    await window.renderMarkdown(String.raw`\(\eqref{x}+\eqref{y}\)`+'\n\n'+String.raw`\[x=1\tag{A}\label{x}\]`+'\n\n'+String.raw`\[y=2\tag{B}\label{y}\]`,{showCopyButtons:false});
    const links=Array.from(document.querySelectorAll('#markdown-preview .math-reference-links a'));
    expect(links.map(link=>link.textContent)).toEqual(['(A)','(B)']);
    expect(links.every(link=>!link.closest('[aria-hidden="true"]'))).toBe(true);
});
