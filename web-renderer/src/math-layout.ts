import { originalMathSource } from './math-source-store';

/** Only oversized inline mathematics changes its baseline/scrolling behavior. */
export function installMathLayout(root: HTMLElement): () => void {
    const update = () => {
        const decisions = Array.from(root.querySelectorAll<HTMLElement>('span.flux-math-source, div.flux-math-source')).flatMap(node => {
            if (originalMathSource(node) === undefined) return [];
            const svg = node.querySelector('svg');
            if (!svg) return [];
            if (node.tagName === 'DIV') {
                return [node, ...node.querySelectorAll<HTMLElement>('mjx-container')].map(surface => ({
                    node:surface, inline:false, oversized:surface.clientWidth > 0 && surface.scrollWidth > surface.clientWidth + 1
                        && ['auto', 'scroll'].includes(getComputedStyle(surface).overflowX),
                }));
            }
            const block = node.closest<HTMLElement>('p,li,td,th,dd,dt,blockquote') || root;
            const style = getComputedStyle(block);
            const available = block.clientWidth - (parseFloat(style.paddingLeft) || 0) - (parseFloat(style.paddingRight) || 0);
            return [{node, inline:true, oversized:available > 0 && svg.getBoundingClientRect().width > available + 1}];
        });
        // Read geometry first, then write classes, avoiding per-item forced layout.
        for (const {node, inline, oversized} of decisions) {
            if (inline && node.classList.contains('math-inline-overflow') !== oversized) {
                node.classList.toggle('math-inline-overflow', oversized);
            }
            // Only genuine scroll surfaces add a tab stop; keep ordinary math in reading order.
            if (oversized) node.tabIndex = 0;
            else node.removeAttribute('tabindex');
        }
    };
    update();
    const observer = typeof ResizeObserver === 'undefined' ? null : new ResizeObserver(update);
    observer?.observe(root);
    window.addEventListener('resize', update);
    return () => { observer?.disconnect(); window.removeEventListener('resize', update); };
}
