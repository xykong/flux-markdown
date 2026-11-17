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
        button.textContent = ['−', '100%', '+'][index]; element.append(button); return button;
    });
    function update(): void {
        buttons[0].disabled = !ready || factor <= minimum + 1e-8;
        buttons[1].disabled = !ready;
        buttons[2].disabled = !ready || factor >= maximum - 1e-8;
        buttons[1].textContent = `${Math.round(factor * 100)}%`;
    }
    function setFactor(value: number): void {
        if (!Number.isFinite(value) || !ready || disposed) return;
        factor = Math.max(minimum, Math.min(maximum, value));
        update(); changed();
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
}
export function diagramZoomAt(point: { x: number; y: number }): { host: Element; controls: DiagramZoomControls; drawing: Element; viewport: HTMLElement } | undefined {
    const host = document.elementFromPoint(point.x, point.y)?.closest('.mermaid, .svg-image-diagram');
    const controls = host && diagramControls.get(host);
    const drawing = host?.querySelector('svg, img');
    const viewport = host?.querySelector<HTMLElement>('.mermaid-viewport, .svg-image-viewport');
    return controls && drawing && viewport ? { host, controls, drawing, viewport } : undefined;
}
