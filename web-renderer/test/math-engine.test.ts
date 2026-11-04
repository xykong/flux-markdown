import { renderMathSources } from '../src/math-engine';
import type { MathSource } from '../src/math-syntax';
import { SVG } from '@mathjax/src/js/output/svg.js';

function source(id: string, payload: string, display = true): MathSource {
    return { id, payload, display, raw: payload, firstLine: 1, lastLine: 1 };
}
test('renders a complete document with forward reference and assistive semantics', async () => {
    const result = await renderMathSources([
        source('ref', String.raw`\eqref{eq:x}`, false),
        source('eq', String.raw`x^2\tag{A}\label{eq:x}`),
    ], 'engine-one');
    expect(result.errors).toHaveLength(0);
    const root = document.createElement('div'); root.innerHTML = result.items.map(item => item.html).join('');
    expect(root.querySelectorAll('mjx-container')).toHaveLength(2);
    expect(root.querySelectorAll('mjx-assistive-mml math')).toHaveLength(2);
    const href = root.querySelector('a')!.getAttribute('href')!;
    expect(Array.from(root.querySelectorAll('[id]')).some(node => node.id === decodeURIComponent(href.slice(1)))).toBe(true);
});
test('flags unresolved references and preserves valid following formulas', async () => {
    const result = await renderMathSources([source('bad',String.raw`\eqref{absent}`,false), source('good','x=1')], 'engine-two');
    expect(result.errors.map(error => error.sourceId)).toEqual(['bad']);
    expect(result.items.find(item => item.id === 'good')?.html).toContain('<svg');
});
test.each([
    String.raw`x=1\label{x}`,
    String.raw`x=1\tag{A}\label{x}\unknownCommand`,
])('references to unnumbered or failed declarations remain unresolved',async payload=>{
    const result=await renderMathSources([source('target',payload),source('ref',String.raw`\eqref{x}`,false)],'invalid-target');
    expect(result.errors).toContainEqual({sourceId:'ref',code:'unresolved-reference'});
    const root=document.createElement('div');root.innerHTML=result.items[1].html;
    expect(root.querySelector('a[href]')).toBeNull();
});
test('output failures preserve source and do not masquerade as successfully rendered mathematics',async()=>{
    const broken=source('broken',String.raw`\frac{x}{2}`);
    const spy=jest.spyOn(SVG.prototype,'typeset').mockImplementationOnce(()=>{throw new Error('Injected output failure');});
    try {
        const result=await renderMathSources([broken,source('good','y=1')],'output-failure');
        expect(result.errors).toContainEqual({sourceId:'broken',code:'output'});
        expect(result.items[0].html).toContain(broken.raw);
        expect(result.items[1].html).toContain('<svg');
        expect(document.querySelector('[data-math-measurement]')).toBeNull();
    } finally {spy.mockRestore();}
});
test('initialization failure does not leave a measurement root',async()=>{
    await expect(renderMathSources([source('x','x=1')],'invalid namespace')).rejects.toThrow();
    expect(document.querySelector('[data-math-measurement]')).toBeNull();
});
test('a superseded session stops before constructing mathematical output',async()=>{
    const spy=jest.spyOn(SVG.prototype,'typeset');
    try {
        await expect(renderMathSources([source('x','x=1')],'cancelled',undefined,()=>false)).rejects.toThrow('superseded');
        expect(spy).not.toHaveBeenCalled();
        expect(document.querySelector('[data-math-measurement]')).toBeNull();
    } finally {spy.mockRestore();}
});
test('supersession during compilation prevents typesetting and removes the stage',async()=>{
    let active=true;
    const original=SVG.prototype.getMetrics;
    const metrics=jest.spyOn(SVG.prototype,'getMetrics').mockImplementation(function(doc){active=false;return original.call(this,doc);});
    const spy=jest.spyOn(SVG.prototype,'typeset');
    try {
        await expect(renderMathSources([source('x','x=1')],'cancelled-later',undefined,()=>active)).rejects.toThrow('superseded');
        expect(spy).not.toHaveBeenCalled();
        expect(document.querySelector('[data-math-measurement]')).toBeNull();
    } finally {spy.mockRestore();metrics.mockRestore();}
});
test('only processes its own stage, leaving other document mathematics untouched',async()=>{
    const outside=document.createElement('div');outside.textContent=String.raw`\(outside\)`;document.body.append(outside);
    try {
        await renderMathSources([source('inside','x=1')],'scoped');
        expect(outside.textContent).toBe(String.raw`\(outside\)`);
        expect(outside.querySelector('mjx-container')).toBeNull();
    } finally {outside.remove();}
});
test('returns owned CSS without leaving a second engine stylesheet in the page',async()=>{
    document.querySelectorAll('#MJX-SVG-styles').forEach(node=>node.remove());
    const result=await renderMathSources([source('x','x=1')],'style-owner');
    expect(result.css).toContain('mjx-container');
    expect(result.css).toContain('mjx-assistive-mml');
    expect(document.querySelector('#MJX-SVG-styles')).toBeNull();
});
test('disconnects temporary output descendants after returning independent sanitized HTML',async()=>{
    const original=SVG.prototype.typeset;
    const temporary: HTMLElement[]=[];
    const spy=jest.spyOn(SVG.prototype,'typeset').mockImplementation(function(math,doc){
        const node=original.call(this,math,doc) as HTMLElement;temporary.push(node);return node;
    });
    try {
        const result=await renderMathSources([source('x','x=1')],'temporary-trees');
        expect(result.items[0].html).toContain('<svg');
        expect(temporary).toHaveLength(1);
        expect(temporary[0].childNodes).toHaveLength(0);
    } finally {spy.mockRestore();}
});
test('multi-formula output preserves every source boundary and its own local glyphs',async()=>{
    const result=await renderMathSources(Array.from({length:12},(_,i)=>source('item-'+i,`x_${i}=1`)), 'batch');
    expect(result.items.map(item=>item.id)).toEqual(Array.from({length:12},(_,i)=>'item-'+i));
    for(const item of result.items){
        const root=document.createElement('div');root.innerHTML=item.html;
        expect(root.querySelectorAll('mjx-container')).toHaveLength(1);
        expect(root.querySelectorAll('path').length).toBeGreaterThan(0);
        for(const use of root.querySelectorAll('use')){
            const id=(use.getAttribute('href')||use.getAttribute('xlink:href')||'').slice(1);
            expect(Array.from(root.querySelectorAll('defs [id]')).some(node=>node.id===id)).toBe(true);
        }
    }
});
test('equation references remain document-local when the host sets a resource base URL', async () => {
    const base=document.createElement('base');base.href='file:///tmp/documents/';document.head.append(base);
    try {
        const result=await renderMathSources([source('eq',String.raw`x=1\tag{1}\label{x}`),source('ref',String.raw`\eqref{x}`,false)],'base-url');
        expect(result.errors).toHaveLength(0);
        expect(result.items[1].html).toContain('href="#');
    } finally {base.remove();}
});
test('oversized input is preserved without entering the TeX engine', async () => {
    const oversized=source('large','x'.repeat(65537));
    const result=await renderMathSources([oversized,source('good','y=1')],'bounded');
    expect(result.errors).toEqual([{sourceId:'large',code:'input-limit'}]);
    expect(result.items[0].html).toContain(oversized.raw);
    expect(result.items[0].html).not.toContain('mjx-container');
    expect(result.items[1].html).toContain('<svg');
});
test('measures using the current content width and text font, then removes the stage', async () => {
    const host = document.createElement('div');
    host.style.cssText = 'font-size:24px;font-family:serif;padding:10px;';
    Object.defineProperty(host, 'clientWidth', { value: 340 });
    document.body.appendChild(host);
    const pending = renderMathSources([source('x','x=1')], 'metrics', host);
    const stage = document.querySelector<HTMLElement>('[data-math-measurement]')!;
    expect(stage).not.toBeNull();
    expect(stage.style.width).toBe('320px');
    expect(stage.style.fontSize).toBe('24px');
    expect(stage.getAttribute('aria-hidden')).toBe('true');
    await pending;
    expect(document.querySelector('[data-math-measurement]')).toBeNull();
    host.remove();
});
jest.mock('../src/math-font-loader', () => ({ installMathFontLoader: () => {} }));
