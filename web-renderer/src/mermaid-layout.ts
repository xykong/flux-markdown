import { createDiagramZoomControls } from './diagram-zoom-controls';
/** Diagram sizing uses SVG user units, never the engine's width="100%" default. */
export function diagramScale(width: number, available: number, bodyFont: number, labelFont: number): number {
    return Math.min(1, bodyFont / labelFont, available > 0 ? available / width : 1);
}

export function installMermaidLayout(root: HTMLElement): () => void {
    const entries: { host: HTMLElement; svg: SVGSVGElement; viewport: HTMLElement; controls: ReturnType<typeof createDiagramZoomControls>; width: number; font: number }[] = [];
    root.querySelectorAll<HTMLElement>('.mermaid').forEach(host => {
        const svg = host.querySelector('svg');
        if (!svg) return;
        const viewBox = (svg.getAttribute('viewBox') || '').trim().split(/[\s,]+/).map(Number);
        if (viewBox.length !== 4 || !viewBox.every(Number.isFinite) || viewBox[2] <= 0 || viewBox[3] <= 0) return;
        let font = 0;
        svg.querySelectorAll('text, tspan, foreignObject *').forEach(label => {
            if (!Array.from(label.childNodes).some(node => node.nodeType === Node.TEXT_NODE && node.textContent?.trim())) return;
            font = Math.max(font, parseFloat(getComputedStyle(label).fontSize) || 16);
        });
        const viewport = document.createElement('div'); viewport.className = 'mermaid-viewport';
        svg.before(viewport); viewport.append(svg);
        const controls = createDiagramZoomControls('mermaid-tools', layout);
        host.prepend(controls.element);
        entries.push({ host, svg, viewport, controls, width: viewBox[2], font: font || 16 });
        svg.style.maxWidth = 'none'; svg.style.height = 'auto'; svg.style.display = 'block';
    });
    function layout(): void {
        const bodyFont = parseFloat(getComputedStyle(root).fontSize) || 16;
        for (const entry of entries) {
            const base = diagramScale(entry.width, entry.viewport.clientWidth, bodyFont, entry.font);
            const factor = entry.controls.factor;
            const width = `${entry.width * base * factor}px`;
            if (entry.svg.style.width !== width) entry.svg.style.width = width;
        }
    }
    const resize = typeof ResizeObserver === 'undefined' ? undefined : new ResizeObserver(layout);
    entries.forEach(entry => resize?.observe(entry.viewport));
    const mutation = new MutationObserver(layout);
    mutation.observe(root, { attributes: true, attributeFilter: ['style', 'class'] });
    window.addEventListener('resize', layout);
    layout();
    return () => {
        resize?.disconnect(); mutation.disconnect(); window.removeEventListener('resize', layout);
        entries.forEach(entry => { entry.controls.dispose(); entry.viewport.replaceWith(entry.svg); });
    };
}
