const mermaidRender = jest.fn(async (id: string) => ({ svg: `<svg data-test="${id}"></svg>` }));
jest.mock('mermaid', () => ({ __esModule: true, default: { initialize: jest.fn(), render: (id: string) => mermaidRender(id) } }));
import '../src/index';

const options = {context:'quicklook' as const, followFile:true, showCopyButtons:true};
const root = () => document.getElementById('markdown-preview')!;
/** Generated ids and change highlights differ per render; everything else must match a fresh render. */
const normalized = () => {
    window.clearDiffMarks?.();
    return root().innerHTML
        .replace(/ class=""/g, '')
        .replace(/ style="animation-delay: \d+ms;"/g, '')
        .replace(/mermaid-\d+-\d+/g, 'mermaid-id')
        .replace(/fxeq-[\w-]+/g, 'fxeq-id');
};
async function follow(before: string): Promise<void> {
    await window.renderMarkdown(before, options);
    window.setQuickLookFollow(true);
    await window.renderMarkdown(before, options);
}
async function fresh(text: string): Promise<string> {
    await window.renderMarkdown(text, {...options, followFile:false});
    return normalized();
}

beforeEach(() => {
    window.setQuickLookFollow(false);
    document.body.innerHTML = '<div id="markdown-preview"></div><div id="toc-container"></div><div id="search-container"></div>';
    window.scrollTo = jest.fn();
    mermaidRender.mockClear();
});

test.each([
    ['paragraph continuation', 'First block\n\nlast line', ' continues\nand wraps'],
    ['new paragraphs', '# Title\n\nIntro\n\n', 'Second\n\nThird\n'],
    ['partial final line', 'Alpha\n\nBet', 'a and more\n'],
    ['setext heading', 'Intro\n\nHeading text\n', '===\n\nBody\n'],
    ['tight list becomes loose', '- one\n- two\n', '\n- three\n'],
    ['ordered list continues', '1. one\n2. two\n', '3. three\n'],
    ['table rows', '| a | b |\n|---|---|\n| 1 | 2 |\n', '| 3 | 4 |\n'],
    ['open fence closes', 'Text\n\n```js\nconst a = 1;\n', 'const b = 2;\n```\n\nAfter\n'],
    ['closed fence then text', 'Text\n\n```text\nfirst\n```\n\n', 'Next paragraph\n'],
    ['indented code across blank line', 'Para\n\n    code one\n\n', '    code two\n'],
    ['blockquote lazy continuation', '> quoted\n', 'lazy line\n\n> again\n'],
    ['github alert', '> [!NOTE]\n> first\n', '> second\n'],
    ['task list', '- [ ] one\n', '- [x] two\n'],
    ['definition list', 'Term\n', ': Definition\n'],
    ['duplicate heading ids', '# Intro\n\n## Intro\n\n', '## Intro\n\n### Intro-1\n\n## Intro\n'],
    ['reference defined earlier', '[ref]: https://example.com\n\nText\n\n', 'Uses [link][ref]\n'],
    ['abbreviation defined earlier', '*[HTML]: Hyper Text\n\nSome HTML\n\n', 'More HTML here\n'],
    ['front matter', '---\ntitle: Log\n---\n\n# Log\n\nentry one\n', '\nentry two\n'],
    ['unterminated front matter closes', '---\ntitle: Log\n', '---\n\nBody\n'],
    ['inline html', 'Text with <span>inline</span>\n\n', '<details><summary>More</summary>\n\nInside\n\n</details>\n'],
    ['math only in the tail', 'Plain text\n\n', 'Inline $x^2$ and\n\n$$\ny = 1\n$$\n'],
    ['math before the tail', 'Euler $e^{i\\pi}+1=0$\n\nText\n\n', 'Later $a+b$\n'],
    ['footnotes', 'Text[^1]\n\n[^1]: Note\n\n', 'More text[^2]\n\n[^2]: Second\n'],
    ['crlf line endings', 'One\r\n\r\nTwo\r', '\nThree\r\n'],
    ['mermaid diagram stays rendered', '```mermaid\ngraph TD; A-->B\n```\n\n', 'After diagram\n'],
])('incremental result equals a fresh full render: %s', async (_name, before, append) => {
    await follow(before);
    await window.renderMarkdown(before + append, options);
    const incremental = normalized();
    expect(incremental).toBe(await fresh(before + append));
});

