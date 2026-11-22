import { diagramForHost } from './diagram-zoom-controls';
import { feedbackGeneration } from './error-feedback';
import { sanitizeDiagramHTML } from './safe-html';
import { workflowLabels, showWorkflowStatus } from './reading-workflow-ui';
let nextID=0;
const completed=new Map<string,string>();
const pending=new Map<string,{host:Element;action:string;generation:string}>();
export function diagramSVG(host: Element): string {
    const entry=diagramForHost(host);
    if(!entry)throw new Error('diagram unavailable');
    let svg: SVGSVGElement;
    if(entry.drawing instanceof SVGSVGElement) {
        svg=entry.drawing.cloneNode(true) as SVGSVGElement;
        const originals=[entry.drawing,...Array.from(entry.drawing.querySelectorAll('*'))];
        const clones=[svg,...Array.from(svg.querySelectorAll('*'))];
        const properties=['font-family','font-size','font-weight','font-style','color','fill','stroke','stroke-width','stroke-dasharray','opacity','text-anchor','dominant-baseline','display','white-space','line-height','padding','margin','background-color','border-radius','box-sizing','filter','marker-start','marker-mid','marker-end','stop-color','stop-opacity','stroke-linecap','stroke-linejoin'];
        originals.forEach((node,index)=>{
            const style=getComputedStyle(node), clone=clones[index] as SVGElement;
            for(const property of properties){const value=style.getPropertyValue(property);if(value)clone.style.setProperty(property,value.replace(/url\(["']?[^)"']*#([^)"']+)["']?\)/g,'url(#$1)'));}
        });
    } else {
        const source=(entry.drawing as HTMLImageElement).currentSrc || (entry.drawing as HTMLImageElement).src;
        if(!/^data:image\/svg\+xml[;,]/i.test(source))throw new Error('SVG source unavailable');
        const comma=source.indexOf(',');
        const xml=/;base64$/i.test(source.slice(0,comma))?new TextDecoder().decode(Uint8Array.from(atob(source.slice(comma+1)),c=>c.charCodeAt(0))):decodeURIComponent(source.slice(comma+1));
        const parsed=new DOMParser().parseFromString(sanitizeDiagramHTML(xml),'image/svg+xml');
        if(parsed.querySelector('parsererror') || parsed.documentElement.localName!=='svg')throw new Error('SVG unavailable');
        svg=parsed.documentElement as unknown as SVGSVGElement;
    }
    const box=(svg.getAttribute('viewBox') || '').trim().split(/[ ,]+/).map(Number);
    const width=box.length===4?box[2]:Number(svg.getAttribute('width'));
    const height=box.length===4?box[3]:Number(svg.getAttribute('height'));
    if(!Number.isFinite(width) || !Number.isFinite(height) || width<=0 || height<=0)throw new Error('diagram dimensions unavailable');
    svg.setAttribute('xmlns','http://www.w3.org/2000/svg');svg.setAttribute('width',String(width));svg.setAttribute('height',String(height));
    svg.style.width=width+'px';svg.style.height=height+'px';svg.style.maxWidth='none';svg.style.margin='0';svg.style.display='block';
    svg.style.backgroundColor=getComputedStyle(document.body).backgroundColor;
    const result=new XMLSerializer().serializeToString(svg);
    if(new TextEncoder().encode(result).length>8*1024*1024)throw new Error('diagram export budget exceeded');
    return result;
}
export function requestDiagramAction(host: Element,action: string): void {
    if(!['copy','png','svg'].includes(action))return;
    const bridge=window.webkit?.messageHandlers.diagramAction;
    if(!bridge)return;
    const id=String(++nextID), generation=feedbackGeneration();
    if(Array.from(pending.values()).some(value=>value.host===host))return;
    pending.set(id,{host,action,generation});showWorkflowStatus(workflowLabels().preparing);
    try {bridge.postMessage({id,generation,action,svg:diagramSVG(host)});}
    catch {bridge.postMessage({id,generation,action,svg:''});}
}
export function diagramActionResult(id: string,generation:string,status:string): void {
    const request=pending.get(id);
    if((!request && completed.get(id)!==generation) || (request && request.generation!==generation))return;
    pending.delete(id);completed.set(id,generation);
    while(completed.size>100)completed.delete(completed.keys().next().value);
    if(generation!==feedbackGeneration())return;
    const s=workflowLabels();
    if(status==='copied')showWorkflowStatus(s.copied);
    else if(status==='saved')showWorkflowStatus(s.saved);
    else if(status==='cancelled')showWorkflowStatus(s.cancelled);
    else if(status==='openApp')showWorkflowStatus(s.openApp);
}
window.addEventListener('diagramAction',event=>{const {host,action}=(event as CustomEvent<{host:Element;action:string}>).detail;requestDiagramAction(host,action);});
