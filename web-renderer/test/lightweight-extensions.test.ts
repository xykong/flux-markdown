jest.mock('mermaid', () => ({initialize:jest.fn(),render:jest.fn()}));
import fs from 'fs';
import path from 'path';
import '../src/index';

const corpus = fs.readFileSync(path.resolve(__dirname, '../../Tests/fixtures/issues/64/markdown-preview-test.md'), 'utf8');
const definitions = corpus.split('### 12.2 定义列表')[1].split('### 12.3')[0];
const abbreviations = corpus.split('### 12.3 缩写定义')[1].split('### 12.4')[0];
beforeEach(() => { document.body.innerHTML='<div id="markdown-preview"></div>'; });

test('renders original definition-list terms, repeated definitions and paragraphs', async () => {
    await window.renderMarkdown(definitions);
    expect(Array.from(document.querySelectorAll('dt')).map(e=>e.textContent)).toEqual(['Markdown','预览插件']);
    expect(document.querySelectorAll('dd')).toHaveLength(3);
    expect(document.querySelector('dl')?.textContent).toContain('定义中的第二个段落。');
});
test('renders original abbreviation definitions as safe titles', async () => {
    await window.renderMarkdown(abbreviations);
    expect(document.querySelector('abbr')?.getAttribute('title')).toBe('HyperText Markup Language');
    expect(Array.from(document.querySelectorAll('abbr')).map(e=>e.textContent)).toEqual(['HTML','CSS']);
    expect(document.getElementById('markdown-preview')?.textContent).not.toContain('*[HTML]:');
});
test('insertion supports nested emphasis while code and C++ stay literal', async () => {
    await window.renderMarkdown('++**插入且加粗**++\n\nC++ and `++literal++`\n\n```text\n++literal++\nHTML\n```\n\n*[HTML]: HyperText', {showLineNumbers:false});
    expect(document.querySelector('ins strong')?.textContent).toBe('插入且加粗');
    expect(document.querySelectorAll('ins')).toHaveLength(1);
    expect(document.querySelector('pre code')?.textContent).toBe('++literal++\nHTML\n');
    expect(document.querySelectorAll('code ins, code abbr')).toHaveLength(0);
    expect(document.getElementById('markdown-preview')?.textContent).toContain('C++');
});
test('abbreviations are word-bound and document-scoped', async () => {
    await window.renderMarkdown('HTML HTMLs\n\n*[HTML]: HyperText');
    expect(document.querySelectorAll('abbr')).toHaveLength(1);
    await window.renderMarkdown('HTML');
    expect(document.querySelectorAll('abbr')).toHaveLength(0);
});
test('HTML-looking tooltip definitions cannot add executable nodes', async () => {
    await window.renderMarkdown('HTML\n\n*[HTML]: <img src=x onerror=alert(1)>');
    expect(document.querySelector('abbr')?.getAttribute('title')).toBe('<img src=x onerror=alert(1)>');
    expect(document.querySelector('#markdown-preview script, #markdown-preview img, #markdown-preview [onerror]')).toBeNull();
});
test('source and HTML export preserve the intended representations', async () => {
    const source=definitions+'\n\n'+abbreviations+'\n\n++inserted++';
    await window.renderMarkdown(source);
    const exported=new DOMParser().parseFromString(window.exportHTML(),'text/html');
    expect(exported.querySelectorAll('dl, abbr, ins').length).toBeGreaterThanOrEqual(4);
    expect(exported.body.textContent).toContain('inserted');
    window.renderSource(source,'light');
    expect(document.getElementById('markdown-preview')?.textContent).toContain('*[HTML]:');
    expect(document.getElementById('markdown-preview')?.textContent).toContain('++inserted++');
});
