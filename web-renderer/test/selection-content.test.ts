import { DiffAnimator } from '../src/diff-animator';
import { computeLineDiff } from '../src/diff-engine';
import { copySelectionWithFormat, copySourceSelectionAsPlainText, selectedContent } from '../src/selection-content';
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
    document.body.innerHTML = '<main class="source-mode"><div class="source-diff-gutter">1</div><div class="source-diff-content"><span class="source-diff-line" data-source-line="1">a<span class="diff-char-removed">old</span>b</span><span class="source-diff-line" data-source-line="2">c</span></div></main>';
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

test.each([
    ['one empty line', 'alpha\n\nbeta'],
    ['consecutive empty lines', 'alpha\n\n\nbeta'],
    ['leading and trailing empty lines', '\nalpha\n\n'],
    ['whitespace-only line', 'alpha\n \t\nbeta'],
])('source selection preserves %s in both copy formats', (_label, source) => {
    const root = document.createElement('main');
    root.classList.add('source-mode');
    root.innerHTML = new DiffAnimator().buildSourceHTML(computeLineDiff('', source), 'light');
    document.body.replaceChildren(root);
    const range = document.createRange();
    range.selectNodeContents(root);
    expect(selectedContent(root, range, 'plain')).toBe(source);
    expect(selectedContent(root, range, 'markdown')).toBe(source);
});

