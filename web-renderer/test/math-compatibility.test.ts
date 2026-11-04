jest.mock('mermaid', () => ({
    initialize: jest.fn(), render: jest.fn().mockResolvedValue({ svg: '<svg></svg>' }),
}));

import '../src/index';

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
        expect(preview().querySelector('code')?.textContent).toBe(code+'\n');
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
});
