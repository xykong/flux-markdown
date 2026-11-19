import { selectedContent, CopyFormat } from './selection-content';
import { nativeCopy, nextCopyID } from './block-copy';

const labels: Record<string, string[]> = {
    en: ['Copy as Plain Text', 'Copy as Markdown', 'Copied', 'Copy was not confirmed. Retry, or use Open in FluxMarkdown.', 'Retry'],
    zh: ['复制为纯文本', '复制为 Markdown', '已复制', '复制未确认。请重试，或用 FluxMarkdown 打开。', '重试'],
    de: ['Als Klartext kopieren', 'Als Markdown kopieren', 'Kopiert', 'Kopieren nicht bestätigt. Erneut versuchen oder in FluxMarkdown öffnen.', 'Erneut versuchen'],
    fr: ['Copier en texte brut', 'Copier en Markdown', 'Copié', 'Copie non confirmée. Réessayez ou ouvrez dans FluxMarkdown.', 'Réessayer'],
    es: ['Copiar como texto sin formato', 'Copiar como Markdown', 'Copiado', 'Copia no confirmada. Reintenta o abre en FluxMarkdown.', 'Reintentar'],
    ar: ['نسخ كنص عادي', 'نسخ بصيغة Markdown', 'تم النسخ', 'لم يتم تأكيد النسخ. أعد المحاولة أو افتح في FluxMarkdown.', 'إعادة المحاولة'],
};
/** What a successful copy reports: line count and format, e.g. "Copied 3 lines as plain text". */
const copiedLabels: Record<string, (lines: number, markdown: boolean) => string> = {
    en: (n, md) => `Copied ${n} ${n === 1 ? 'line' : 'lines'} as ${md ? 'Markdown' : 'plain text'}`,
    zh: (n, md) => `已复制 ${n} 行${md ? ' Markdown' : '纯文本'}`,
    de: (n, md) => `${n} ${n === 1 ? 'Zeile' : 'Zeilen'} als ${md ? 'Markdown' : 'Klartext'} kopiert`,
    fr: (n, md) => `${n} ${n === 1 ? 'ligne copiée' : 'lignes copiées'} en ${md ? 'Markdown' : 'texte brut'}`,
    es: (n, md) => `${n} ${n === 1 ? 'línea copiada' : 'líneas copiadas'} como ${md ? 'Markdown' : 'texto sin formato'}`,
    ar: (n, md) => `تم نسخ ${n} ${n === 1 ? 'سطر' : 'أسطر'} ${md ? 'بصيغة Markdown' : 'كنص عادي'}`,
};
export function copiedMessage(language: string, text: string, format: CopyFormat): string {
    const lines = text.replace(/\n$/, '').split('\n').length;
    return (copiedLabels[language] || copiedLabels.en)(lines, format === 'markdown');
}
export interface SelectionCopyOptions { context?: string; selectionCopy?: boolean; format?: string; showCopyButtons?: boolean }
export function selectionCopyEnabled(options: SelectionCopyOptions): boolean {
    return options.context === 'quicklook' && options.selectionCopy === true && (!options.format || options.format === 'markdown');
}
export function installSelectionCopy(root: HTMLElement, generation: string, options: SelectionCopyOptions): () => void {
    if (!selectionCopyEnabled(options)) return () => {};
    const language = (window.__fluxLang || navigator.language).split('-')[0];
    const strings = labels[language] || labels.en;
    let feedbackTimer: ReturnType<typeof setTimeout> | undefined;
    const tools = document.createElement('div'); tools.className = 'selection-copy-tools'; tools.hidden = true;
    tools.setAttribute('role', 'group'); tools.setAttribute('aria-label', strings[0]);
    const status = document.createElement('span'); status.setAttribute('role', 'status');
    let snapshot: Range | null = null, busy = false, disposed = false, dragging = false, revision = 0;
    let suppressPopup = false;
    let suppressedSelection: Range | null = null;
    let frame = 0;
    /** Where the pointer let go of the current selection, in document coordinates. */
    let pointerEnd: { pageX: number; pageY: number } | null = null;
    const listeners: Array<() => void> = [];
    function listen(target: EventTarget, type: string, handler: EventListener): void {
        target.addEventListener(type, handler); listeners.push(() => target.removeEventListener(type, handler));
    }
    function editable(node: Node | null): boolean {
        const element = node instanceof Element ? node : node?.parentElement;
        return !!element?.closest('button,input,textarea,select,[contenteditable="true"],.selection-copy-tools,.block-copy-tools,.error-feedback-controls,.diagram-tools,.mermaid-tools');
    }
    function capture(): Range | null {
        const selection = window.getSelection();
        if (!selection?.rangeCount || selection.isCollapsed || editable(document.activeElement) || editable(selection.anchorNode) || editable(selection.focusNode)) return null;
        const range = selection.getRangeAt(0);
        return root.contains(range.startContainer) && root.contains(range.endContainer) ? range.cloneRange() : null;
    }
    function position(): void {
        if (!snapshot || tools.hidden) return;
        const width = tools.offsetWidth, height = tools.offsetHeight;
        // A selection made with the pointer gets its toolbar next to where the pointer
        // let go; it keeps that place in the document while scrolling.
        if (pointerEnd) {
            const x = pointerEnd.pageX - scrollX, y = pointerEnd.pageY - scrollY;
            if (y < 0 || y > innerHeight) { tools.hidden = true; return; }
            tools.style.left = `${Math.max(8, Math.min(x + 8, innerWidth - width - 8))}px`;
            tools.style.top = `${Math.max(8, y + 14 + height + 8 < innerHeight ? y + 14 : y - height - 10)}px`;
            return;
        }
        const rects = Array.from(snapshot.getClientRects());
        const rect = rects.reverse().find(r => r.bottom > 0 && r.top < innerHeight && r.right > 0 && r.left < innerWidth);
        if (!rect) { tools.hidden = true; return; }
        tools.style.left = `${Math.max(8, Math.min(rect.left, innerWidth - width - 8))}px`;
        tools.style.top = `${Math.max(8, rect.bottom + height + 8 < innerHeight ? rect.bottom + 6 : rect.top - height - 6)}px`;
    }
    function update(): void {
        frame = 0;
        if (disposed || dragging || tools.contains(document.activeElement)) return;
        if (suppressPopup) { tools.hidden = true; return; }
        const previous = snapshot;
        snapshot = capture(); ++revision;
        // Keep the "Copied …" report while the same text stays selected.
        if (feedbackTimer && snapshot && previous && sameRange(snapshot, previous)) { tools.hidden = false; position(); return; }
        clearFeedback();
        tools.hidden = !snapshot || options.showCopyButtons !== true;
        position();
    }
    function sameRange(a: Range, b: Range): boolean {
        return a.startContainer === b.startContainer && a.startOffset === b.startOffset && a.endContainer === b.endContainer && a.endOffset === b.endOffset;
    }
    function clearFeedback(): void {
        if (feedbackTimer) { clearTimeout(feedbackTimer); feedbackTimer = undefined; }
        status.textContent = ''; status.className = ''; delete tools.dataset.copyState;
        plainButton.textContent = '⧉'; markdownButton.textContent = 'MD';
    }
    function schedule(): void { if (!frame) frame = requestAnimationFrame(update); }
    async function copy(format: CopyFormat): Promise<void> {
        if (disposed || busy || !snapshot) return;
        const text = selectedContent(root, snapshot, format);
        if (!text) return;
        const copied = snapshot;
        clearFeedback();
        const button = format === 'markdown' ? markdownButton : plainButton;
        busy = true; tools.dataset.copyState = "pending"; plainButton.disabled = markdownButton.disabled = true;
        const success = new TextEncoder().encode(text).length <= 4 * 1024 * 1024 &&
            await nativeCopy({ id: nextCopyID(), generation, text }, 'selectionCopy');
        busy = false; plainButton.disabled = markdownButton.disabled = false;
        if (disposed) return;
        // Every copy reports its result, from the toolbar or the menu, even when the
        // selection changed meanwhile or the toolbar is turned off.
        snapshot = copied; tools.hidden = false;
        tools.dataset.copyState = success ? 'success' : 'error';
        if (success) button.textContent = '✓';
        status.textContent = success ? copiedMessage(language, text, format) : strings[3];
        status.className = success ? '' : 'block-copy-error';
        if (!success) {
            const retry = document.createElement('button'); retry.type = 'button'; retry.textContent = strings[4];
            retry.addEventListener('click', event => { if (event.isTrusted) void copy(format); }); status.append(retry);
        } else {
            feedbackTimer = setTimeout(() => {
                clearFeedback();
                if (options.showCopyButtons !== true) tools.hidden = true;
                position();
            }, 2000);
        }
        position();
    }
    // Clicks only: some Quick Look hosts never pass a right-click to the preview.
    function copyButton(text: string, label: string, format: CopyFormat): HTMLButtonElement {
        const button = document.createElement('button'); button.type = 'button'; button.textContent = text;
        button.setAttribute('aria-label', label); button.title = label;
        button.addEventListener('pointerdown', event => event.preventDefault());
        button.addEventListener('click', event => { if (event.isTrusted) void copy(format); });
        return button;
    }
    const plainButton = copyButton('⧉', strings[0], 'plain');
    const markdownButton = copyButton('MD', strings[1], 'markdown');
    tools.append(plainButton, markdownButton, status); root.append(tools);
    // The native "Copy as Markdown" menu item copies through here, with the same report.
    const nativeAction = (format: CopyFormat = 'markdown'): void => {
        if (format !== 'plain' && format !== 'markdown') return;
        const current = capture(); if (current) snapshot = current;
        if (snapshot) void copy(format);
    };
    window.copyQuickLookSelection = nativeAction;
    function selectionChanged(event: Event): void {
        if (event.type === 'focusin' && editable(document.activeElement) && !tools.contains(document.activeElement)) {
            suppressedSelection = snapshot; suppressPopup = true; tools.hidden = true;
        }
        if (event.type === 'selectionchange' && !editable(document.activeElement)) {
            const current = capture();
            const same = current && suppressedSelection && current.startContainer === suppressedSelection.startContainer &&
                current.endContainer === suppressedSelection.endContainer && current.startOffset === suppressedSelection.startOffset && current.endOffset === suppressedSelection.endOffset;
            if (!same) suppressPopup = false;
        }
        schedule();
    }
    listen(document, 'selectionchange', selectionChanged);
    listen(document, 'focusin', selectionChanged);
    listen(document, 'pointerdown', event => {
        if (tools.contains(event.target as Node)) return;
        if (editable(event.target as Node)) {
            // A block copy button copies its block, not the selection; drop the
            // selection so its highlight does not suggest it was copied too.
            if ((event.target as Element | null)?.closest?.('.block-copy-tools')) window.getSelection()?.removeAllRanges();
            // Existing block buttons own this gesture. Do not revive a popup
            // from an earlier selection while focus/disabled state changes.
            suppressedSelection = capture(); suppressPopup = true; snapshot = null;
            ++revision; dragging = false; tools.hidden = true;
            return;
        }
        suppressPopup = false;
        // A right-click opens the context menu on the current selection; it starts no new one.
        if ((event as PointerEvent).button !== 0) return;
        dragging = true; tools.hidden = true; status.className = '';
    });
    listen(document, 'pointerup', event => {
        const pointer = event as PointerEvent;
        pointerEnd = tools.contains(pointer.target as Node) ? pointerEnd : { pageX: pointer.clientX + scrollX, pageY: pointer.clientY + scrollY };
        dragging = false; schedule();
    });
    // A selection changed from the keyboard is placed by its text again.
    listen(document, 'keyup', event => { if ((event as KeyboardEvent).shiftKey) { pointerEnd = null; schedule(); } });
    listen(document, 'keydown', event => {
        const key = event as KeyboardEvent;
        if (key.key === 'Escape') { tools.hidden = true; (document.activeElement as HTMLElement | null)?.blur(); }
        if (tools.contains(key.target as Node) && ['ArrowLeft','ArrowRight','Home','End'].includes(key.key)) {
            const buttons = Array.from(tools.querySelectorAll('button'));
            const current = buttons.indexOf(document.activeElement as HTMLButtonElement);
            const next = key.key === 'Home' ? 0 : key.key === 'End' ? buttons.length - 1 : (current + (key.key === 'ArrowLeft' ? buttons.length - 1 : 1)) % buttons.length;
            buttons[next]?.focus(); key.preventDefault();
        }
        if (key.altKey && key.key.toLowerCase() === 'c' && snapshot && !editable(document.activeElement)) {
            tools.hidden = false; position(); tools.querySelector('button')?.focus(); key.preventDefault();
        }
    });
    listen(window, 'resize', () => position()); listen(document, 'scroll', () => position());
    return () => {
        disposed = true; cancelAnimationFrame(frame); for (const remove of listeners) remove(); tools.remove(); snapshot = null;
        if (window.copyQuickLookSelection === nativeAction) delete window.copyQuickLookSelection;
    };
}
