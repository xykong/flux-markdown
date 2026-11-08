/** Diagram sizing uses SVG user units, never the engine's width="100%" default. */
export function diagramScale(width: number, available: number, bodyFont: number, labelFont: number): number {
    return Math.min(1, bodyFont / labelFont, available > 0 ? available / width : 1);
}
const labels: Record<string, [string, string, string]> = {
    en: ['Zoom out diagram', 'Reset diagram zoom', 'Zoom in diagram'],
    zh: ['缩小图表', '还原图表缩放', '放大图表'],
    de: ['Diagramm verkleinern', 'Diagrammzoom zurücksetzen', 'Diagramm vergrößern'],
    fr: ['Réduire le diagramme', 'Réinitialiser le zoom du diagramme', 'Agrandir le diagramme'],
    es: ['Alejar diagrama', 'Restablecer zoom del diagrama', 'Acercar diagrama'],
    ar: ['تصغير المخطط', 'إعادة تعيين تكبير المخطط', 'تكبير المخطط'],
};

export function installMermaidLayout(root: HTMLElement): () => void {
    const strings = labels[(window.__fluxLang || navigator.language).split('-')[0]] || labels.en;
    const entries: { host: HTMLElement; svg: SVGSVGElement; viewport: HTMLElement; tools: HTMLElement; width: number; font: number; step: number; buttons: HTMLButtonElement[] }[] = [];
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
        const tools = document.createElement('div'); tools.className = 'mermaid-tools';
        const buttons = strings.map((label, index) => {
            const button = document.createElement('button'); button.type = 'button';
            button.title = label; button.setAttribute('aria-label', label);
            button.textContent = ['−', '100%', '+'][index]; tools.append(button); return button;
        });
        host.prepend(tools);
        const entry = { host, svg, viewport, tools, width: viewBox[2], font: font || 16, step: 0, buttons };
        entries.push(entry);
        buttons.forEach((button, index) => button.addEventListener('click', event => {
            event.preventDefault(); event.stopPropagation();
            entry.step = index === 1 ? 0 : Math.max(-8, Math.min(8, entry.step + (index === 0 ? -1 : 1)));
            layout();
        }));
        svg.style.maxWidth = 'none'; svg.style.height = 'auto'; svg.style.display = 'block';
    });
    function layout(): void {
        const bodyFont = parseFloat(getComputedStyle(root).fontSize) || 16;
        for (const entry of entries) {
            const base = diagramScale(entry.width, entry.viewport.clientWidth, bodyFont, entry.font);
            const factor = Math.pow(1.25, entry.step);
            const width = `${entry.width * base * factor}px`;
            if (entry.svg.style.width !== width) entry.svg.style.width = width;
            entry.buttons[0].disabled = entry.step === -8;
            entry.buttons[2].disabled = entry.step === 8;
            entry.buttons[1].textContent = `${Math.round(factor * 100)}%`;
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
        entries.forEach(entry => { entry.tools.remove(); entry.viewport.replaceWith(entry.svg); });
    };
}
