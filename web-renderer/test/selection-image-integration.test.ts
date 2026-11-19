jest.mock('mermaid', () => ({ initialize: jest.fn(), render: jest.fn() }));
import '../src/index';
import { selectedContent } from '../src/selection-content';

beforeEach(() => { document.body.innerHTML = '<div id="markdown-preview"></div><div id="toc-container"></div><div id="search-container"></div>'; });
/** From the second character to the end: a partly selected block is converted, not copied as source. */
function fromSecondCharacter(root: HTMLElement): Range {
    const range = document.createRange(); range.selectNodeContents(root);
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    range.setStart(walker.nextNode()!, 1);
    return range;
}

test.each(['![diagram](./images/picture.png)', '<img alt="diagram" src="./images/picture.png">'])(
    'renderer preserves the original relative path through embedding: %s', async image => {
        const data = 'data:image/png;base64,' + 'A'.repeat(201);
        await window.renderMarkdown('text ' + image, {context:'quicklook',imageData:{'./images/picture.png':data}});
        const root = document.getElementById('markdown-preview')!;
        expect(root.querySelector('img')?.getAttribute('src')).toBe(data);
        expect(selectedContent(root,fromSecondCharacter(root),'markdown')).toBe('ext ![diagram](./images/picture.png)');
        const whole = document.createRange(); whole.selectNodeContents(root);
        expect(selectedContent(root,whole,'markdown')).toBe('text ' + image);
    });

test('literal embedded images without a source path are omitted from converted Markdown', async () => {
    await window.renderMarkdown('before ![diagram](data:image/png;base64,' + 'A'.repeat(201) + ') after', {context:'quicklook'});
    const root = document.getElementById('markdown-preview')!;
    expect(selectedContent(root,fromSecondCharacter(root),'markdown')).toBe('efore after');
});

test('a rendered Mermaid diagram keeps its source for Markdown copies', async () => {
    await window.renderMarkdown('before\n\n```mermaid\ngraph TD\n  A-->B\n```\n\nafter', {context:'quicklook'});
    const root = document.getElementById('markdown-preview')!;
    const range = document.createRange(); range.selectNodeContents(root);
    expect(selectedContent(root,range,'markdown')).toContain('```mermaid\ngraph TD\n  A-->B\n```');
});

test('selecting a whole rendered document copies its Markdown source', async () => {
    const source = '# Title\n\n- [ ] task\n- [x] done\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n```mermaid\ngraph TD\n  A-->B\n```\n\n> [!NOTE]\n> careful\n\n```js\nconst x = 1;\n```';
    await window.renderMarkdown(source, {context:'quicklook'});
    const root = document.getElementById('markdown-preview')!;
    const range = document.createRange(); range.selectNodeContents(root);
    expect(selectedContent(root,range,'markdown')).toBe(source);
});
