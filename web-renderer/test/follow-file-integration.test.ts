jest.mock('mermaid', () => ({ initialize: jest.fn(), render: jest.fn() }));
import '../src/index';
const options = {context:'quicklook' as const, followFile:true, showCopyButtons:true};
beforeEach(() => { window.setQuickLookFollow(false); document.body.innerHTML='<div id="markdown-preview"></div><div id="toc-container"></div><div id="search-container"></div>'; window.scrollTo=jest.fn(); });
test('real renderer retains paragraphs and code through repeated appends without duplicate controls', async () => {
 const content='# Heading\n\nExisting text\n\n```js\nconst x=1;\n```\n\n';
 await window.renderMarkdown(content, options);
 const root=document.getElementById('markdown-preview')!;
 window.setQuickLookFollow(true);
 await window.renderMarkdown(content,options);
 const heading=root.querySelector('h1'); const pre=root.querySelector('pre');
 await window.renderMarkdown(content+'new paragraph', options);
 expect(root.querySelector('h1')).toBe(heading); expect(root.querySelector('pre')).toBe(pre);
 await window.renderMarkdown(content+'new paragraph extended',options);
 expect(root.querySelector('pre')).toBe(pre);
 expect(root.querySelectorAll('.block-copy-tools')).toHaveLength(1);
 expect(pre?.querySelectorAll('.code-line .code-line')).toHaveLength(0);
});
test('reference appended at end updates earlier paragraph', async () => {
 await window.renderMarkdown('[link][ref]\n\n',options);
 await window.renderMarkdown('[link][ref]\n\n[ref]: https://example.com\n',options);
 expect(document.querySelector('#markdown-preview a')?.getAttribute('href')).toBe('https://example.com');
});
test('app context cannot retain Quick Look nodes', async () => {
 await window.renderMarkdown('first\n\n',options); const first=document.querySelector('#markdown-preview p');
 await window.renderMarkdown('first\n\nsecond',{...options,context:'app'});
 expect(document.querySelector('#markdown-preview p')).not.toBe(first);
});
test.each([
 ['paragraph',' extended'],
 ['- first\n','- second\n'],
 ['| a | b |\n|---|---|\n|1|2|\n','|3|4|\n'],
 ['```text\nfirst\n','second\n```\n']
])('extended ending agrees with fresh full render: %s',async (before,append) => {
 await window.renderMarkdown(before,options); await window.renderMarkdown(before+append,options);
 const root=document.getElementById('markdown-preview')!;
 const semantic=()=> { const clone=root.cloneNode(true) as HTMLElement; clone.querySelectorAll('.block-copy-tools').forEach(n=>n.remove()); return clone.textContent; };
 const updated=semantic();
 await window.renderMarkdown(before+append,{...options,followFile:false});
 expect(semantic()).toBe(updated);
});
test('selected content survives a queued render until selection clears', async () => {
 await window.renderMarkdown('selected text',options);
 const root=document.getElementById('markdown-preview')!; const paragraph=root.querySelector('p')!;
 const range=document.createRange(); range.selectNodeContents(paragraph); window.getSelection()?.addRange(range);
 const update=window.renderMarkdown('selected text\n\nnew content',options);
 await Promise.resolve(); expect(window.getSelection()?.toString()).toBe('selected text'); expect(root.querySelector('p')).toBe(paragraph);
 window.getSelection()?.removeAllRanges(); await update;
 expect(root.textContent).toContain('new content');
});
test('capability with Follow off does not retain nodes', async () => {
 await window.renderMarkdown('before\n\n', options);
 const first=document.querySelector('#markdown-preview p');
 await window.renderMarkdown('before\n\nafter',options);
 expect(document.querySelector('#markdown-preview p')).not.toBe(first);
});
test('the renderer tells the toolbar layout whether Follow is offered', async () => {
 await window.renderMarkdown('text', options);
 expect(document.documentElement.dataset.followControl).toBe('true');
 await window.renderMarkdown('text', {...options, followFile:false});
 expect(document.documentElement.dataset.followControl).toBe('false');
});
