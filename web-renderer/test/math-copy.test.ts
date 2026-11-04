import { TextEncoder } from 'util';
Object.assign(globalThis,{TextEncoder});
jest.mock('mermaid',()=>({initialize:jest.fn(),render:jest.fn()}));
import '../src/index';
import { installBlockCopy, blockPlainText } from '../src/block-copy';

beforeEach(()=>{ document.body.innerHTML='<div id="markdown-preview"></div>'; });
test('copies exact inline and fenced math source through the existing copy controller',async()=>{
    const inline=String.raw`\(\frac{x}{2}\)`;
    const fence='```math\n'+String.raw`x^2\tag{1}`+'\n```';
    await window.renderMarkdown(inline+'\n\n'+fence,{showCopyButtons:false});
    const root=document.getElementById('markdown-preview')!;
    const formulas=Array.from(root.querySelectorAll<HTMLElement>('.flux-math-source'));
    const send=jest.fn(async()=>true);
    const controller=installBlockCopy(root,'math-copy',send);
    expect(root.querySelectorAll('.block-copy-tools')).toHaveLength(2);
    await controller.copy(formulas[0]);
    expect(send).toHaveBeenLastCalledWith(expect.objectContaining({text:inline}));
    await controller.copy(formulas[1]);
    expect(send).toHaveBeenLastCalledWith(expect.objectContaining({text:fence}));
    expect(blockPlainText(formulas[0])).toBe(inline);
    controller.dispose();
});
test('copying a quote includes math source once and failure exposes selectable source',async()=>{
    const math=String.raw`\(x^2\)`;
    await window.renderMarkdown('> Formula '+math,{showCopyButtons:false});
    const root=document.getElementById('markdown-preview')!;
    expect(blockPlainText(root.querySelector('blockquote')!)).toBe('Formula '+math);
    const controller=installBlockCopy(root,'failure',async()=>false);
    const formula=root.querySelector<HTMLElement>('.flux-math-source')!;
    await controller.copy(formula);
    const source=root.querySelector<HTMLTextAreaElement>('.math-copy-source');
    expect(source?.value).toBe(math);
    expect(source?.readOnly).toBe(true);
    expect(formula.querySelector('svg')).not.toBeNull();
    controller.dispose();
});
