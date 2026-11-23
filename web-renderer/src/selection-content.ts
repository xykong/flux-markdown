import TurndownService from 'turndown';
import { gfm } from 'turndown-plugin-gfm';
import { blockPlainText } from './block-copy';
import { originalMathSource } from './math-source-store';
import { originalDiagramSource } from './diagram-source-store';
import { relativeImageSource } from './image-source';

export type CopyFormat = 'plain' | 'markdown';
const ignored = '.block-copy-tools,.selection-copy-tools,.diagram-tools,.mermaid-tools,.error-feedback-controls,.blockquote-placeholder,.source-diff-gutter,.diff-char-removed,script,style,[hidden],[aria-hidden="true"]';
const editableInput = 'input,textarea,select,[contenteditable="true"]';
const converter = new TurndownService({ codeBlockStyle: 'fenced', emDelimiter: '*', bulletListMarker: '-' });
converter.use(gfm);

/** The text each root shows, and the file line just before its first line (non-zero for a tail window). */
const renderedSource = new WeakMap<Element, { text: string; firstLine: number; hasReferences: boolean }>();
export function rememberRenderedSource(root: Element, text: string, firstLine: number, hasReferences = false): void {
    renderedSource.set(root, { text, firstLine, hasReferences });
}

/** Construct only intersected content while retaining its ancestor semantics. */
export function selectedContent(root: HTMLElement, range: Range, format: CopyFormat): string | null {
    if (range.collapsed || !root.contains(range.startContainer) || !root.contains(range.endContainer)) return null;
    const source = root.classList.contains('source-mode');
    const rendered = !source && format === 'markdown' ? renderedSource.get(root) : undefined;
    const lines = rendered?.text.split('\n');
    /** All of the node's visible text is selected; a drag need not start before the node. */
    function wholly(node: Element): boolean {
        for (const leaf of node.querySelectorAll('img, br, hr')) {
            if (leaf.closest(ignored) || getComputedStyle(leaf).display === 'none') continue;
            const parent = leaf.parentNode!;
            const index = Array.prototype.indexOf.call(parent.childNodes, leaf);
            if (range.comparePoint(parent, index) !== 0 || range.comparePoint(parent, index + 1) !== 0) return false;
        }
        const texts: Text[] = [];
        const walker = document.createTreeWalker(node, NodeFilter.SHOW_TEXT);
        for (let text = walker.nextNode() as Text | null; text; text = walker.nextNode() as Text | null) {
            if (/\S/.test(text.data) && !text.parentElement?.closest(ignored)) texts.push(text);
        }
        if (!texts.length) {
            const whole = document.createRange(); whole.selectNodeContents(node);
            return range.compareBoundaryPoints(Range.START_TO_START, whole) <= 0 && range.compareBoundaryPoints(Range.END_TO_END, whole) >= 0;
        }
        const first = texts[0], last = texts[texts.length - 1];
        return range.comparePoint(first, first.data.search(/\S/)) === 0 &&
            range.comparePoint(last, last.data.length - (last.data.match(/\s*$/)?.[0].length ?? 0)) === 0;
    }
    /** The source lines of a whole top-level block, which keep its exact Markdown. */
    function blockSource(node: Element): string | undefined {
        if (!lines || !rendered || node.matches('tr,thead,tbody,tfoot,th,td')) return undefined;
        const start = Number(node.getAttribute('data-source-line')), end = Number(node.getAttribute('data-source-line-end'));
        if (!Number.isInteger(start) || !Number.isInteger(end) || start <= rendered.firstLine || end < start || end - rendered.firstLine > lines.length) return undefined;
        const text = lines.slice(start - 1 - rendered.firstLine, end - rendered.firstLine).join('\n').replace(/\s+$/, '');
        // Reference links and images can depend on definitions outside this block.
        // Convert the rendered selection so its destinations survive a standalone paste.
        if (rendered.hasReferences && text.includes('[') && node.querySelector('a[href], img')) return undefined;
        return text && wholly(node) ? text : undefined;
    }
    function clone(node: Node, nested = false): Node | null {
        if (!range.intersectsNode(node)) return null;
        if (node.nodeType === Node.TEXT_NODE) {
            const start = node === range.startContainer ? range.startOffset : 0;
            const end = node === range.endContainer ? range.endOffset : node.textContent?.length;
            return document.createTextNode((node.textContent || '').slice(start, end));
        }
        if (!(node instanceof Element) || node.matches(ignored)) return null;
        if (source && node.matches('.source-diff-line:not([data-source-line])')) return null;
        if (getComputedStyle(node).display === 'none') return null;
        // Blocks inside a partly selected block keep its markers in their lines; they convert instead.
        const sourceBlock = !nested && node.hasAttribute('data-source-line');
        const raw = sourceBlock ? blockSource(node) : undefined;
        if (raw !== undefined) {
            const block = document.createElement('div'); block.textContent = raw; block.dataset.selectionSource = raw;
            return block;
        }
        // A whole rendered diagram copies as the fenced source it came from.
        const diagram = !source && format === 'markdown' ? originalDiagramSource(node) : undefined;
        if (diagram && wholly(node)) {
            const pre = document.createElement('pre'), code = document.createElement('code');
            code.className = `language-${diagram.language}`; code.textContent = diagram.source;
            pre.append(code); return pre;
        }
        if (!source && format === 'markdown' && node.tagName === 'IMG') {
            // A relative path from the file always wins. Without one, long embedded data and the
            // preview's internal address are left out; web addresses and short data stay.
            const src = node.getAttribute('src') || '';
            const relative = relativeImageSource(node.getAttribute('data-original-image-source'));
            const base64 = /^data:image\/[^,]*;base64,/i.exec(src);
            if (relative || /^local-md:/i.test(src) || (base64 && src.length - base64[0].length > 200)) {
                if (!relative) return null;
                const image = node.cloneNode(false) as Element;
                image.setAttribute('src', relative);
                return image;
            }
        }
        const math = originalMathSource(node);
        if (math !== undefined) {
            if (wholly(node)) {
                const span = document.createElement('span'); span.textContent = math;
                // Raw math must survive Markdown escaping.
                span.dataset.selectionMath = math; return span;
            }
        }
        const copy = node.cloneNode(false) as Element;
        for (const child of Array.from(node.childNodes)) { const selected = clone(child, nested || sourceBlock); if (selected) copy.append(selected); }
        if (node.tagName === 'A' && node.querySelector('img') && !copy.textContent?.trim() && !copy.querySelector('img')) return null;
        if (node.tagName === 'TR' && copy.children.length !== node.children.length) copy.setAttribute('data-selection-partial', 'true');
        return copy;
    }
    const fragment = clone(root) as HTMLElement | null;
    if (!fragment) return null;
    if (source) {
        const lines = fragment.querySelectorAll('.source-diff-line');
        if (!lines.length) return fragment.textContent;
        // WebKit needs a newline inside empty rows for native selection copying.
        // Source rows represent individual lines, so only the join adds line breaks here.
        return Array.from(lines, line => {
            const text = line.textContent || '';
            return text === '\n' ? '' : text;
        }).join('\n');
    }
    if (format === 'plain') {
        // The block extractor handles whole quotes; selection tables need row boundaries.
        for (const table of Array.from(fragment.querySelectorAll('table'))) {
            const pre = document.createElement('pre');
            pre.textContent = Array.from(table.querySelectorAll('tr')).map(row => Array.from(row.children).map(cell => blockPlainText(cell)).join('\t')).join('\n');
            table.replaceWith(pre);
        }
        return blockPlainText(fragment);
    }
    return converter.turndown(fragment);
}
converter.addRule('selection-source', {
    filter: node => node.hasAttribute('data-selection-source'),
    replacement: (_content, node) => '\n\n' + ((node as HTMLElement).dataset.selectionSource || '') + '\n\n',
});
converter.addRule('selection-math', {
    filter: node => node.hasAttribute('data-selection-math'),
    replacement: (_content, node) => (node as HTMLElement).dataset.selectionMath || '',
});
converter.addRule('partial-selection-table', {
    filter: node => node.tagName === 'TABLE' && (!node.querySelector('tr > th') || !!node.querySelector('[data-selection-partial]')),
    replacement: (_content, node) => '\n\n' + Array.from((node as Element).querySelectorAll('tr')).map(row =>
        Array.from(row.children).map(cell => converter.escape(blockPlainText(cell))).join('\t')).join('  \n') + '\n\n',
});

