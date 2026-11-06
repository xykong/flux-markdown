import type { HeadingNode } from './outline';
import { readingLabels, updateReadingControlsLayout, captureReadingAnchor, restoreReadingAnchor, ReadingAnchor } from './reading-controls';

function compressMultipleHyphens(text: string): string {
    return text.replace(/-+/g, '-');
}

function unifyUnderscoreAndHyphen(text: string): string {
    return text.replace(/[_-]/g, '~');
}

function findElementByAnchor(anchorId: string): HTMLElement | null {
    const allElementsWithId = document.querySelectorAll('[id]');
    
    const exactMatch = document.getElementById(anchorId);
    if (exactMatch) return exactMatch;
    
    const level2NormalizedTarget = compressMultipleHyphens(anchorId);
    for (const element of allElementsWithId) {
        const elementId = element.getAttribute('id');
        if (elementId && compressMultipleHyphens(elementId) === level2NormalizedTarget) {
            return element as HTMLElement;
        }
    }
    
    const level3NormalizedTarget = unifyUnderscoreAndHyphen(compressMultipleHyphens(anchorId));
    for (const element of allElementsWithId) {
        const elementId = element.getAttribute('id');
        if (elementId && unifyUnderscoreAndHyphen(compressMultipleHyphens(elementId)) === level3NormalizedTarget) {
            return element as HTMLElement;
        }
    }
    
    return null;
}

export class TableOfContents {
    private container: HTMLElement;
    private button: HTMLButtonElement;
    private buttonSlot: HTMLElement;
    private dockedPreference: boolean | null = null;
    private overlayVisible = false;
    private wide = window.innerWidth >= 900;
    private hasHeadings = false;
    private headings: HTMLElement[] = [];
    private userScrollUntil = 0;
    private frame: number | null = null;
    private anchor: ReadingAnchor | null = null;
    private disposed = false;
    private readonly resizeHandler = () => this.updateLayout(true);
    private readonly scrollHandler = () => {
        if (this.frame !== null) return;
        this.frame = requestAnimationFrame(() => {
            this.frame = null;
            this.anchor = captureReadingAnchor();
            this.updateActiveHeading();
        });
    };
    private readonly outsideHandler = (event: MouseEvent) => {
        const target = event.target as Node;
        if (this.overlayVisible && !this.container.contains(target) && !this.buttonSlot.contains(target)) this.closeOverlay(false);
    };
    private readonly keyHandler = (event: KeyboardEvent) => {
        if (event.key === 'Escape' && !event.defaultPrevented && this.overlayVisible && document.documentElement.dataset.context === 'app') {
            event.preventDefault(); event.stopPropagation(); this.closeOverlay(true);
        }
    };

    constructor(containerId: string) {
        const element = document.getElementById(containerId);
        if (!element) throw new Error(`TOC container element not found: ${containerId}`);
        this.container = element;
        this.buttonSlot = document.getElementById('toc-button-container') || element;
        this.button = document.createElement('button');
        this.button.type = 'button';
        this.button.className = 'toc-toggle reading-tool-button';
        this.button.setAttribute('aria-controls', 'toc-navigation');
        this.button.addEventListener('click', () => this.toggle());
        this.buttonSlot.appendChild(this.button);
        window.addEventListener('resize', this.resizeHandler);
        window.addEventListener('scroll', this.scrollHandler, { passive: true });
        document.addEventListener('click', this.outsideHandler);
        document.addEventListener('keydown', this.keyHandler, true);
    }

    isMounted(): boolean { return this.container.isConnected && this.button.isConnected; }

    public render(headings: HeadingNode[]): void {
        this.hasHeadings = headings.length > 0;
        const labels = readingLabels();
        this.button.textContent = labels.contents;
        this.button.setAttribute('aria-label', labels.contents);
        if (!this.hasHeadings) {
            this.overlayVisible = false;
            this.headings = [];
            this.container.querySelector('.toc-nav')?.remove();
            this.updateLayout();
            return;
        }
        const nav = document.createElement('nav');
        nav.id = 'toc-navigation'; nav.className = 'toc-nav';
        nav.setAttribute('aria-label', labels.contents);
        const header = document.createElement('div'); header.className = 'toc-header';
        const title = document.createElement('span'); title.className = 'toc-title'; title.textContent = labels.contents;
        const close = document.createElement('button'); close.type = 'button'; close.className = 'toc-close reading-tool-button';
        close.textContent = '×'; close.setAttribute('aria-label', labels.close);
        close.addEventListener('click', () => { this.hide(); if (document.documentElement.dataset.context === 'app') this.button.focus(); });
        header.append(title, close); nav.appendChild(header);
        const levels: number[] = [];
        const collect = (nodes: HeadingNode[]) => nodes.forEach(node => { levels.push(node.level); collect(node.children); });
        collect(headings);
        nav.appendChild(this.renderList(headings, levels.reduce((minimum, level) => Math.min(minimum, level), 6)));
        for (const event of ['wheel', 'touchstart', 'pointerdown', 'keydown']) {
            nav.addEventListener(event, () => { this.userScrollUntil = Date.now() + 2000; }, { passive: true });
        }
        this.container.querySelector('.toc-nav')?.remove();
        this.container.appendChild(nav);
        // Let the browser resolve dir=auto, then batch writes to avoid interleaved style reads.
        // Physical CSS fallbacks also cover Safari 14.0, before logical inset properties.
        const directions = Array.from(nav.querySelectorAll<HTMLAnchorElement>('.toc-link'))
            .map(link => ({ link, direction: getComputedStyle(link).direction }));
        for (const { link, direction } of directions) link.dataset.textDirection = direction === 'rtl' ? 'rtl' : 'ltr';
        this.headings = Array.from(document.querySelectorAll<HTMLElement>('#markdown-preview h1[id], #markdown-preview h2[id], #markdown-preview h3[id], #markdown-preview h4[id], #markdown-preview h5[id], #markdown-preview h6[id]'));
        this.updateLayout();
        this.updateActiveHeading();
    }

