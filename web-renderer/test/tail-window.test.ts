jest.mock('mermaid', () => ({ initialize: jest.fn(), render: jest.fn() }));
import '../src/index';

const options = {context:'quicklook' as const, followFile:true, showCopyButtons:true};
const root = () => document.getElementById('markdown-preview')!;
const lines = (selector = '[data-source-line]') =>
    Array.from(root().querySelectorAll(selector)).map(el => `${el.tagName}:${el.getAttribute('data-source-line')}-${el.getAttribute('data-source-line-end')}`);

beforeEach(() => {
    window.setQuickLookFollow(false);
    document.body.innerHTML = '<div id="markdown-preview"></div><div id="toc-container"></div><div id="search-container"></div>';
    window.scrollTo = jest.fn();
});

const head = '# One\n\nfirst paragraph\n\n';                       // 4 lines
const tail = '## Two\n\nsecond\n\n```js\nconst x = 1;\n```\n\n- item\n';

test('a tail window carries the file\'s own line numbers', async () => {
    await window.renderMarkdown(head + tail, {...options, followFile:false});
    const full = lines().filter(entry => Number(entry.split(':')[1].split('-')[0]) > 4);
    await window.renderMarkdown(tail, {...options, followFile:false, sourceLineStart: 4});
    expect(lines()).toEqual(full);
});

test('a window that starts with --- shows a rule, not front matter', async () => {
    await window.renderMarkdown('---\ntitle: not front matter\n---\n\ntext\n', {...options, sourceLineStart: 10});
    expect(root().querySelector('hr')).not.toBeNull();
    expect(root().querySelector('[data-source-line="1"]')).toBeNull();
    expect(root().querySelector('[data-source-line="11"]')).not.toBeNull();
    expect(root().textContent).toContain('title: not front matter');
});

test('appends inside a tail window equal a fresh render of the window', async () => {
    const window50 = {...options, sourceLineStart: 50};
    await window.renderMarkdown(tail, window50);
    window.setQuickLookFollow(true);
    await window.renderMarkdown(tail, window50);
    const kept = root().querySelector('h2');
    const result = await window.renderMarkdown('\nmore\n\n## Three\n', {...window50, followAppendBase: tail.length});
    expect(result).toBeUndefined();
    expect(root().querySelector('h2')).toBe(kept);
    window.clearDiffMarks?.();
    const clean = (html: string) => html.replace(/ class=""/g, '').replace(/ style="(animation-delay: \d+ms;)?"/g, '');
    const incremental = clean(root().innerHTML);
    window.setQuickLookFollow(false);
    await window.renderMarkdown(tail + '\nmore\n\n## Three\n', {...window50, followFile:false});
    expect(clean(root().innerHTML)).toBe(incremental);
});

test('change highlights in a tail window match those of the same text at line 0', async () => {
    const marked = async (start: number) => {
        window.setQuickLookFollow(false);
        const opts = {...options, sourceLineStart: start};
        await window.renderMarkdown(tail, opts);
        window.setQuickLookFollow(true);
        await window.renderMarkdown(tail, opts);
        await window.renderMarkdown('\nappended paragraph\n', {...opts, followAppendBase: tail.length});
        return Array.from(root().querySelectorAll('.render-diff-block-enter')).map(el => el.textContent?.trim());
    };
    const atStart = await marked(0);
    expect(atStart).toContain('appended paragraph');
    expect(await marked(50)).toEqual(atStart);
});