describe('copySourceSelectionAsPlainText', () => {
    function makeCopyEvent(target: EventTarget) {
        const data = new Map<string, string>();
        let prevented = false;
        const event = {
            target,
            clipboardData: {
                setData: (type: string, value: string) => { data.set(type, value); },
                getData: (type: string) => data.get(type) ?? '',
            },
            preventDefault: () => { prevented = true; },
        } as unknown as ClipboardEvent;
        return { event, data, isPrevented: () => prevented };
    }

    function selectRange(range: Range) {
        const selection = window.getSelection()!;
        selection.removeAllRanges();
        selection.addRange(range);
    }

    function renderSourceFixture(source: string, prev = '') {
        const root = document.createElement('div');
        root.id = 'markdown-preview';
        root.className = 'markdown-body source-mode';
        root.innerHTML = new DiffAnimator().buildSourceHTML(computeLineDiff(prev, source, { sourceView: true }), 'light');
        document.body.replaceChildren(root);
        return root;
    }

    test('writes only text/plain and preserves adjacent headings, paragraphs, lists, and blank lines', () => {
        const source = [
            '## Title',
            '',
            '### 1.1 Section',
            'Paragraph directly below heading.',
            '',
            '### 1.2 Details',
            'Intro line:',
            '- first item',
            '- second item',
            '',
            '',
            'After two blank lines.',
        ].join('\n');
        const root = renderSourceFixture(source);
        const rows = root.querySelectorAll('.source-diff-line');
        const range = document.createRange();
        range.setStart(rows[0].firstChild!, 0);
        const lastText = rows[rows.length - 1].firstChild!;
        range.setEnd(lastText, lastText.textContent!.length);
        selectRange(range);

        const { event, data, isPrevented } = makeCopyEvent(rows[0]);
        expect(copySourceSelectionAsPlainText(event, root)).toBe(true);
        expect(isPrevented()).toBe(true);
        expect(Array.from(data.keys())).toEqual(['text/plain']);
        expect(data.get('text/plain')).toBe(source);
    });

    test('clamps Select All ranges extending outside #markdown-preview without losing trailing newline', () => {
        const source = '### Heading\nBody\n- item\n';
        const root = renderSourceFixture(source);
        const header = document.createElement('div');
        header.textContent = 'toolbar';
        document.body.prepend(header);

        const range = document.createRange();
        range.selectNodeContents(document.body);
        selectRange(range);

        const { event, data, isPrevented } = makeCopyEvent(document.body);
        expect(copySourceSelectionAsPlainText(event, root)).toBe(true);
        expect(isPrevented()).toBe(true);
        expect(Array.from(data.keys())).toEqual(['text/plain']);
        expect(data.get('text/plain')).toBe(source);
    });

    test('excludes gutter numbers, removed diff lines, and deleted diff characters', () => {
        const root = renderSourceFixture('keep\nhello earth', 'keep\nremoved\nhello world');
        const range = document.createRange();
        range.selectNodeContents(root);
        selectRange(range);

        const { event, data, isPrevented } = makeCopyEvent(root);
        expect(copySourceSelectionAsPlainText(event, root)).toBe(true);
        expect(isPrevented()).toBe(true);
        expect(data.get('text/plain')).toBe('keep\nhello earth');
    });

    test.each([
        ['', 'a\r\n\r\nb\r\n', 'a\n\nb\n'],
        ['a\nremoved\nlast\n', 'a\nlast\n\n', 'a\nlast\n\n'],
        ['a\nremoved\nlast\n', 'a\nlast', 'a\nlast'],
        ['a\nremoved\nlast\n', '\n', '\n'],
    ])('preserves source lines before and after diff marks are cleared (%j → %j)', (previous, source, expected) => {
        const root = renderSourceFixture(source, previous);
        const range = document.createRange();
        range.selectNodeContents(root);
        selectRange(range);

        for (const clearMarks of [false, true]) {
            if (clearMarks) {
                root.querySelectorAll('.diff-exiting').forEach(row => row.classList.remove('diff-exiting'));
            }
            const { event, data } = makeCopyEvent(root);
            expect(copySourceSelectionAsPlainText(event, root)).toBe(true);
            expect(data.get('text/plain')).toBe(expected);
            expect(selectedContent(root, range, 'plain')).toBe(expected);
            expect(selectedContent(root, range, 'markdown')).toBe(expected);
        }
    });

    test('leaves native TSV copy unchanged, including when a preview notice is present', () => {
        const tsv = 'col1\tcol2\nval1\tval2';
        document.body.innerHTML = `<div id="markdown-preview" class="source-mode"><div class="tsv-truncated">Preview limited</div><pre>${tsv}</pre></div>`;
        const root = document.getElementById('markdown-preview')!;
        const range = document.createRange();
        range.selectNodeContents(root);
        selectRange(range);

        const { event, data, isPrevented } = makeCopyEvent(root);
        expect(copySourceSelectionAsPlainText(event, root)).toBe(false);
        expect(isPrevented()).toBe(false);
        expect(data.size).toBe(0);
    });

    test('does not intercept copy in rendered view', () => {
        document.body.innerHTML = '<div id="markdown-preview"><p>Hello <strong>world</strong></p></div>';
        const root = document.getElementById('markdown-preview')!;
        const range = document.createRange();
        range.selectNodeContents(root);
        selectRange(range);

        const { event, data, isPrevented } = makeCopyEvent(root);
        expect(copySourceSelectionAsPlainText(event, root)).toBe(false);
        expect(isPrevented()).toBe(false);
        expect(data.size).toBe(0);
    });

    test('does not intercept copy inside search input or outside #markdown-preview', () => {
        const root = renderSourceFixture('alpha\nbeta');
        const input = document.createElement('input');
        input.value = 'query';
        document.body.prepend(input);
        input.focus();

        const range = document.createRange();
        range.selectNodeContents(root);
        selectRange(range);

        const fromInput = makeCopyEvent(input);
        expect(copySourceSelectionAsPlainText(fromInput.event, root)).toBe(false);
        expect(fromInput.isPrevented()).toBe(false);
        input.blur();

        const outside = document.createElement('p');
        outside.textContent = 'help dialog text';
        document.body.append(outside);
        const outsideRange = document.createRange();
        outsideRange.selectNodeContents(outside);
        selectRange(outsideRange);

        const fromOutside = makeCopyEvent(outside);
        expect(copySourceSelectionAsPlainText(fromOutside.event, root)).toBe(false);
        expect(fromOutside.isPrevented()).toBe(false);
    });

    test('still intercepts copy when focus remains on a toolbar button', () => {
        const root = renderSourceFixture('### Heading\nParagraph');
        const button = document.createElement('button');
        button.textContent = 'Source';
        document.body.prepend(button);
        button.focus();

        const range = document.createRange();
        range.selectNodeContents(root);
        selectRange(range);

        const { event, data, isPrevented } = makeCopyEvent(root);
        expect(copySourceSelectionAsPlainText(event, root)).toBe(true);
        expect(isPrevented()).toBe(true);
        expect(data.get('text/plain')).toBe('### Heading\nParagraph');
    });
});

