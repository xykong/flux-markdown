import { selectedContent } from '../src/selection-content';
import { rememberDiagramSource } from '../src/diagram-source-store';
import { rememberRenderedSource } from '../src/selection-content';

function select(html: string, selector: string, start: number, end: number) {
    document.body.innerHTML = `<main>${html}</main>`;
    const root = document.querySelector('main')!;
    const node = root.querySelector(selector)!.firstChild!;
    const range = document.createRange(); range.setStart(node, start); range.setEnd(node, end);
    return {root, range};
}
test('partial bold keeps ancestor formatting without widening selection', () => {
    const {root, range} = select('<p><strong>hello world</strong></p>', 'strong', 6, 11);
    expect(selectedContent(root, range, 'plain')).toBe('world');
    expect(selectedContent(root, range, 'markdown')).toBe('**world**');
});
test('partial link keeps destination and selected label', () => {
    const {root, range} = select('<p><a href="../doc.md">hello world</a></p>', 'a', 6, 11);
    expect(selectedContent(root, range, 'markdown')).toBe('[world](../doc.md)');
});
test('code preserves tabs and final newline and excludes controls', () => {
    document.body.innerHTML = '<main><pre><code>\tx\n</code></pre><div class="block-copy-tools">Copy</div></main>';
    const root = document.querySelector('main')!;
    const range = document.createRange(); range.selectNodeContents(root);
    expect(selectedContent(root, range, 'plain')).toBe('\tx\n');
    expect(selectedContent(root, range, 'markdown')).toContain('```');
});
test('source view excludes gutters and deleted historical characters', () => {
    document.body.innerHTML = '<main class="source-mode"><div class="source-diff-gutter">1</div><div class="source-diff-content"><span class="source-diff-line">a<span class="diff-char-removed">old</span>b</span><span class="source-diff-line">c</span></div></main>';
    const root = document.querySelector('main')!;
    const range = document.createRange(); range.selectNodeContents(root);
    expect(selectedContent(root, range, 'markdown')).toBe('ab\nc');
});
test('cross-root and empty selections are rejected', () => {
    const {root, range} = select('<p>hello</p>', 'p', 0, 0);
    expect(selectedContent(root, range, 'plain')).toBeNull();
    range.selectNodeContents(document.body);
    expect(selectedContent(root, range, 'plain')).toBeNull();
});
test('tables retain plain-text row and cell boundaries', () => {
    document.body.innerHTML = '<main><table><tr><th>A</th><th>B</th></tr><tr><td>one</td><td>two</td></tr></table></main>';
    const root = document.querySelector('main')!;
    const range = document.createRange(); range.selectNodeContents(root);
    expect(selectedContent(root, range, 'plain')).toBe('A\tB\none\ttwo');
    expect(selectedContent(root, range, 'markdown')).toContain('|');
});
test('partial tables copy selected cells as readable text without HTML or invented cells', () => {
    const {root, range} = select('<table><tr><th>A</th><th>B</th></tr><tr><td>one</td><td>two</td></tr></table>', 'td', 0, 3);
    expect(selectedContent(root, range, 'markdown')).toBe('one');
});
test('hidden content is excluded and selected repeated phrases are not searched globally', () => {
    const {root, range} = select('<p>world</p><p><em>world</em><span hidden>private</span></p>', 'em', 0, 5);
    expect(selectedContent(root, range, 'markdown')).toBe('*world*');
    range.selectNodeContents(root);
    expect(selectedContent(root, range, 'plain')).toBe('world\n\nworld');
});

function selectedImage(html: string): string | null {
    document.body.innerHTML = `<main>${html}</main>`;
    const root = document.querySelector('main')!;
    const range = document.createRange(); range.selectNodeContents(root);
    return selectedContent(root, range, 'markdown');
}
test('long Base64 images use their original relative URL instead of the embedded payload', () => {
    expect(selectedImage(`<p>text <img alt="diagram" src="data:image/png;base64,${'A'.repeat(201)}" data-original-image-source="../images/diagram.png"></p>`))
        .toBe('text ![diagram](../images/diagram.png)');
});
test('long Base64 images with no relative source are omitted entirely, including an enclosing image-only link', () => {
    expect(selectedImage(`<p>text <a href="https://example.com"><img alt="diagram" src="data:image/png;base64,${'A'.repeat(201)}"></a> after</p>`))
        .toBe('text after');
});
test('the payload limit is 200 characters; unsafe or absolute fallback URLs are not used', () => {
    const below = `data:image/png;base64,${'A'.repeat(199)}`;
    expect(selectedImage(`<img alt="below" src="${below}">`)).toBe(`![below](${below})`);
    const short = `data:image/png;base64,${'A'.repeat(200)}`;
    expect(selectedImage(`<img alt="small" src="${short}">`)).toBe(`![small](${short})`);
    for (const fallback of ['data:image/png;base64,AAAA', 'file:///private/image.png', '/private/image.png', 'https://example.com/image.png']) {
        expect(selectedImage(`<p>text<img src="data:image/png;base64,${'A'.repeat(201)}" data-original-image-source="${fallback}"></p>`)).toBe('text');
    }
});

