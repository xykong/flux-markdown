import { updateReadingControlsLayout } from './reading-controls';

export function headingPath(headings: HTMLElement[], active: HTMLElement): string[] {
    const stack: HTMLElement[] = [];
    for (const heading of headings) {
        while (stack.length && stack[stack.length - 1].tagName >= heading.tagName) stack.pop();
        stack.push(heading);
        if (heading === active) break;
    }
    return stack.map(heading => heading.textContent?.trim() || '');
}
export function scrollProgress(y: number, height: number, viewport: number): number | null {
    return height <= viewport + 1 ? null : Math.round(Math.max(0, Math.min(1, y / (height - viewport))) * 100);
}
const labels = {
    en: ['Position', 'Document updated'], zh: ['位置', '文档已更新'],
    de: ['Position', 'Dokument aktualisiert'], fr: ['Position', 'Document actualisé'],
    es: ['Posición', 'Documento actualizado'], ar: ['الموضع', 'تم تحديث المستند']
};
export class ReadingStatus {
    private lastText: string | undefined;
    private headings: HTMLElement[] = [];
    private path = document.createElement('span');
    private parent = document.createElement('span');
    private current = document.createElement('span');
    private file = document.createElement('span');
    private progress = document.createElement('span');
    private updated = document.createElement('span');
    private frame: number | null = null;
    private timer: ReturnType<typeof setTimeout> | null = null;
    private observer: ResizeObserver | null = null;
    private readonly heading = (event: Event) => {
        const active = this.headings.find(h => h.id === (event as CustomEvent<string>).detail);
        if (!active) return;
        const path = headingPath(this.headings, active);
        this.path.title = path.join(' › ');
        this.parent.textContent = path.length > 1 ? path[path.length - 2] + ' › ' : '';
        this.current.textContent = path[path.length - 1];
    };
    private readonly schedule = () => {
        if (this.frame !== null) return;
        this.frame = requestAnimationFrame(() => { this.frame = null; this.update(); });
    };
    constructor(private element: HTMLElement) {
        this.file.className = 'reading-filename'; this.path.className = 'reading-path';
        this.parent.className = 'reading-parent'; this.current.className = 'reading-current';
        this.progress.className = 'reading-progress'; this.updated.className = 'reading-updated';
        this.updated.setAttribute('role', 'status'); this.updated.hidden = true;
        this.path.append(this.parent, this.current);
        element.replaceChildren(this.file, this.path, this.progress, this.updated);
        document.addEventListener('reading-heading', this.heading);
        window.addEventListener('scroll', this.schedule, { passive: true });
        window.addEventListener('resize', this.schedule);
        if (typeof ResizeObserver !== 'undefined') {
            this.observer = new ResizeObserver(this.schedule);
            this.observer.observe(element);
            const preview = document.getElementById('markdown-preview');
            if (preview) this.observer.observe(preview);
        }
    }
    isMounted(): boolean { return this.element === document.getElementById('reading-status'); }
    render(text: string, filename?: string, previous?: string): void {
        if (this.timer) clearTimeout(this.timer);
        this.updated.hidden = true;
        this.headings = Array.from(document.querySelectorAll<HTMLElement>('#markdown-preview h1[id], #markdown-preview h2[id], #markdown-preview h3[id], #markdown-preview h4[id], #markdown-preview h5[id], #markdown-preview h6[id]'));
        this.parent.textContent = ''; this.current.textContent = ''; this.path.title = '';
        this.file.textContent = document.documentElement.dataset.context === 'quicklook' ? filename || '' : '';
        this.file.title = this.file.textContent;
        if (previous !== undefined && previous !== text && this.lastText !== text) {
            this.updated.textContent = this.strings()[1]; this.updated.hidden = false;
            this.timer = setTimeout(() => { this.updated.hidden = true; this.update(); }, 4000);
        }
        if (this.headings[0]) this.heading(new CustomEvent('reading-heading', { detail: this.headings[0].id }));
        this.lastText = text;
        this.update();
    }
    private strings(): string[] {
        const lang = (window.__fluxLang || navigator.language || 'en').split('-')[0];
        return labels[lang as keyof typeof labels] || labels.en;
    }
    private update(): void {
        const value = scrollProgress(window.scrollY, document.documentElement.scrollHeight, window.innerHeight);
        this.progress.hidden = value === null;
        this.progress.textContent = value === null ? '' : `${this.strings()[0]} ${value}%`;
        this.progress.title = this.progress.textContent;
        this.element.hidden = document.documentElement.dataset.context === 'finder'
            || !!document.querySelector('#markdown-preview.source-mode')
            || (!this.headings.length && !this.file.textContent && value === null && this.updated.hidden);
        const width = this.element.getBoundingClientRect().width;
        this.element.dataset.size = width < 170 ? 'tiny' : width < 300 ? 'small' : width < 480 ? 'medium' : 'large';
        updateReadingControlsLayout();
    }
    dispose(): void {
        if (this.timer) clearTimeout(this.timer);
        if (this.frame !== null) cancelAnimationFrame(this.frame);
        this.observer?.disconnect();
        document.removeEventListener('reading-heading', this.heading);
        window.removeEventListener('scroll', this.schedule); window.removeEventListener('resize', this.schedule);
    }
}
