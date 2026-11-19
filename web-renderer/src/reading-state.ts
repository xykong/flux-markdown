import { readingRect } from './reading-geometry';
import { setReadingZoom } from './reading-zoom';
import { feedbackGeneration } from './error-feedback';
import { workflowButton, workflowLabels } from './reading-workflow-ui';

export interface ReadingState { id: string; hash: string; index: number; top: number; scrollY: number; zoom: number }
let documentId='';
let history: ReadingState[]=[];
let cursor=-1;
let restoring=false;
let rendering=false;
let renderAnchor: ReadingState | undefined;
let saveTimer: ReturnType<typeof setTimeout> | undefined;
let nativeHistory=false;
function blocks(): HTMLElement[] { return Array.from(document.getElementById('markdown-preview')?.children || []).filter((el): el is HTMLElement=>el instanceof HTMLElement); }
function fingerprint(element: HTMLElement): string {
    let text='';
    const walker=document.createTreeWalker(element,NodeFilter.SHOW_TEXT,{acceptNode:node=>node.parentElement?.closest('style,script,.diagram-tools,.block-copy-tools,.error-feedback-controls')?NodeFilter.FILTER_REJECT:NodeFilter.FILTER_ACCEPT});
    let node:Node | null;
    while(text.length<4096 && (node=walker.nextNode()))text+=' '+node.textContent;
    let value=2166136261;
    for(const c of text.replace(/\s+/g,' ').trim().slice(0,4096))value=Math.imul(value^c.charCodeAt(0),16777619);
    return (value>>>0).toString(16);
}
export function captureReadingState(): ReadingState {
    const root=document.getElementById('markdown-preview');
    const list=blocks();
    const rect=root && readingRect(root);
    const top=Math.max(80,document.getElementById('reading-controls')?.getBoundingClientRect().bottom || 0)+8;
    let element=rect && document.elementFromPoint?.(Math.max(2,rect.left)+Math.min(rect.width,innerWidth-Math.max(2,rect.left))/2,Math.min(top,innerHeight-2));
    while(element?.parentElement && element.parentElement!==root)element=element.parentElement;
    const target=list.find(el=>el===element) || list.find(el=>readingRect(el).bottom>top) || list[0];
    return {id:target?.id || '',hash:target?fingerprint(target):'',index:Math.max(0,list.indexOf(target)),top:(target && readingRect(target).top) || 0,scrollY:window.scrollY,zoom:parseFloat(root?.style.getPropertyValue('zoom') || '') || 1};
}
/**
 * A scroll made while Quick Look shows or resizes the preview can reach the page but not
 * the screen: clicks then land a line or two away from the text under the pointer.
 * A real one-pixel scroll and back makes the screen take the page's position again.
 */
