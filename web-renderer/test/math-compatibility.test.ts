jest.mock('mermaid', () => ({
    initialize: jest.fn(), render: jest.fn().mockResolvedValue({ svg: '<svg></svg>' }),
}));

import '../src/index';
import { readFileSync } from 'fs';
import { resolve } from 'path';

function preview(): HTMLElement {
    return document.getElementById('markdown-preview')!;
}

function formulas(): Element[] {
    return Array.from(preview().querySelectorAll('.katex, mjx-container'))
        .filter(node => !node.querySelector('merror, [data-mml-node="merror"], mjx-merror'));
}

async function render(source: string): Promise<void> {
    await window.renderMarkdown(source, { enableMermaid: false, enableTypst: false });
}

describe('Issue 64 mathematical input contracts', () => {
    beforeEach(() => {
        document.body.innerHTML = '<div id="markdown-preview"></div>';
    });

    test.each([
        ['inline dollars', '$E = mc^2$'],
        ['inline parentheses', String.raw`\(a^2+b^2=c^2\)`],
        ['display dollars', '$$\n'+String.raw`\int_0^1 x\,dx=\frac12`+'\n$$'],
        ['display brackets', '\\[\n'+String.raw`\sum_{k=1}^n k=\frac{n(n+1)}2`+'\n\\]'],
        ['math fence', '```math\n'+String.raw`\nabla\cdot\mathbf{E}=\frac{\rho}{\varepsilon_0}`+'\n```'],
        ['tilde math fence', '~~~math\nx^2\n~~~'],
        ['standalone AMS equation', String.raw`\begin{equation}x=1\end{equation}`],
        ['quoted display brackets', '> \\[\n> x^2\n> \\]'],
        ['list math fence', '- Formula\n\n  ```math\n  x^2\n  ```'],
    ])('%s produces one valid mathematical item', async (_name, source) => {
        await render(source);
        expect(formulas()).toHaveLength(1);
    });

    test.each([
        ['code span', '`$x$ \\(y\\)`'],
        ['ordinary fence', '```text\n$x$ \\(y\\)\n```'],
        ['indented code', '    $x$ \\(y\\)'],
        ['escaped money', String.raw`Prices: \$5.00 and \$10.00. Code: `+'`$HOME`'],
        ['HTML attributes', '<span title="$x$">Visible</span>'],
        ['HTML comment', '<!-- $x$ \\(y\\) -->\nVisible'],
        ['unclosed parentheses', String.raw`\(x^2`+'\n\n# Following content'],
    ])('%s remains outside mathematics', async (_name, source) => {
        await render(source);
        expect(formulas()).toHaveLength(0);
    });

    test('protected fence source is preserved verbatim', async () => {
        const code = String.raw`\(x^2\) $$y$$ \label{literal}`;
        await render('```text\n'+code+'\n```');
        // The existing line-number presentation removes the final fence newline.
        expect(preview().querySelector('code')?.textContent).toBe(code);
    });

    test('an explicit tag and backward reference produce a real target', async () => {
        await render('$$\nx^2'+String.raw`\tag{1}\label{eq:pythagoras}`+'\n$$\n\n'+String.raw`$\eqref{eq:pythagoras}$`);
        expect(formulas()).toHaveLength(2);
        const links = Array.from(preview().querySelectorAll<HTMLAnchorElement>('a[href^="#"]'));
        expect(links).toHaveLength(1);
        const href = links[0].getAttribute('href')!;
        expect(href).not.toBe('#');
        const target = document.getElementById(decodeURIComponent(href.slice(1)));
        expect(target).not.toBeNull();
        expect(preview().contains(target)).toBe(true);
    });

    test('forward references resolve after the complete document is compiled', async () => {
        await render(String.raw`$\eqref{eq:forward}$`+'\n\n$$\ny=x'+String.raw`\tag{A}\label{eq:forward}`+'\n$$');
        expect(formulas()).toHaveLength(2);
        expect(preview().textContent).not.toContain('???');
        expect(preview().querySelector('a[href="#"]')).toBeNull();
        expect(preview().querySelector('a[href^="#"]')).not.toBeNull();
    });

    test('a bad command preserves following valid mathematics and prose', async () => {
        await render(String.raw`$\unknownMarkdownPreviewCommand{x}$`+'\n\n$x=1$\n\nDocument end');
        expect(formulas()).toHaveLength(1);
        expect(preview().textContent).toContain('Document end');
        expect(preview().querySelector('.katex-error, .math-error, [data-mml-node="merror"], mjx-merror')).not.toBeNull();
    });

    test('renders the original MathML beside TeX with one accessible tree per item', async () => {
        const cases: Array<{ id: string; tex: string }> = JSON.parse(readFileSync(resolve(__dirname, '../../docs/research/issue64/math-cases.json'), 'utf8'));
        await render(cases.find(item => item.id === 'M13')!.tex+'\n\n$x=1$');
        expect(formulas()).toHaveLength(2);
        expect(preview().querySelectorAll('mjx-assistive-mml math')).toHaveLength(2);
        const semantic = preview().querySelector('mjx-assistive-mml math')!;
        expect(Array.from(semantic.querySelectorAll('msup > mi')).map(node => node.textContent)).toEqual(['x','y','z']);
    });

    test('preserves native MathML when enhanced mathematics is disabled', async () => {
        await window.renderMarkdown('<math><mi>x</mi></math>\n\n'+String.raw`\(x^2\)`, { enableKatex: false });
        expect(preview().querySelector('math mi')?.textContent).toBe('x');
        expect(formulas()).toHaveLength(0);
        expect(preview().textContent).toContain(String.raw`\(x^2\)`);
    });

    test('renders every original mathematical item and retains the intentional error', async () => {
        const original = readFileSync(resolve(__dirname, '../../Tests/fixtures/issues/64/markdown-preview-test.md'), 'utf8');
        const cases: Array<{ id: string; tex: string }> = JSON.parse(readFileSync(resolve(__dirname, '../../docs/research/issue64/math-cases.json'), 'utf8'));
        const section = original.slice(original.indexOf('## 10 ·'), original.indexOf('<a id="diagrams">'));
        await render(cases.find(item => item.id === 'M13')!.tex+'\n\n'+section);
        expect(formulas()).toHaveLength(12);
        expect(preview().querySelectorAll('mjx-container')).toHaveLength(13);
        expect(preview().querySelectorAll('.math-error')).toHaveLength(1);
        expect(preview().querySelectorAll('mjx-assistive-mml math')).toHaveLength(13);
        expect(preview().textContent).toContain('$5.00');
        expect(preview().querySelector('code')?.textContent).toBe('$HOME');
    });

    test('export rejects unresolved references and recovers on the next valid document', async () => {
        await render(String.raw`$\eqref{absent}$`);
        await expect(window.waitForExportReady()).rejects.toThrow(/math/i);
        await render('$x=1$');
        await expect(window.waitForExportReady()).resolves.toBeUndefined();
    });
    test('math-only headings have meaningful distinct navigation anchors',async()=>{
        await render('# $x^2$\n\n# $y^2$');
        const headings=Array.from(preview().querySelectorAll('h1'));
        expect(headings[0].id).toContain('x');
        expect(headings[1].id).toContain('y');
        expect(headings[0].id).not.toBe(headings[1].id);
    });
    test('formula navigation retains original source lines after CRLF front matter',async()=>{
        await render('---\r\ntitle: Test\r\n---\r\n\r\nText\r\n\r\n\\[\r\nx=1\r\n\\]');
        expect(preview().querySelector('.flux-math-source')?.getAttribute('data-source-line')).toBe('7');
        expect(preview().querySelector('.flux-math-source')?.getAttribute('data-source-line-end')).toBe('9');
    });
    test('GFM table escaping preserves mathematical vertical bars',async()=>{
        await render('| Formula | Result |\n| --- | --- |\n| $a\\|b$ | **$x^2$** |');
        expect(preview().querySelectorAll('tbody td')).toHaveLength(2);
        expect(formulas()).toHaveLength(2);
        expect(preview().querySelector('.math-error')).toBeNull();
        const semantic=preview().querySelector('mjx-assistive-mml math')!;
        expect(semantic.textContent).toContain('|');
    });
    test('footnote formulas and references use source order despite footnote relocation',async()=>{
        await render('[^n]: '+String.raw`\(\eqref{x}\)`+'\n\nBody[^n]\n\n'+String.raw`\[x=1\tag{A}\label{x}\]`);
        expect(formulas()).toHaveLength(2);
        const footnote=preview().querySelector('.footnotes')!;
        expect(footnote.querySelector('a.math-reference-link')?.getAttribute('aria-label')).toBe('(A)');
        expect(preview().querySelector('.math-error')).toBeNull();
    });
    test('strong and emphasis containers preserve formula semantics',async()=>{
        await render('**'+String.raw`\(x^2\)`+'** and *$y^2$*');
        expect(preview().querySelector('strong mjx-container')).not.toBeNull();
        expect(preview().querySelector('em mjx-container')).not.toBeNull();
    });
    test('an unmatched display opener does not consume a later heading and valid block',async()=>{
        await render('\\[\nunclosed\n\n## Following\n\n\\[\nx=1\n\\]\n\nEnd');
        expect(preview().querySelector('h2')?.textContent).toBe('Following');
        expect(formulas()).toHaveLength(1);
        expect(preview().textContent).toContain('unclosed');
        expect(preview().textContent).toContain('End');
    });
    test('an unclosed block in a quote cannot consume a later top-level closer',async()=>{
        await render('> \\[\n> unclosed\n\n## Following\n\n\\]\n\n$x=1$');
        expect(preview().querySelector('h2')?.textContent).toBe('Following');
        expect(formulas()).toHaveLength(1);
    });
});
