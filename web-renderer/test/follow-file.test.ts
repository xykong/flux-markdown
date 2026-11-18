beforeEach(() => { window.scrollTo = jest.fn(); });
import { FollowFile, blockElement, lastBlockLine, lineStart, uniqueHeadingSlug } from '../src/follow-file';
test('finds the final block by source line, through a copy-control wrapper', () => {
 const root=document.createElement('div');
 root.innerHTML='<p data-source-line="1">a</p>\n<div class="block-copy-host"><div class="block-copy-tools"></div><pre data-source-line="3"></pre></div>\n';
 expect(blockElement(root,3)).toBe(root.querySelector('.block-copy-host'));
 expect(blockElement(root,1)).toBeUndefined();
 root.insertAdjacentHTML('beforeend','<div>untracked</div>');
 expect(blockElement(root,3)).toBe(root.querySelector('.block-copy-host'));
});
test('line starts and the last top-level block', () => {
 expect(lineStart('a\nb\r\nc',0)).toBe(0); expect(lineStart('a\nb\r\nc',2)).toBe(5); expect(lineStart('a',3)).toBe(-1);
 expect(lastBlockLine([{level:0,nesting:1,map:[0,2]},{level:1,nesting:0,map:[0,1]},{level:0,nesting:-1,map:null},{level:0,nesting:0,map:[4,5]}])).toBe(4);
 expect(lastBlockLine([])).toBeUndefined();
});
test('heading slugs continue the numbering of blocks parsed earlier', () => {
 const env={headingSlugs:new Set(['intro','intro-1'])};
 expect(uniqueHeadingSlug('intro',env)).toBe('intro-2'); expect(uniqueHeadingSlug('other',env)).toBe('other');
 expect(uniqueHeadingSlug('intro',{})).toBe('intro');
});
test('pauses for user navigation and resumes explicitly', () => {
 const root=document.createElement('div'); const follow=new FollowFile(root);
 follow.set(true); expect(follow.status().active).toBe(true);
 window.dispatchEvent(new WheelEvent('wheel',{deltaY:-10})); expect(follow.status().paused).toBe(true);
 follow.set(true); expect(follow.status().paused).toBe(false);
 follow.set(false); expect(follow.status().active).toBe(false); follow.dispose();
});
test('selection pauses and defers updates', () => {
 const root=document.createElement('div'); root.textContent='select me'; document.body.append(root);
 const follow=new FollowFile(root); follow.set(true);
 const range=document.createRange(); range.selectNodeContents(root); window.getSelection()?.addRange(range);
 expect(follow.status()).toMatchObject({paused:true,selected:true});
 follow.dispose(); window.getSelection()?.removeAllRanges(); root.remove();
});
test('scrollbar pointer pauses Follow', () => {
 const follow=new FollowFile(document.createElement('div')); follow.set(true);
 document.documentElement.dispatchEvent(new MouseEvent('pointerdown',{bubbles:true,clientX:innerWidth-1}));
 expect(follow.status().paused).toBe(true); follow.dispose();
});
test('layout scroll events do not impersonate deliberate navigation', () => {
 const follow=new FollowFile(document.createElement('div'));follow.set(true);
 // WebKit can clamp/re-anchor the viewport while replacing a growing suffix.
 Object.defineProperty(window,'scrollY',{configurable:true,value:120});
 try {
  window.dispatchEvent(new Event('scroll'));
  expect(follow.status().paused).toBe(false);
 } finally {follow.dispose();Object.defineProperty(window,'scrollY',{configurable:true,value:0});}
});
test.each(['ArrowUp','PageUp','Home','End','Tab',' '])('navigation key %s still pauses', key => {
 const follow=new FollowFile(document.createElement('div'));follow.set(true);
 try {window.dispatchEvent(new KeyboardEvent('keydown',{key}));expect(follow.status().paused).toBe(true);}
 finally {follow.dispose();}
});
test('touch navigation still pauses', () => {
 const follow=new FollowFile(document.createElement('div'));follow.set(true);
 try {window.dispatchEvent(new Event('touchmove'));expect(follow.status().paused).toBe(true);}
 finally {follow.dispose();}
});
test('paused position follows a source block when layout above changes', () => {
 const root=document.createElement('div');root.innerHTML='<p data-source-line="1">first</p><p data-source-line="3">reading</p>';document.body.append(root);
 const reading=root.lastElementChild!;
 const rect=(top:number)=>({top,bottom:top+20,left:0,right:100,width:100,height:20,x:0,y:top,toJSON(){return {};}});
 reading.getBoundingClientRect=()=>rect(20);
 const follow=new FollowFile(root);follow.set(true);window.dispatchEvent(new WheelEvent('wheel'));
 follow.captureAnchor();reading.getBoundingClientRect=()=>rect(120);
 follow.restoreAnchor();expect(window.scrollTo).toHaveBeenLastCalledWith(0,100);
 follow.dispose();root.remove();
});
