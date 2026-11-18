/** Quick Look session-only follow state. No document contents enter diagnostics. */

/**
 * What a followed render keeps so the next append parses only its tail.
 * Lines are absolute, 0-based source lines; `restart` is the last top-level block,
 * the only block an append can extend.
 */
export interface FollowSnapshot {
    text: string;
    key: string;
    prefix: string;
    restart?: { line: number; offset: number; html: string };
    headings: Array<{ line: number; level: number; text: string; id: string }>;
    references: Record<string, unknown>;
    abbreviations?: Record<string, string>;
    footnotes: boolean;
    firstMathLine?: number;
}

/** Character index where the given 0-based line starts, or -1. */
export function lineStart(text: string, line: number): number {
    let index = 0;
    for (let current = 0; current < line; current++) {
        index = text.indexOf('\n', index) + 1;
        if (index === 0) return -1;
    }
    return index;
}

/** First line of the last top-level block in a token stream. */
export function lastBlockLine(tokens: Array<{ level: number; nesting: number; map: [number, number] | null }>): number | undefined {
    for (let index = tokens.length - 1; index >= 0; index--) {
        const token = tokens[index];
        if (token.level === 0 && token.nesting !== -1 && token.map) return token.map[0];
    }
    return undefined;
}

/** The direct child that starts at a 1-based source line, searched from the end. */
export function blockElement(root: ParentNode, sourceLine: number): Element | undefined {
    for (let element = root.lastElementChild; element; element = element.previousElementSibling) {
        // Copy controls wrap code blocks until they are disposed before a commit.
        const source = element.classList.contains('block-copy-host') ? element.querySelector(':scope > [data-source-line]') : element;
        const value = source?.getAttribute('data-source-line') ?? null;
        if (value === null) continue;
        return Number(value) === sourceLine ? element : undefined;
    }
    return undefined;
}

/** Same algorithm as markdown-it-anchor, but sharing slugs with blocks parsed earlier. */
export function uniqueHeadingSlug(slug: string, env: { headingSlugs?: Set<string> }): string {
    const used = env.headingSlugs;
    if (!used) return slug;
    let candidate = slug;
    for (let suffix = 1; used.has(candidate); suffix++) candidate = `${slug}-${suffix}`;
    used.add(candidate);
    return candidate;
}

/** Elements inside or equal to any root; decoration then skips kept blocks. */
export function queryRoots(roots: readonly Element[], selector: string): Element[] {
    return roots.flatMap(root => [...(root.matches(selector) ? [root] : []), ...Array.from(root.querySelectorAll(selector))]);
}

export function documentSelection(root: HTMLElement): boolean {
    const selection = window.getSelection();
    return !!selection && !selection.isCollapsed && !!selection.anchorNode &&
        (root.contains(selection.anchorNode) || (!!selection.focusNode && root.contains(selection.focusNode)));
}
export function copyPending(root: HTMLElement): boolean {
    return !!root.querySelector('[data-copy-state="pending"]');
}
export async function waitForSafeCommit(root: HTMLElement, isCurrent: () => boolean): Promise<boolean> {
    while (documentSelection(root) || copyPending(root)) {
        await new Promise<void>(resolve => setTimeout(resolve, 50));
        if (!isCurrent()) return false;
    }
    return isCurrent();
}

export class FollowFile {
    private active = false;
    private paused = false;
    private observer?: ResizeObserver;
    private restoring = false;
    private anchor?: {node: Element; line: string | null; tag: string; text: string; top: number; scroll: number};
    private pause = () => { if (this.active) { this.paused = true; this.captureAnchor(); } };
    private key = (event: KeyboardEvent) => {
        if (['ArrowUp','ArrowDown','PageUp','PageDown','Home','End',' ','Tab'].includes(event.key) ||
            ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'f')) this.pause();
    };
    private pointer = (event: Event) => {
        const target = event.target;
        if (target === document.documentElement || target === document.body ||
            (target instanceof Element && target.closest('a, button, input, #toc-container, #search-container'))) this.pause();
    };
    private scroll = () => {
        if (this.restoring) return;
        // Layout, scroll anchoring and our own scrollTo also emit scroll events.
        // Pause on explicit navigation input, not a transient layout coordinate.
        if (this.paused) this.captureAnchor();
    };
    constructor(private root: HTMLElement) {
        window.addEventListener('wheel',this.pause,{passive:true});
        window.addEventListener('touchmove',this.pause,{passive:true});
        window.addEventListener('keydown',this.key);
        window.addEventListener('scroll',this.scroll);
        document.addEventListener('pointerdown',this.pointer,true);
        if (typeof ResizeObserver !== 'undefined') {
            this.observer = new ResizeObserver(() => this.paused ? this.restoreAnchor() : this.settle());
        }
    }
    owns(root: HTMLElement): boolean { return this.root === root; }
    set(active: boolean): void {
        this.active=active; this.paused=false; this.anchor=undefined;
        if (active) this.observer?.observe(this.root); else this.observer?.disconnect();
        this.settle();
    }
    status(): {active:boolean;paused:boolean;selected:boolean;copying:boolean} {
        const selected=documentSelection(this.root);
        if (selected && !this.paused) this.pause();
        return {active:this.active,paused:this.paused,selected,copying:copyPending(this.root)};
    }
    captureAnchor(): void {
        if (!this.paused || this.restoring) return;
        const node=Array.from(this.root.querySelectorAll('[data-source-line]')).find(el=>el.getBoundingClientRect().bottom>0);
        if (node) this.anchor={node,line:node.getAttribute('data-source-line'),tag:node.tagName,
            text:this.anchorText(node),top:node.getBoundingClientRect().top,scroll:window.scrollY};
    }
    private anchorText(node: Element): string {
        const clone=node.cloneNode(true) as Element;
        clone.querySelectorAll('.block-copy-tools').forEach(el=>el.remove());
        return clone.textContent || '';
    }
    restoreAnchor(): void {
        if (!this.paused || !this.anchor) return;
        const saved=this.anchor;
        const candidates=Array.from(this.root.querySelectorAll('[data-source-line]'));
        const node=this.root.contains(saved.node) ? saved.node :
            candidates.find(el=>el.tagName===saved.tag && this.anchorText(el)===saved.text) ||
            candidates.find(el=>el.getAttribute('data-source-line')===saved.line);
        this.restoring=true;
        window.scrollTo(0,node ? window.scrollY + node.getBoundingClientRect().top-saved.top : saved.scroll);
        this.restoring=false;
    }
    settle(): void {
        const status=this.status();
        if (status.active && !status.paused) {
            // Scroll the scrolling element, not the last source node: trailing
            // margins and asynchronously sized content must also be visible.
            const bottom=Math.max(0,document.documentElement.scrollHeight-window.innerHeight);
            window.scrollTo(0,bottom);
        }
    }
    dispose(): void {
        this.active=false; this.observer?.disconnect();
        window.removeEventListener('wheel',this.pause); window.removeEventListener('touchmove',this.pause);
        window.removeEventListener('keydown',this.key); window.removeEventListener('scroll',this.scroll);
        document.removeEventListener('pointerdown',this.pointer,true);
    }
}
