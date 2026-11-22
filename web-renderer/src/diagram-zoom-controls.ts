import { showZoomFeedback, workflowButton, workflowLabels } from './reading-workflow-ui';
const labels: Record<string, [string, string, string]> = {
    en: ['Zoom out diagram', 'Reset diagram zoom', 'Zoom in diagram'],
    zh: ['缩小图表', '还原图表缩放', '放大图表'],
    de: ['Diagramm verkleinern', 'Diagrammzoom zurücksetzen', 'Diagramm vergrößern'],
    fr: ['Réduire le diagramme', 'Réinitialiser le zoom du diagramme', 'Agrandir le diagramme'],
    es: ['Alejar diagrama', 'Restablecer zoom del diagrama', 'Acercar diagrama'],
    ar: ['تصغير المخطط', 'إعادة تعيين تكبير المخطط', 'تكبير المخطط'],
};


/** Shared interaction, bounds and labels for rendered and referenced diagrams. */
export function createDiagramZoomControls(className: string, changed: () => void) {
    const strings = labels[(window.__fluxLang || navigator.language).split('-')[0]] || labels.en;
    const element = document.createElement('span'); element.className = `diagram-tools ${className}`;
    let factor = 1, ready = true, disposed = false;
    const minimum = Math.pow(1.25, -8), maximum = Math.pow(1.25, 8);
    const buttons = strings.map((label, index) => {
        const button = document.createElement('button'); button.type = 'button';
        button.title = label; button.setAttribute('aria-label', label);
        button.dataset.diagramZoom = ['out','reset','in'][index];
        button.textContent = ['−', '100%', '+'][index]; element.append(button); return button;
    });
    const currentMinimum=()=>element.closest('#diagram-focus') ? 0.001 : minimum;
    function update(): void {
        buttons[0].disabled = !ready || factor <= currentMinimum() + 1e-8;
        buttons[1].disabled = !ready;
        buttons[2].disabled = !ready || factor >= maximum - 1e-8;
        buttons[1].textContent = `${Math.round(factor * 100)}%`;
    }
    function setFactor(value: number): void {
        if (!Number.isFinite(value) || !ready || disposed) return;
        factor = Math.max(currentMinimum(), Math.min(maximum, value));
        update(); changed(); showZoomFeedback(factor, 'diagram');
    }
    const handlers = buttons.map((_button, index) => (event: MouseEvent) => {
        event.preventDefault(); event.stopPropagation();
        if (disposed || !ready) return;
        setFactor(index === 1 ? 1 : factor * (index === 0 ? 1 / 1.25 : 1.25));
    });
    buttons.forEach((button, index) => button.addEventListener('click', handlers[index]));
    return {
        element,
        get factor(): number { return factor; },
        setFactor,
        setReady(value: boolean): void { ready = value; update(); },
        dispose(): void {
            disposed = true;
            buttons.forEach((button, index) => button.removeEventListener('click', handlers[index]));
            element.remove();
        },
    };
}

export type DiagramZoomControls = ReturnType<typeof createDiagramZoomControls>;
const diagramControls = new WeakMap<Element, DiagramZoomControls>();
export function registerDiagramZoom(host: Element, controls: DiagramZoomControls): void {
    diagramControls.set(host, controls);
    const s=workflowLabels();
    const focus=workflowButton('⛶',()=>window.dispatchEvent(new CustomEvent('focusDiagram',{detail:{host}})));
    focus.title=s.focus;focus.setAttribute('aria-label',s.focus);focus.dataset.diagramAction='focus';
    const menu=document.createElement('details');menu.className='diagram-export-menu';
    const summary=document.createElement('summary');summary.textContent='⋯';summary.setAttribute('aria-label',s.copy+' / '+s.png+' / '+s.svg);const options=document.createElement('div');options.className='diagram-export-options';menu.append(summary,options);
    for(const [action,label] of [['copy',s.copy],['png',s.png],['svg',s.svg]]) {
        const button=workflowButton(label,()=>{menu.open=false;window.dispatchEvent(new CustomEvent('diagramAction',{detail:{host,action}}));});
        button.dataset.diagramAction=action;options.append(button);
    }
    controls.element.append(focus,menu);
}
export function diagramForHost(host: Element | null) {
    const controls=host && diagramControls.get(host);
    const drawing=host?.querySelector('svg, img');
    const viewport=host?.closest<HTMLElement>('.focus-stage') || host?.querySelector<HTMLElement>('.mermaid-viewport, .svg-image-viewport');
    return controls && drawing && viewport ? {host,controls,drawing,viewport} : undefined;
}
export function diagramZoomAt(point: { x: number; y: number }) {
    return diagramForHost(document.elementFromPoint(point.x,point.y)?.closest('.mermaid,.svg-image-diagram') || null);
}
