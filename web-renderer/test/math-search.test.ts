jest.mock('mermaid', () => ({initialize: jest.fn(), render: jest.fn()}));
import '../src/index';
import { SearchEngine } from '../src/search';
const options={caseSensitive:false,wholeWord:false,useRegex:false};
beforeEach(()=>{
    document.body.innerHTML='<div id="markdown-preview"></div>';
    HTMLElement.prototype.scrollIntoView=jest.fn();
});
test('searches original TeX once per formula without altering SVG or assistive MathML',async()=>{
    await window.renderMarkdown(String.raw`\(\frac{x}{x}\)`);
    const root=document.querySelector('.flux-math')!;
    const original=root.innerHTML;
    const search=new SearchEngine();
    expect(search.search('frac',options)).toBe(1);
    expect(root.classList.contains('math-search-highlight')).toBe(true);
    expect(root.innerHTML).toBe(original);
    search.clear();
    expect(root.innerHTML).toBe(original);
    expect(root.classList.contains('math-search-highlight')).toBe(false);
    expect(search.search('x',options)).toBe(1);
});
test('keeps math and prose matches in document order and export omits highlights',async()=>{
    await window.renderMarkdown('before x\n\n$x$\n\nafter x');
    const search=new SearchEngine();
    expect(search.search('x',options)).toBe(3);
    search.next();
    expect(document.querySelector('.flux-math')?.classList.contains('search-highlight-active')).toBe(true);
    expect(window.exportHTML()).not.toContain('class="flux-math-source flux-math math-search-highlight');
    expect(window.exportHTML()).not.toContain('search-highlight-active"');
});
