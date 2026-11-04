/** Rendering is awaited by the caller; then fonts/images must settle before print. */
export async function waitForExportReady(timeoutMs = 15000): Promise<void> {
    const root = document.getElementById('markdown-preview');
    if (root?.querySelector('.math-error, .katex-error')) {
        throw new Error('Cannot export: mathematics or an equation reference failed to render');
    }
    if (root?.querySelector('.mermaid-error, .vega-error, .graphviz-error, .typst-error')) {
        throw new Error('Cannot export: a diagram failed to render');
    }
    const cleanup: Array<() => void> = [];
    let timer: ReturnType<typeof setTimeout> | undefined;
    const images = Array.from(root?.querySelectorAll('img') || []).map(img => {
        const check = () => { if (img.naturalWidth === 0) throw new Error('Cannot export: an image failed to load'); };
        if (img.complete) return Promise.resolve().then(check);
        return new Promise<void>((resolve, reject) => {
            const loaded = () => resolve();
            const failed = () => reject(new Error('Cannot export: an image failed to load'));
            img.addEventListener('load', loaded, { once: true });
            img.addEventListener('error', failed, { once: true });
            cleanup.push(() => { img.removeEventListener('load', loaded); img.removeEventListener('error', failed); });
        });
    });
    try {
        await Promise.race([
            Promise.all([...images, document.fonts?.ready]),
            new Promise<never>((_, reject) => { timer = setTimeout(() => reject(new Error('Export resources timed out')), timeoutMs); }),
        ]);
    } finally {
        if (timer !== undefined) clearTimeout(timer);
        cleanup.forEach(dispose => dispose());
    }
}