describe('rendered preview markdown copy preserves exact inter-block line breaks and honors defaultCopyFormat', () => {
    function makeCopyEvent(target: EventTarget) {
        const data = new Map<string, string>();
        let prevented = false;
        const event = {
            target,
            clipboardData: {
                setData: (type: string, value: string) => { data.set(type, value); },
                getData: (type: string) => data.get(type) ?? '',
            },
            preventDefault: () => { prevented = true; },
        } as unknown as ClipboardEvent;
        return { event, data, isPrevented: () => prevented };
    }

    function selectRange(range: Range) {
        const selection = window.getSelection()!;
        selection.removeAllRanges();
        selection.addRange(range);
    }

    function renderMappedPreview(source: string, html: string) {
        document.body.innerHTML = `<div id="markdown-preview" class="markdown-body">${html}</div>`;
        const root = document.getElementById('markdown-preview')!;
        rememberRenderedSource(root, source, 0);
        return root;
    }

    test('preserves 0 blank lines, 1 blank line, and 2+ blank lines between selected blocks', () => {
        const source = [
            '### 1.1 Section',
            'Paragraph directly below heading.',
            '',
            '### 1.2 Details',
            '- first item',
            '- second item',
            '',
            '',
            'After two blank lines.',
        ].join('\n');
        const html = [
            '<h3 data-source-line="1" data-source-line-end="1">1.1 Section</h3>',
            '<p data-source-line="2" data-source-line-end="2">Paragraph directly below heading.</p>',
            '<h3 data-source-line="4" data-source-line-end="4">1.2 Details</h3>',
            '<ul data-source-line="5" data-source-line-end="6"><li>first item</li><li>second item</li></ul>',
            '<p data-source-line="9" data-source-line-end="9">After two blank lines.</p>',
        ].join('');
        const root = renderMappedPreview(source, html);
        const range = document.createRange();
        range.selectNodeContents(root);
        expect(selectedContent(root, range, 'markdown')).toBe(source);
    });

    test('preserves exact blank lines for partial cross-block selections', () => {
        const source = 'First **bold** end\n\n\nStart *italic* second';
        const html = '<p data-source-line="1" data-source-line-end="1">First <strong>bold</strong> end</p>' +
            '<p data-source-line="4" data-source-line-end="4">Start <em>italic</em> second</p>';
        const root = renderMappedPreview(source, html);
        const ps = root.querySelectorAll('p');
        const range = document.createRange();
        range.setStart(ps[0].querySelector('strong')!.firstChild!, 0);
        range.setEnd(ps[1].querySelector('em')!.firstChild!, 6);
        expect(selectedContent(root, range, 'markdown')).toBe('**bold** end\n\n\nStart *italic*');
    });

    test('copySelectionWithFormat respects rich-text, markdown, and plain-text in rendered view', () => {
        const source = '### Heading\nParagraph **bold**\n\n\nNext line';
        const html = '<h3 data-source-line="1" data-source-line-end="1">Heading</h3>' +
            '<p data-source-line="2" data-source-line-end="2">Paragraph <strong>bold</strong></p>' +
            '<p data-source-line="5" data-source-line-end="5">Next line</p>';
        const root = renderMappedPreview(source, html);
        const range = document.createRange();
        range.selectNodeContents(document.body);
        selectRange(range);

        const rich = makeCopyEvent(root);
        expect(copySelectionWithFormat(rich.event, root, 'rich-text')).toBe(false);
        expect(rich.isPrevented()).toBe(false);
        expect(rich.data.size).toBe(0);

        const md = makeCopyEvent(root);
        expect(copySelectionWithFormat(md.event, root, 'markdown')).toBe(true);
        expect(md.isPrevented()).toBe(true);
        expect(Array.from(md.data.keys())).toEqual(['text/plain']);
        expect(md.data.get('text/plain')).toBe(source);

        const plain = makeCopyEvent(root);
        expect(copySelectionWithFormat(plain.event, root, 'plain-text')).toBe(true);
        expect(plain.isPrevented()).toBe(true);
        expect(Array.from(plain.data.keys())).toEqual(['text/plain']);
        expect(plain.data.get('text/plain')).toBe('Heading\n\nParagraph bold\n\nNext line');
    });

    test('copySelectionWithFormat does not intercept editable inputs even in markdown mode', () => {
        const root = renderMappedPreview('### Heading', '<h3 data-source-line="1" data-source-line-end="1">Heading</h3>');
        const input = document.createElement('input');
        input.value = 'find';
        document.body.prepend(input);
        input.focus();

        const range = document.createRange();
        range.selectNodeContents(root);
        selectRange(range);

        const ev = makeCopyEvent(input);
        expect(copySelectionWithFormat(ev.event, root, 'markdown')).toBe(false);
        expect(ev.isPrevented()).toBe(false);
    });
});