    private renderList(headings: HeadingNode[], baseLevel: number): HTMLElement {
        const list = document.createElement('ul'); list.className = 'toc-list';
        headings.forEach(heading => {
            const item = document.createElement('li'); item.className = 'toc-item';
            const link = document.createElement('a'); link.className = 'toc-link';
            link.dir = 'auto';
            link.href = `#${heading.id}`; link.textContent = heading.text; link.title = heading.text;
            link.dataset.level = String(heading.level);
            link.dataset.depth = String(Math.min(5, heading.level - baseLevel));
            link.style.setProperty('--toc-indent', `${Math.min(5, heading.level - baseLevel) * 12}px`);
            link.addEventListener('click', event => {
                event.preventDefault();
                const target = findElementByAnchor(heading.id);
                if (!target) return;
                if (!this.wide) this.closeOverlay(document.documentElement.dataset.context === 'app');
                const reduced = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
                target.scrollIntoView({ behavior: reduced ? 'auto' : 'smooth', block: 'start' });
                this.setActiveItem(target.id);
            });
            item.appendChild(link);
            if (heading.children.length) item.appendChild(this.renderList(heading.children, baseLevel));
            list.appendChild(item);
        });
        return list;
    }

    private updateActiveHeading(): void {
        if (!this.headings.length) return;
        const controls = document.getElementById('reading-controls');
        const scrollMargin = parseFloat(getComputedStyle(this.headings[0]).scrollMarginTop);
        const threshold = (Number.isFinite(scrollMargin) ? scrollMargin
            : Math.max(64, (controls && !controls.hidden ? controls.getBoundingClientRect().bottom : 0) + 8) + 16) + 2;
        let active = this.headings[0];
        for (const heading of this.headings) {
            if (heading.getBoundingClientRect().top > threshold) break;
            active = heading;
        }
        this.setActiveItem(active.id);
    }

    private setActiveItem(id: string): void {
        document.dispatchEvent(new CustomEvent('reading-heading', { detail: id }));
        this.container.querySelectorAll<HTMLAnchorElement>('.toc-link').forEach(link => {
            const selected = link.getAttribute('href') === `#${id}`;
            link.classList.toggle('active', selected);
            if (selected) link.setAttribute('aria-current', 'location'); else link.removeAttribute('aria-current');
        });
        const nav = this.container.querySelector<HTMLElement>('.toc-nav');
        const active = this.container.querySelector<HTMLElement>('[aria-current="location"]');
        if (!nav || !active || !this.wide || Date.now() < this.userScrollUntil) return;
        const bounds = nav.getBoundingClientRect(), item = active.getBoundingClientRect();
        const headerHeight = nav.querySelector('.toc-header')?.getBoundingClientRect().height || 44;
        const delta = item.top < bounds.top + headerHeight ? item.top - bounds.top - headerHeight
            : item.bottom > bounds.bottom ? item.bottom - bounds.bottom : 0;
        if (delta && typeof nav.scrollBy === 'function') nav.scrollBy({ top: delta, behavior: 'auto' });
    }

    public updateLayout(resizing = false): void {
        const oldDocked = document.documentElement.dataset.tocDocked === 'true';
        const readingAnchor = resizing ? this.anchor : captureReadingAnchor();
        const compact = document.documentElement.dataset.context === 'finder';
        const wide = window.innerWidth >= 900 && !compact;
        if (wide !== this.wide) this.overlayVisible = false;
        this.wide = wide;
        const visible = this.hasHeadings && !compact && (wide ? (this.dockedPreference ?? true) : this.overlayVisible);
        const docked = wide && visible;
        document.documentElement.dataset.tocDocked = String(docked);
        document.documentElement.dataset.tocAvailable = String(this.hasHeadings && !compact);
        this.container.dataset.layout = wide ? 'sidebar' : 'overlay';
        this.container.style.display = this.hasHeadings && !compact ? 'block' : 'none';
        this.buttonSlot.hidden = !this.hasHeadings || compact;
        const nav = this.container.querySelector<HTMLElement>('.toc-nav');
        nav?.classList.toggle('visible', visible);
        if (nav) nav.hidden = !visible;
        this.button.setAttribute('aria-expanded', String(visible));
        updateReadingControlsLayout();
        if (resizing || oldDocked !== docked) restoreReadingAnchor(readingAnchor);
        this.anchor = captureReadingAnchor();
    }
    private closeOverlay(focus: boolean): void { this.overlayVisible = false; this.updateLayout(); if (focus) this.button.focus(); }
    public toggle(): void { this.setVisible(this.button.getAttribute('aria-expanded') !== 'true'); }
    public show(): void { this.setVisible(true); }
    public hide(): void { this.setVisible(false); }
    private setVisible(visible: boolean): void {
        if (this.wide) this.dockedPreference = visible; else this.overlayVisible = visible;
        this.updateLayout();
    }
    public dispose(): void {
        if (this.disposed) return;
        this.disposed = true;
        window.removeEventListener('resize', this.resizeHandler);
        window.removeEventListener('scroll', this.scrollHandler);
        document.removeEventListener('click', this.outsideHandler);
        document.removeEventListener('keydown', this.keyHandler, true);
        if (this.frame !== null) cancelAnimationFrame(this.frame);
    }
}
