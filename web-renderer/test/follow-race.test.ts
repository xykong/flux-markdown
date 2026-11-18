jest.mock('mermaid', () => ({initialize:jest.fn(),render:jest.fn()}));
const mockMathRender=jest.fn();
jest.mock('../src/math-engine',()=>({renderMathSources:(...args:unknown[])=>mockMathRender(...args)}));
import '../src/index';
import { waitForSafeCommit } from '../src/follow-file';

beforeEach(()=>{document.body.innerHTML='<div id="markdown-preview"></div><div id="toc-container"></div><div id="search-container"></div>';Range.prototype.getClientRects=jest.fn(()=>[] as unknown as DOMRectList);window.scrollTo=jest.fn();window.getSelection()?.removeAllRanges();});
test('selection starting during async preparation keeps old copy controls until commit',async()=>{
 const options={context:'quicklook' as const,followFile:true,showCopyButtons:true};
 await window.renderMarkdown('existing **selection**\n\n```\ncode\n```',options);
 const root=document.getElementById('markdown-preview')!;
 const old=root.querySelector('strong')!;const control=root.querySelector('.block-copy-tools');
 let release:()=>void=()=>{};let entered:()=>void=()=>{};
 const preparing=new Promise<void>(resolve=>{entered=resolve;});
 mockMathRender.mockImplementation(async()=>{entered();await new Promise<void>(resolve=>{release=resolve;});return {css:'',items:[],errors:[]};});
 const update=window.renderMarkdown('replacement $x$',options);
 await preparing;
 const range=document.createRange();range.selectNodeContents(old);window.getSelection()?.addRange(range);
 release();await new Promise(resolve=>setTimeout(resolve,20));
 expect(root.querySelector('strong')).toBe(old);expect(window.getSelection()?.toString()).toBe('selection');
 expect(root.querySelector('.block-copy-tools')).toBe(control);
 window.getSelection()?.removeAllRanges();await update;
 expect(root.textContent).toContain('replacement');
});
test('pending clipboard acknowledgement holds commit and cancellation releases stale update',async()=>{
 const root=document.getElementById('markdown-preview')!;
 root.innerHTML='<div data-copy-state="pending">copy</div>';
 let current=true;let completed=false;
 const waiting=waitForSafeCommit(root,()=>current).then(value=>{completed=true;return value;});
 await Promise.resolve();expect(completed).toBe(false);
 current=false;expect(await waiting).toBe(false);
});
test('document replacement cancels a selected old document instead of waiting forever',async()=>{
 const options={context:'quicklook' as const,followFile:true,documentGeneration:'first'};
 await window.renderMarkdown('old selected',options);
 const root=document.getElementById('markdown-preview')!;const range=document.createRange();range.selectNodeContents(root.querySelector('p')!);window.getSelection()?.addRange(range);
 await window.renderMarkdown('new document',{...options,documentGeneration:'second'});
 expect(root.textContent).toContain('new document');
});