test('appended text keeps earlier blocks, including a closed final fence', async () => {
    const before = '# Heading\n\nExisting text\n\n```js\nconst x=1;\n```\n\n';
    await follow(before);
    const heading = root().querySelector('h1');
    const paragraph = root().querySelector('p');
    const pre = root().querySelector('pre');
    await window.renderMarkdown(before + 'new paragraph', options);
    expect(root().querySelector('h1')).toBe(heading);
    expect(root().querySelector('p')).toBe(paragraph);
    expect(root().querySelector('pre')).toBe(pre);
    expect(root().textContent).toContain('new paragraph');
});

test('an extended final paragraph is replaced and earlier blocks keep their identity', async () => {
    await follow('Keep me\n\nGrowing');
    const kept = root().querySelector('p');
    await window.renderMarkdown('Keep me\n\nGrowing line', options);
    const paragraphs = root().querySelectorAll('p');
    expect(paragraphs[0]).toBe(kept);
    expect(paragraphs[1].textContent).toBe('Growing line');
});

test('a reference definition appended later updates the earlier link', async () => {
    await follow('[link][ref]\n\n');
    const before = root().querySelector('p');
    await window.renderMarkdown('[link][ref]\n\n[ref]: https://example.com\n', options);
    expect(root().querySelector('a')?.getAttribute('href')).toBe('https://example.com');
    expect(root().querySelector('p')).not.toBe(before);
});

test('rendered diagrams above the tail are not rendered again', async () => {
    await follow('```mermaid\ngraph TD; A-->B\n```\n\nText\n\n');
    const calls = mermaidRender.mock.calls.length;
    const diagram = root().querySelector('.mermaid');
    await window.renderMarkdown('```mermaid\ngraph TD; A-->B\n```\n\nText\n\nMore\n', options);
    expect(mermaidRender.mock.calls.length).toBe(calls);
    expect(root().querySelector('.mermaid')).toBe(diagram);
});

test('contents include kept and appended headings', async () => {
    await follow('# One\n\ntext\n\n');
    await window.renderMarkdown('# One\n\ntext\n\n# Two\n', options);
    const titles = Array.from(document.querySelectorAll('#toc-container a')).map(link => link.textContent?.trim());
    expect(titles).toEqual(expect.arrayContaining(['One', 'Two']));
});

describe('append-only bridge payload', () => {
    test('appended text is joined to the retained source', async () => {
        const before = '# Log\n\nfirst\n\n';
        await follow(before);
        const heading = root().querySelector('h1');
        const result = await window.renderMarkdown('second\n', {...options, followAppendBase: before.length});
        expect(result).toBeUndefined();
        expect(root().querySelector('h1')).toBe(heading);
        const incremental = normalized();
        expect(incremental).toBe(await fresh(before + 'second\n'));
    });

    test('a base that does not match the retained source asks for a full render', async () => {
        await follow('first\n\n');
        const html = root().innerHTML;
        const result = await window.renderMarkdown('second\n', {...options, followAppendBase: 3});
        expect(result).toEqual({needsFullRender: true});
        expect(root().innerHTML).toBe(html);
    });

    test('appending while not following asks for a full render', async () => {
        await window.renderMarkdown('first\n\n', options);
        const result = await window.renderMarkdown('second\n', {...options, followAppendBase: 'first\n\n'.length});
        expect(result).toEqual({needsFullRender: true});
    });
});

test('copy controls of kept blocks survive an append and new blocks get their own', async () => {
    const before = '```js\nconst a = 1;\n```\n\nText\n\n';
    await follow(before);
    const tools = root().querySelector('.block-copy-tools');
    const host = root().querySelector('.block-copy-host');
    await window.renderMarkdown(before + '```js\nconst b = 2;\n```\n', options);
    expect(root().querySelector('.block-copy-tools')).toBe(tools);
    expect(root().querySelector('.block-copy-host')).toBe(host);
    expect(root().querySelectorAll('pre')).toHaveLength(2);
    expect(root().querySelectorAll('.block-copy-tools')).toHaveLength(2);
    expect(normalized()).toBe(await fresh(before + '```js\nconst b = 2;\n```\n'));
});

test('option order does not matter: native dictionaries reach the renderer in any key order', async () => {
    const before = '# Log\n\nfirst\n\n';
    await follow(before);
    const reordered = Object.fromEntries(Object.entries({...options, followAppendBase: before.length}).reverse());
    expect(await window.renderMarkdown('second\n', reordered)).toBeUndefined();
    expect(root().textContent).toContain('second');
});
