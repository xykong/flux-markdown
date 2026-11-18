jest.mock('mermaid', () => ({ __esModule: true, default: { initialize: jest.fn(), render: jest.fn(async (id: string) => ({ svg: `<svg data-id="${id}"></svg>` })) } }));
import '../src/index';

// Each case renders about 600 KB in jsdom; a loaded machine needs more than 5 s.
jest.setTimeout(30_000);

const options = {context:'quicklook' as const, followFile:true, showCopyButtons:true};
const root = () => document.getElementById('markdown-preview')!;
const clean = () => {
    window.clearDiffMarks?.();
    return root().innerHTML.replace(/mermaid-\d+-\d+/g, 'mermaid-id').replace(/ class=""/g, '').replace(/ style="(animation-delay: \d+ms;)?"/g, '');
};
/** About 600 KB of transcript-shaped text: headings, prose, code, tables, quotes. */
function stream(turns = 400): string {
    let text = '# Session\n\n';
    for (let i = 0; i < turns; i++) {
        text += `## Turn ${i}\n\n> prompt ${i}\n\nReply ${i} ` + 'words '.repeat(120) + `\n\n\`\`\`text\nlog ${i}\n${'output '.repeat(60)}\n\`\`\`\n\n| a | b |\n|---|---|\n| ${i} | x |\n\n`;
    }
    return text + 'FINAL-MARKER\n';
}
/** Element children of the preview at the first DOM commit of the next render. */
function firstCommit(): Promise<string[]> {
    return new Promise(resolve => {
        const observer = new MutationObserver(() => {
            if (!root().querySelector('[data-source-line]')) return;
            observer.disconnect();
            resolve(Array.from(root().children).map(child => child.textContent || ''));
        });
        observer.observe(root(), { childList: true });
    });
}

beforeEach(() => {
    window.setQuickLookFollow(false);
    document.body.innerHTML = '<div id="markdown-preview"></div><div id="toc-container"></div><div id="search-container"></div>';
    window.scrollTo = jest.fn();
});

test('the first commit holds only the first pages and the completed preview equals a single commit', async () => {
    const text = stream();
    await window.renderMarkdown(text, {...options, progressive: false});
    const single = clean();
    const total = root().children.length;
    const first = firstCommit();
    await window.renderMarkdown(text, {...options, documentGeneration: 'fresh'});
    const committed = await first;
    expect(committed.length).toBeLessThan(total / 4);
    expect(committed[0]).toContain('Session');
    expect(committed.join('')).not.toContain('FINAL-MARKER');
    expect(clean()).toBe(single);
});

test('while following, the first commit holds the last pages', async () => {
    const text = stream();
    await window.renderMarkdown('start', options);
    window.setQuickLookFollow(true);
    const first = firstCommit();
    await window.renderMarkdown(text, options);
    const committed = await first;
    expect(committed.join('')).toContain('FINAL-MARKER');
    expect(committed.join('')).not.toContain('Session');
    expect(root().firstElementChild?.textContent).toContain('Session');
});

test('export and print wait for the whole window', async () => {
    const pending = window.renderMarkdown(stream(), options);
    await window.waitForExportReady();
    expect(root().textContent).toContain('FINAL-MARKER');
    expect(root().textContent).toContain('Turn 0');
    await pending;
});

test('a newer render cancels the remaining slices', async () => {
    const older = window.renderMarkdown(stream(), options);
    await new Promise(resolve => setTimeout(resolve, 0));
    await window.renderMarkdown('# Newer\n', {...options, documentGeneration: 'newer'});
    await older;
    await new Promise(resolve => setTimeout(resolve, 20));
    expect(root().textContent).toContain('Newer');
    expect(root().textContent).not.toContain('Turn 1 ');
});

test('contents and copy controls cover the whole window', async () => {
    await window.renderMarkdown(stream(), options);
    expect(document.querySelectorAll('#toc-container a').length).toBeGreaterThan(400);
    expect(root().querySelectorAll('.block-copy-tools').length).toBe(root().querySelectorAll('pre').length + root().querySelectorAll('blockquote').length);
});

test('a document with math renders its whole window in one commit after the provisional page', async () => {
    const commits: number[] = [];
    const observer = new MutationObserver(() => commits.push(root().children.length));
    observer.observe(root(), { childList: true });
    await window.renderMarkdown(stream() + '\n$x^2$\n', options);
    observer.disconnect();
    expect(root().textContent).toContain('FINAL-MARKER');
    expect(root().querySelector('.flux-math-source, .flux-math')).not.toBeNull();
    // At most a provisional page, then the whole window at once.
    expect(commits.filter((count, index) => index === 0 || count !== commits[index - 1]).length).toBeLessThanOrEqual(2);
});

test('the contents column appears with the first slice even when that slice has no headings', async () => {
    const text = '# Start\n\n' + Array.from({ length: 400 }, (_, i) => `## Turn ${i}\n\ntext\n\n`).join('') + 'tail '.repeat(10_000) + '\n\nFINAL-MARKER\n';
    await window.renderMarkdown('start', options);
    window.setQuickLookFollow(true);
    let linksAtFirstCommit = -1;
    const observer = new MutationObserver(() => {
        if (linksAtFirstCommit >= 0 || !root().textContent?.includes('FINAL-MARKER')) return;
        linksAtFirstCommit = document.querySelectorAll('#toc-container .toc-link').length;
    });
    observer.observe(root(), { childList: true });
    await window.renderMarkdown(text, options);
    observer.disconnect();
    expect(linksAtFirstCommit).toBeGreaterThan(0);
});

test('parsing the window in segments gives the same page as one parse', async () => {
    let text = '---\ntitle: Log\n---\n\n# Session\n\n';
    for (let i = 0; i < 300; i++) {
        text += `## Turn\n\nReply ${i} ${'words '.repeat(80)}\n\n- item a\n\n- item b\n\n  continued\n\n1. one\n\n2. two\n\n` +
            `\`\`\`text\nlog ${i}\n\nWord after blank inside code\n\`\`\`\n\n| a | b |\n|---|---|\n| ${i} | x |\n\nTerm ${i}\n: definition\n\n> quote ${i}\nlazy line\n\n` +
            (i % 50 === 0 ? '```mermaid\ngraph TD; A-->B\n```\n\n' : '');
    }
    await window.renderMarkdown(text, {...options, progressive: false});
    const single = clean();
    await window.renderMarkdown(text, {...options, documentGeneration: 'segmented'});
    expect(clean()).toBe(single);
});

test('only large pages ask WebKit to skip distant blocks', async () => {
    await window.renderMarkdown(stream(), options);
    expect(document.documentElement.dataset.largeDocument).toBe('true');
    await window.renderMarkdown('# Small\n', {...options, documentGeneration: 'small'});
    expect(document.documentElement.dataset.largeDocument).toBe('false');
});

test.each(['app', 'quicklook', 'finder'] as const)('multiline reference definitions work throughout a large %s preview', async context => {
    const text = '[multi line]\n\n' + 'Padding '.repeat(9000) + '\n\n# Later\n\n[multi\nline]: https://example.com\n';
    await window.renderMarkdown(text, {context});
    expect(root().querySelector('a')?.getAttribute('href')).toBe('https://example.com');
});
