export class MathematicalExportError extends Error {}
export type ExportPreparation = { status: 'ready' } | { status: 'mathematics' };

export async function prepareExport(wait: () => Promise<void>): Promise<ExportPreparation> {
    try { await wait(); return { status: 'ready' }; }
    catch (error) {
        if (error instanceof MathematicalExportError) return { status: 'mathematics' };
        throw error;
    }
}

/** Rendering is awaited by the caller; then fonts/images must settle before print. */
export async function waitForExportReady(timeoutMs = 15000, checkCurrent: () => void = () => {}): Promise<void> {
    checkCurrent();
    const root = document.getElementById('markdown-preview');
    if (root?.querySelector('.math-error, .katex-error')) {
        throw new MathematicalExportError('Cannot export: mathematics or an equation reference failed to render');
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
    const fontsReady = async () => {
        // Font requests can start only after the new mathematics participates in
        // layout. Recheck after each ready promise rather than trusting an old one.
        for (let pass = 0; pass < 6; pass++) {
            checkCurrent();
            root?.getBoundingClientRect();
            await document.fonts?.ready;
            checkCurrent();
            root?.getBoundingClientRect();
            if (!document.fonts || document.fonts.status === 'loaded') return;
        }
        throw new Error('Export fonts did not settle');
    };
    try {
        await Promise.race([
            Promise.all([...images, fontsReady()]),
            new Promise<never>((_, reject) => { timer = setTimeout(() => reject(new Error('Export resources timed out')), timeoutMs); }),
        ]);
        checkCurrent();
    } finally {
        if (timer !== undefined) clearTimeout(timer);
        cleanup.forEach(dispose => dispose());
    }
}