function isEditableInput(node: Node | null): boolean {
    const element = node instanceof Element ? node : node?.parentElement;
    return !!element?.closest(editableInput);
}

/** Clamp a selection range (e.g. Select All on document.body) to the bounds of `root`. */
export function clampRangeToRoot(root: HTMLElement, range: Range): Range | null {
    if (range.collapsed || !range.intersectsNode(root)) return null;
    const whole = document.createRange();
    whole.selectNodeContents(root);
    const clamped = range.cloneRange();
    if (clamped.compareBoundaryPoints(Range.START_TO_START, whole) < 0) {
        clamped.setStart(whole.startContainer, whole.startOffset);
    }
    if (clamped.compareBoundaryPoints(Range.END_TO_END, whole) > 0) {
        clamped.setEnd(whole.endContainer, whole.endOffset);
    }
    if (clamped.collapsed || !root.contains(clamped.startContainer) || !root.contains(clamped.endContainer)) {
        return null;
    }
    return clamped;
}

/**
 * In Source View, native WebKit copy writes styled HTML/RTF alongside plain text.
 * Rich-text paste targets that prefer HTML can strip CSS block layout or carry
 * source styles, merging adjacent lines. Writing only `text/plain` keeps Cmd+C
 * faithful to the raw source across all paste targets.
 */
export function copySourceSelectionAsPlainText(event: ClipboardEvent, root: HTMLElement | null): boolean {
    if (!root?.classList.contains('source-mode') || !root.querySelector('.source-diff-content') || !event.clipboardData) return false;
    if (isEditableInput(event.target as Node | null) || isEditableInput(document.activeElement)) return false;
    const selection = window.getSelection();
    if (!selection?.rangeCount || selection.isCollapsed) return false;
    if (isEditableInput(selection.anchorNode) || isEditableInput(selection.focusNode)) return false;
    const clamped = clampRangeToRoot(root, selection.getRangeAt(0));
    if (!clamped) return false;
    const text = selectedContent(root, clamped, 'plain');
    if (!text) return false;
    event.preventDefault();
    event.clipboardData.setData('text/plain', text);
    return true;
}
