import { renderMathSources } from '../src/math-engine';
import type { MathSource } from '../src/math-syntax';

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
