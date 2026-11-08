import { diagramScale, installMermaidLayout } from '../src/mermaid-layout';

describe('Mermaid readable default size', () => {
    test('never stretches small diagrams and caps larger labels at body size', () => {
        expect(diagramScale(300, 1400, 16, 16)).toBe(1);
        expect(diagramScale(300, 1400, 16, 32)).toBe(.5);
        expect(diagramScale(2000, 500, 16, 16)).toBe(.25);
        expect(diagramScale(300, 1400, 12, 16)).toBe(.75);
    });
    test('independent bounded controls reset and dispose', () => {
        document.body.innerHTML = '<div id="root" style="font-size:16px">' +
            '<div class="mermaid"><svg viewBox="0 0 300 100"><text style="font-size:16px">A</text></svg></div>'.repeat(2) + '</div>';
        const root = document.getElementById('root')!;
        const dispose = installMermaidLayout(root);
        const diagrams = root.querySelectorAll<HTMLElement>('.mermaid');
        const first = diagrams[0].querySelector('svg')!;
        const second = diagrams[1].querySelector('svg')!;
        const buttons = diagrams[0].querySelectorAll('button');
        const original = first.style.width;
        buttons[2].click();
        expect(first.style.width).not.toBe(original);
        expect(second.style.width).toBe(original);
        for (let i=0;i<30;i++) buttons[2].click();
        expect(buttons[2].disabled).toBe(true);
        buttons[1].click();
        expect(first.style.width).toBe(original);
        for (let i=0;i<40;i++) buttons[0].click();
        expect(buttons[0].disabled).toBe(true);
        expect(buttons[1].getAttribute('aria-label')).toBeTruthy();
        dispose();
        expect(root.querySelector('.mermaid-tools')).toBeNull();
    });
});

test('diagram controls are excluded from copied and searched document text', () => {
    document.body.innerHTML = '<div id="markdown-preview"><blockquote><div class="mermaid-tools"><button>100%</button></div><p>Actual document</p></blockquote></div>';
    const { blockPlainText } = require('../src/block-copy');
    const { SearchEngine } = require('../src/search');
    expect(blockPlainText(document.querySelector('blockquote'))).toBe('Actual document');
    const search = new SearchEngine();
    expect(search.search('100%', {caseSensitive:false, wholeWord:false, useRegex:false})).toBe(0);
});