export function resyncScrollPosition(): void {
    const y=window.scrollY, x=window.scrollX;
    window.scrollTo({top:y>0?y-1:y+1,left:x,behavior:'instant' as ScrollBehavior});
    requestAnimationFrame(()=>window.scrollTo({top:y,left:x,behavior:'instant' as ScrollBehavior}));
}
export function restoreReadingState(state: ReadingState): boolean {
    if(!state || !Number.isFinite(state.zoom) || !Number.isFinite(state.top) || !Number.isInteger(state.index))return false;
    restoring=true;
    setReadingZoom(state.zoom);
    const root=document.getElementById('markdown-preview'), list=blocks();
    const byID=state.id?document.getElementById(state.id):null;
    const matches=list.filter(el=>fingerprint(el)===state.hash);
    matches.sort((a,b)=>Math.abs(list.indexOf(a)-state.index)-Math.abs(list.indexOf(b)-state.index));
    const target=byID && root?.contains(byID)?byID:matches[0] || list[Math.max(0,Math.min(list.length-1,state.index))];
    if(target)window.scrollBy({top:readingRect(target).top-state.top,left:0,behavior:'instant' as ScrollBehavior});
    else window.scrollTo({top:state.scrollY || 0,left:0,behavior:'instant' as ScrollBehavior});
    restoring=false;
    requestAnimationFrame(()=>requestAnimationFrame(resyncScrollPosition));
    window.dispatchEvent(new Event('scroll'));
    saveReadingState();return true;
}
function post(action: string, extra: Record<string,unknown>={}): boolean {
    const bridge=window.webkit?.messageHandlers.readingJourney;
    if(!bridge || !documentId)return false;
    bridge.postMessage({action,generation:feedbackGeneration(),documentId,...extra});return true;
}
export function saveReadingState(): void {
    if(!restoring && !rendering && !document.getElementById('diagram-focus') && document.getElementById('markdown-preview')?.childElementCount)post('save',{state:captureReadingState()});
}
window.addEventListener('scroll',()=>{clearTimeout(saveTimer);saveTimer=setTimeout(saveReadingState,200);},{passive:true});
window.addEventListener('pagehide',saveReadingState);
window.addEventListener('readingZoomChanged',()=>{clearTimeout(saveTimer);saveTimer=setTimeout(saveReadingState,200);});
export function beginReadingRender(nextId?: string): ReadingState | undefined {
    const sameDocument=!!nextId && nextId===documentId;
    // A superseded render has only a partial tree. Carry the last completed
    // reading anchor through it instead of replacing durable state with its top.
    if(!sameDocument)renderAnchor=undefined;
    else if(!rendering && blocks().length)renderAnchor=captureReadingState();
    if(nextId && !sameDocument){history=[];cursor=-1;window.scrollTo({top:0,left:0,behavior:'instant' as ScrollBehavior});}
    documentId=nextId || '';
    rendering=true;
    return renderAnchor;
}
export function finishReadingRender(saved?: ReadingState, preserved?: ReadingState): void {
    rendering=false;renderAnchor=undefined;
    if(preserved || saved)restoreReadingState(preserved || saved);
    installNavigation();saveReadingState();
}
function same(a: ReadingState,b: ReadingState): boolean {return a.id===b.id && a.hash===b.hash && a.zoom===b.zoom && Math.abs(a.top-b.top)<3;}
export function recordReadingJump(before: ReadingState, after: ReadingState): void {
    if(same(before,after))return;
    if(post('jump',{before,after}))return;
    if(cursor<0){history=[before];cursor=0;}else history[cursor]=before;
    history.splice(cursor+1);history.push(after);if(history.length>100)history.shift();cursor=history.length-1;updateNavigation();
}
export function jumpToReadingTarget(target: Element): void {
    const before=captureReadingState();
    const list=blocks();
    let block:Element=target;
    while(block.parentElement && block.parentElement.id!=='markdown-preview')block=block.parentElement;
    const zoom=before.zoom;
    const margin=(parseFloat(getComputedStyle(target).scrollMarginTop) || 0)*zoom;
    const delta=readingRect(target).top-margin;
    const after:ReadingState={id:block.id,hash:fingerprint(block as HTMLElement),index:Math.max(0,list.indexOf(block as HTMLElement)),top:readingRect(block).top-delta,scrollY:Math.max(0,window.scrollY+delta),zoom};
    const reduced=window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    target.scrollIntoView({behavior:reduced?'auto':'smooth',block:'start'});
    recordReadingJump(before,after);
}
export function navigateReadingHistory(direction: number): void {
    if(post('navigate',{direction,state:captureReadingState()}))return;
    const next=cursor+(direction<0?-1:1);
    if(next<0 || next>=history.length)return;
    history[cursor]=captureReadingState();cursor=next;restoreReadingState(history[cursor]);updateNavigation();
}
export function updateNavigation(back?: boolean, forward?: boolean): void {
    if(back!==undefined)nativeHistory=true;
    const nav=document.getElementById('reading-navigation');
    const buttons=nav?.querySelectorAll('button');
    if(buttons){buttons[0].disabled=back===undefined ? cursor<=0 : !back;buttons[1].disabled=forward===undefined ? cursor<0 || cursor>=history.length-1 : !forward;}
}
function installNavigation(): void {
    if(document.documentElement.dataset.context!=='app')return;
    let nav=document.getElementById('reading-navigation');
    if(!nav){nav=document.createElement('span');nav.id='reading-navigation';const s=workflowLabels();nav.append(workflowButton('←',()=>navigateReadingHistory(-1)),workflowButton('→',()=>navigateReadingHistory(1)));const buttons=nav.querySelectorAll('button');buttons[0].title=s.back;buttons[0].setAttribute('aria-label',s.back);buttons[1].title=s.forward;buttons[1].setAttribute('aria-label',s.forward);document.getElementById('reading-toolbar')?.prepend(nav);if(!nav.isConnected)document.getElementById('reading-controls')?.prepend(nav);}
    if(!nativeHistory)updateNavigation();post('availability');
}
document.addEventListener('keydown',event=>{
    if(document.documentElement.dataset.context==='app' && event.metaKey && !event.altKey && ['[',']'].includes(event.key)){
        event.preventDefault();navigateReadingHistory(event.key==='['?-1:1);
    }
});
