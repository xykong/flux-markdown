/** Shared, measured layout for the reading controls (below native window tools). */
declare global { interface Window { __fluxLang?: string; } }
const labels = {
    en: { tools: 'Reading controls', contents: 'Contents', close: 'Close contents', collapse: 'Collapse blockquotes', expand: 'Expand blockquotes' },
    zh: { tools: '阅读工具', contents: '目录', close: '关闭目录', collapse: '折叠引用块', expand: '展开引用块' },
    de: { tools: 'Lesewerkzeuge', contents: 'Inhalt', close: 'Inhalt schließen', collapse: 'Zitate einklappen', expand: 'Zitate ausklappen' },
    fr: { tools: 'Outils de lecture', contents: 'Sommaire', close: 'Fermer le sommaire', collapse: 'Replier les citations', expand: 'Déplier les citations' },
    ar: { tools: 'أدوات القراءة', contents: 'المحتويات', close: 'إغلاق المحتويات', collapse: 'طي الاقتباسات', expand: 'توسيع الاقتباسات' }
};
export function readingLabels() {
    const language = (window.__fluxLang || navigator.language || 'en').split('-')[0];
    return labels[language as keyof typeof labels] || labels.en;
}

const sentLayout = new WeakMap<HTMLElement, string>();

export function updateReadingControlsLayout(): void {
    const root = document.documentElement;
    const controls = document.getElementById('reading-controls');
    if (!controls) return;
    const compact = root.dataset.context === 'finder';
    const toolbar = document.getElementById('reading-toolbar');
    const nativeBase = root.dataset.context === 'app' ? 268 : 306;
    const status = document.getElementById('reading-status');
    const hasStatus = !!status && !status.hidden && window.innerWidth >= nativeBase + 156;
    const hasTools = ['toc-button-container', 'collapse-btn-container'].some(id => {
        const slot = document.getElementById(id);
        return slot && !slot.hidden && slot.childElementCount > 0;
    });
    if (toolbar) { toolbar.hidden = !(hasTools || hasStatus); toolbar.setAttribute('aria-label', readingLabels().tools); }
    const visible = !compact && (hasTools || hasStatus);
    controls.hidden = !visible;
    root.dataset.readingControls = String(visible);
    const slots = toolbar ? Array.from(toolbar.children).filter(e => e.id !== 'reading-status' && !(e as HTMLElement).hidden) : [];
    const naturalWidth = slots.reduce((width, slot) => width + slot.getBoundingClientRect().width, 0) + Math.max(0, slots.length - 1) * 12;
    // Reserve the existing native controls on the right; only wrap when necessary.
    const shared = visible && window.innerWidth >= naturalWidth + nativeBase + 56;
    root.dataset.readingShared = String(shared);
    const directory = document.getElementById('toc-button-container');
    const rightInset = shared && root.dataset.tocSide !== 'left' && directory && !directory.hidden
        ? directory.getBoundingClientRect().width + 20 : 0;
    root.style.setProperty('--reading-native-reserve', `${nativeBase + (rightInset ? rightInset + 14 : 12)}px`);
    const handler = window.webkit?.messageHandlers.readingToolsLayout;
    const key = `${rightInset}:${window.innerWidth}:${window.devicePixelRatio}`;
    if (handler && sentLayout.get(controls) !== key) {
        sentLayout.set(controls, key);
        handler.postMessage({ rightInset });
    }
    const height = visible && toolbar ? Math.ceil(toolbar.getBoundingClientRect().height) : 0;
    root.style.setProperty('--reading-controls-height', `${height}px`);
    const contentTop = Math.max(64, (visible ? controls.getBoundingClientRect().bottom : 0) + 8);
    const search = document.getElementById('search-container');
    const searchBottom = search?.style.display === 'flex' ? search.getBoundingClientRect().bottom + 8 : 0;
    root.style.setProperty('--reading-scroll-top', `${Math.ceil(Math.max(contentTop + 16, searchBottom))}px`);

}

export class ReadingControls {
    private observer: ResizeObserver | null = null;
    private readonly update = () => updateReadingControlsLayout();
    constructor(private element: HTMLElement) {
        if (typeof ResizeObserver !== 'undefined') {
            this.observer = new ResizeObserver(this.update);
            this.observer.observe(element);
            const search = document.getElementById('search-container');
            if (search) this.observer.observe(search);
        }
        window.addEventListener('resize', this.update);
        this.update();
    }
    isMounted(): boolean { return this.element === document.getElementById('reading-controls'); }
    dispose(): void { this.observer?.disconnect(); window.removeEventListener('resize', this.update); }
}

export interface ReadingAnchor { element: HTMLElement; top: number; scrollY: number; }
export function captureReadingAnchor(): ReadingAnchor | null {
    if (window.scrollY <= 0 || typeof document.elementFromPoint !== 'function') return null;
    const preview = document.getElementById('markdown-preview');
    const bounds = preview?.getBoundingClientRect();
    if (!bounds) return null;
    const controls = document.getElementById('reading-controls');
    const top = Math.max(64, (controls && !controls.hidden ? controls.getBoundingClientRect().bottom : 0) + 8);
    const search = document.getElementById('search-container');
    const searchBottom = search?.style.display === 'flex' ? search.getBoundingClientRect().bottom + 8 : 0;
    const hit = document.elementFromPoint(bounds.left + bounds.width / 2, Math.min(Math.max(top + 16, searchBottom), window.innerHeight - 1));
    const element = hit?.closest<HTMLElement>('#markdown-preview > *');
    return element ? { element, top: element.getBoundingClientRect().top, scrollY: window.scrollY } : null;
}
export function restoreReadingAnchor(anchor: ReadingAnchor | null): void {
    if (!anchor) return;
    Promise.resolve().then(() => {
        if (!anchor.element.isConnected || Math.abs(window.scrollY - anchor.scrollY) > 1) return;
        const delta = anchor.element.getBoundingClientRect().top - anchor.top;
        if (Math.abs(delta) > 1) window.scrollBy(0, delta);
    });
}
