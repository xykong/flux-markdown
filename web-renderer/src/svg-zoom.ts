import { createDiagramZoomControls } from './diagram-zoom-controls';

/** Image isolation and the original link remain intact while only its viewport scrolls. */
export function installSVGZoom(root: HTMLElement): () => void {
    const entries: { img: HTMLImageElement; content: Element; host: HTMLElement; viewport: HTMLElement; style: string; controls: ReturnType<typeof createDiagramZoomControls> }[] = [];
    const onlyChild = (parent: Element, child: Element) => Array.from(parent.childNodes).every(node =>
        node === child || node.nodeType === Node.COMMENT_NODE || (node.nodeType === Node.TEXT_NODE && !node.textContent?.trim()));
    root.querySelectorAll<HTMLImageElement>('img.svg-image').forEach(img => {
        const parent = img.parentElement;
        const content = parent?.tagName === 'A' && onlyChild(parent, img) ? parent : img;
        const paragraph = content.parentElement;
        if (paragraph?.tagName !== 'P' || !onlyChild(paragraph, content)) return;
        const host = document.createElement('span'); host.className = 'svg-image-diagram';
        const viewport = document.createElement('span'); viewport.className = 'svg-image-viewport';
        viewport.tabIndex = 0; viewport.setAttribute('role', 'region'); viewport.setAttribute('aria-label', img.alt || 'SVG');
        const controls = createDiagramZoomControls('svg-image-tools', layout);
        content.before(host); host.append(controls.element, viewport); viewport.append(content);
        entries.push({ img, content, host, viewport, controls, style: img.style.cssText });
        img.addEventListener('load', layout);
        img.addEventListener('error', layout);
    });
    function layout(): void {
        for (const entry of entries) {
            // Measure the same automatic baseline as before controls existed.
            // This also handles explicit icon widths and responsive font limits.
            entry.img.style.cssText = entry.style;
            const width = entry.img.getBoundingClientRect().width;
            const ready = entry.img.naturalWidth > 0 && width > 0;
            entry.controls.setReady(ready);
            if (!ready || entry.controls.factor === 1) continue;
            entry.img.style.maxWidth = 'none';
            entry.img.style.width = `${width * entry.controls.factor}px`;
            entry.img.style.height = 'auto';
        }
    }
    const resize = typeof ResizeObserver === 'undefined' ? undefined : new ResizeObserver(layout);
    entries.forEach(entry => resize?.observe(entry.viewport));
    const mutation = new MutationObserver(layout);
    mutation.observe(root, { attributes:true, attributeFilter:['style','class'] });
    window.addEventListener('resize', layout);
    layout();
    return () => {
        resize?.disconnect(); mutation.disconnect(); window.removeEventListener('resize', layout);
        for (const entry of entries) {
            entry.img.removeEventListener('load', layout); entry.img.removeEventListener('error', layout);
            entry.img.style.cssText = entry.style;
            entry.controls.dispose(); entry.host.replaceWith(entry.content);
        }
    };
}
