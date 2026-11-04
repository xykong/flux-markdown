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
jest.mock('../src/math-font-loader', () => ({ installMathFontLoader: () => {} }));