test('a wholly selected Mermaid diagram copies as its fenced source; a partial one as readable text', () => {
    document.body.innerHTML = '<main><p>before</p><div class="mermaid"><svg><text>A</text><text>B</text></svg></div><p>after</p></main>';
    const root = document.querySelector('main')!;
    rememberDiagramSource(root.querySelector('.mermaid')!, 'mermaid', 'graph TD\n  A-->B\n');
    const range = document.createRange(); range.selectNodeContents(root);
    expect(selectedContent(root, range, 'markdown')).toBe('before\n\n```mermaid\ngraph TD\n  A-->B\n```\n\nafter');
    const label = root.querySelector('text')!.firstChild!;
    const partial = document.createRange(); partial.setStart(root.querySelector('p')!.firstChild!, 0); partial.setEnd(label, 1);
    expect(selectedContent(root, partial, 'markdown')).not.toContain('```');
    expect(selectedContent(root, range, 'plain')).not.toContain('graph TD');
});

describe('whole top-level blocks copy as their Markdown source', () => {
    const text = '## Title\n\n> [!NOTE]\n> Be careful\n\npartial **bold** end';
    function fixture() {
        document.body.innerHTML = '<main><h2 data-source-line="1" data-source-line-end="1">Title</h2>' +
            '<div class="markdown-alert" data-source-line="3" data-source-line-end="4"><p>Note</p><p>Be careful</p></div>' +
            '<p data-source-line="6" data-source-line-end="6">partial <strong>bold</strong> end</p></main>';
        const root = document.querySelector('main')!;
        rememberRenderedSource(root, text, 0);
        return root;
    }
    test('a selection dragged from the first to the last character', () => {
        const root = fixture();
        const range = document.createRange();
        range.setStart(root.querySelector('h2')!.firstChild!, 0);
        const careful = root.querySelectorAll('.markdown-alert p')[1].firstChild!;
        range.setEnd(careful, careful.textContent!.length);
        expect(selectedContent(root, range, 'markdown')).toBe('## Title\n\n> [!NOTE]\n> Be careful');
        expect(selectedContent(root, range, 'plain')).not.toContain('[!NOTE]');
    });
    test('a partly selected block still converts only the selected part', () => {
        const root = fixture();
        const range = document.createRange();
        range.setStart(root.querySelector('h2')!.firstChild!, 0);
        range.setEnd(root.querySelector('strong')!.firstChild!, 4);
        expect(selectedContent(root, range, 'markdown')).toBe('## Title\n\n> [!NOTE]\n> Be careful\n\npartial **bold**');
    });
    test('a tail window maps file lines to its own text', () => {
        const root = fixture();
        root.querySelector('h2')!.setAttribute('data-source-line', '101');
        root.querySelector('h2')!.setAttribute('data-source-line-end', '101');
        rememberRenderedSource(root, text, 100);
        const range = document.createRange(); range.selectNodeContents(root.querySelector('h2')!);
        expect(selectedContent(root, range, 'markdown')).toBe('## Title');
    });
});

test('an image from the file copies as the relative path written there, however it is displayed', () => {
    const tiny = 'data:image/png;base64,' + 'A'.repeat(20);
    expect(selectedImage(`<p>a <img alt="small" src="${tiny}" data-original-image-source="img/small.png"> b</p>`)).toBe('a ![small](img/small.png) b');
    expect(selectedImage('<p>a <img alt="local" src="local-md:///Users/me/doc/img/x.png?v=3" data-original-image-source="img/x.png"> b</p>')).toBe('a ![local](img/x.png) b');
    expect(selectedImage('<p>a <img alt="absolute" src="local-md:///Users/me/doc/img/x.png?v=3"> b</p>')).toBe('a b');
    expect(selectedImage('<p>a <img alt="web" src="https://example.com/x.png"> b</p>')).toBe('a ![web](https://example.com/x.png) b');
});
