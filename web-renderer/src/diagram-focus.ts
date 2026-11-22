import { diagramForHost } from './diagram-zoom-controls';
import { workflowButton, workflowLabels } from './reading-workflow-ui';
import { captureReadingState, restoreReadingState, saveReadingState } from './reading-state';
let closeCurrent: (()=>void) | undefined;
export function stepFocusedDiagram(delta: number | null): boolean {
    const host=document.querySelector('#diagram-focus .mermaid,#diagram-focus .svg-image-diagram');
    const entry=diagramForHost(host);
    if(!entry)return false;
    entry.controls.setFactor(delta===null?1:entry.controls.factor*Math.pow(1.25,delta*10));return true;
}
export function scrollReadingSurface(x:number,y:number): void {
    const stage=document.querySelector<HTMLElement>('#diagram-focus .focus-stage');
    if(stage)stage.scrollBy(x,y);else window.scrollBy(x,y);
}
export function closeDiagramFocus(): void { closeCurrent?.(); }
export function openDiagramFocus(host: HTMLElement): boolean {
    closeCurrent?.();
    const entry=diagramForHost(host);
    if(!entry || !host.isConnected)return false;
    saveReadingState();
    const state=captureReadingState(), factor=entry.controls.factor;
    const previousFocus=document.activeElement as HTMLElement | null;
    const placeholder=document.createComment('diagram-focus');host.before(placeholder);
    const dialog=document.createElement('section');dialog.id='diagram-focus';dialog.setAttribute('role','dialog');dialog.setAttribute('aria-modal','true');
    const s=workflowLabels();dialog.setAttribute('aria-label',s.focus);
    const toolbar=document.createElement('div');toolbar.className='focus-toolbar';
    const stage=document.createElement('div');stage.className='focus-stage';stage.tabIndex=0;stage.setAttribute('aria-label',s.diagram);
    const fit=()=>{
        entry.controls.setFactor(1);
        const box=entry.drawing.getBoundingClientRect();
        entry.controls.setFactor(Math.min(1,(stage.clientWidth-32)/Math.max(1,box.width),(stage.clientHeight-44)/Math.max(1,box.height)));
        stage.scrollTo(0,0);
    };
    const close=workflowButton(s.close,()=>closeCurrent?.());
    toolbar.append(workflowButton(s.fit,fit),workflowButton(s.actual,()=>entry.controls.setFactor(1)));
    for(const [action,label] of [['copy',s.copy],['png',s.png],['svg',s.svg]])toolbar.append(workflowButton(label,()=>window.dispatchEvent(new CustomEvent('diagramAction',{detail:{host,action}}))));
    toolbar.append(close);dialog.append(toolbar,stage);document.body.append(dialog);stage.append(host);
    const hidden=Array.from(document.body.children).filter(el=>el!==dialog && el.id!=='zoom-feedback').map(el=>({el,value:el.getAttribute('aria-hidden')}));
    hidden.forEach(({el})=>el.setAttribute('aria-hidden','true'));
    const overflow=document.body.style.overflow;document.body.style.overflow='hidden';
    const key=(event:KeyboardEvent)=>{
        if(event.key==='Escape' && document.documentElement.dataset.context==='app'){event.preventDefault();event.stopImmediatePropagation();closeCurrent?.();}
        if(event.key==='Tab'){
            const buttons=Array.from(dialog.querySelectorAll<HTMLElement>('button,summary,[tabindex="0"]')).filter(el=>el.getClientRects().length>0);
            const first=buttons[0],last=buttons[buttons.length-1];
            if(event.shiftKey && document.activeElement===first){event.preventDefault();last?.focus();}
            else if(!event.shiftKey && document.activeElement===last){event.preventDefault();first?.focus();}
        }
    };
    document.addEventListener('keydown',key,true);
    closeCurrent=()=>{
        closeCurrent=undefined;document.removeEventListener('keydown',key,true);
        if(placeholder.isConnected)placeholder.replaceWith(host);
        entry.controls.setFactor(factor);dialog.remove();document.body.style.overflow=overflow;
        hidden.forEach(({el,value})=>{if(value===null)el.removeAttribute('aria-hidden');else el.setAttribute('aria-hidden',value);});
        restoreReadingState(state);
        if(previousFocus?.isConnected)previousFocus.focus({preventScroll:true});
        else host.querySelector<HTMLElement>('[data-diagram-action="focus"]')?.focus({preventScroll:true});
    };
    fit();close.focus({preventScroll:true});return true;
}
window.addEventListener('focusDiagram',event=>openDiagramFocus((event as CustomEvent<{host:HTMLElement}>).detail.host));
