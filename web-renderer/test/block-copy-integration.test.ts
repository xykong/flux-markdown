jest.mock('mermaid', () => ({ initialize: jest.fn(), render: jest.fn() }));
import '../src/index';
import { blockPlainText } from '../src/block-copy';
import { SearchEngine } from '../src/search';

beforeEach(() => { document.body.innerHTML = '<div id="markdown-preview"></div><div id="toc-container"></div><div id="search-container"></div>'; });
const markdown = '```sh\n\techo "中文 & 😀"\n\n```\n\n> Quote\n>\n> > Nested\n>\n> ```\n> x\n> ```';

test('default off, app/Quick Look on, compact/source off, and setting changes cleanly', async () => {
    await window.renderMarkdown(markdown, {context:'app'});
    expect(document.querySelector('.block-copy-tools')).toBeNull();
    for (const context of ['app', 'quicklook'] as const) {
        await window.renderMarkdown(markdown, {context, showCopyButtons:true, showLineNumbers:true});
        expect(document.querySelectorAll('.block-copy-tools')).toHaveLength(4);
        expect(blockPlainText(document.querySelector('pre')!)).toBe('\techo "中文 & 😀"\n\n');
        expect(blockPlainText(document.querySelector('blockquote')!)).toBe('Quote\n\nNested\n\nx\n');
    }
    await window.renderMarkdown(markdown, {context:'finder',showCopyButtons:true});
    expect(document.querySelector('.block-copy-tools')).toBeNull();
    await window.renderMarkdown(markdown, {context:'app',showCopyButtons:true});
    await window.renderMarkdown(markdown, {context:'app',showCopyButtons:false});
    expect(document.querySelector('.block-copy-host')).toBeNull();
    window.renderSource(markdown, 'light');
    expect(document.querySelector('.block-copy-tools')).toBeNull();
});

test('export retains content without control markup and live document stays intact', async () => {
    await window.renderMarkdown(markdown, {context:'app',showCopyButtons:true,showLineNumbers:false});
    const exported = new DOMParser().parseFromString(window.exportHTML(), 'text/html');
    expect(exported.querySelector('.block-copy-tools, .block-copy-host')).toBeNull();
    expect(exported.querySelector('code')!.textContent).toBe('\techo "中文 & 😀"\n\n');
    expect(document.querySelectorAll('.block-copy-tools')).toHaveLength(4);
});

test('search does not match copy controls or success messages', async () => {
    await window.renderMarkdown('```\nhello\n```', {context:'app',showCopyButtons:true,uiLanguage:'en'});
    document.querySelector('[role=status]')!.textContent = 'Copied';
    const engine = new SearchEngine();
    expect(engine.search('Copied', {caseSensitive:false, wholeWord:false, useRegex:false})).toBe(0);
});

test('disabled diagram rendering exposes ordinary code for copying', async () => {
    await window.renderMarkdown('```mermaid\ngraph TD; A-->B\n```\n\n```typst\nx+y\n```\n\n```dotnet\nhello\n```',
        {context:'app', showCopyButtons:true, enableMermaid:false, enableTypst:false});
    expect(document.querySelectorAll('.block-copy-tools')).toHaveLength(3);
});
