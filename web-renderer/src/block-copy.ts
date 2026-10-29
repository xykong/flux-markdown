/** Plain-text copying. Document contents stay in memory, never in diagnostic messages. */
export interface CopyRequest { id: string; generation: string; text: string }
export interface CopyController { copy(block: HTMLElement): Promise<void>; dispose(): void }
const snapshots = new WeakMap<Element, string>();
const ignored = '.block-copy-tools, .error-feedback-controls, .blockquote-placeholder, svg, script, style';
const blocks = new Set(['P', 'DIV', 'BLOCKQUOTE', 'PRE', 'UL', 'OL', 'TABLE', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6']);
const labels: Record<string, [string, string, string, string, string]> = {
    en: ['Copy', 'Copied', 'Copy failed. Select the text to copy it manually, or retry.', 'Select Text', 'Copying…'],
    zh: ['复制', '已复制', '复制失败。可选择文本手动复制，或重试。', '选择文本', '正在复制…'],
    de: ['Kopieren', 'Kopiert', 'Kopieren fehlgeschlagen. Text zum manuellen Kopieren auswählen oder erneut versuchen.', 'Text auswählen', 'Wird kopiert…'],
    fr: ['Copier', 'Copié', 'Échec de la copie. Sélectionnez le texte pour le copier manuellement ou réessayez.', 'Sélectionner le texte', 'Copie…'],
    es: ['Copiar', 'Copiado', 'No se pudo copiar. Selecciona el texto para copiarlo manualmente o inténtalo de nuevo.', 'Seleccionar texto', 'Copiando…'],
    ar: ['نسخ', 'تم النسخ', 'تعذر النسخ. حدد النص لنسخه يدويًا أو أعد المحاولة.', 'تحديد النص', 'جارٍ النسخ…'],
};

export function blockPlainText(element: Element): string {
    function read(node: Node): string {
        if (node.nodeType === Node.TEXT_NODE) return node.textContent || '';
        if (!(node instanceof Element) || node.matches(ignored)) return '';
        if (node.tagName === 'PRE') return snapshots.get(node) ?? node.querySelector('code')?.textContent ?? node.textContent ?? '';
        if (node.tagName === 'IMG') return node.getAttribute('alt') || '';
        if (node.tagName === 'BR') return '\n';
        if (node.tagName === 'UL' || node.tagName === 'OL') return Array.from(node.children).map(read).join('\n');
        if (node.tagName === 'TR') return Array.from(node.children).map(read).join('\t');
        let result = '', previousBlock = false;
        for (const child of Array.from(node.childNodes)) {
            const text = read(child);
            if (!text || (child.nodeType === Node.TEXT_NODE && /^\s+$/.test(text) && text.includes('\n'))) continue;
            const isBlock = child instanceof Element && blocks.has(child.tagName);
            if (result && (isBlock || previousBlock)) result += result.endsWith('\n\n') ? '' : result.endsWith('\n') ? '\n' : '\n\n';
            result += text; previousBlock = isBlock;
        }
        return result;
    }
    return read(element);
}

let nextID = 0;
const pending = new Map<string, { generation: string; finish: (success: boolean) => void }>();
export function blockCopyResult(id: string, generation: string, success: boolean): void {
    const request = pending.get(id);
    if (request?.generation === generation) request.finish(success === true);
}
function nativeCopy(request: CopyRequest): Promise<boolean> {
    return new Promise(resolve => {
        const finish = (success: boolean): void => { clearTimeout(timeout); pending.delete(request.id); resolve(success); };
        const timeout = setTimeout(() => finish(false), 5000);
        pending.set(request.id, { generation: request.generation, finish });
        try {
            const bridge = window.webkit?.messageHandlers.blockCopy;
            if (!bridge) finish(false);
            else bridge.postMessage(request);
        } catch { finish(false); }
    });
}

export function installBlockCopy(root: HTMLElement, generation: string, send = nativeCopy): CopyController {
    const strings = labels[(window.__fluxLang || navigator.language).split('-')[0]] || labels.en;
    const entries = new Map<HTMLElement, { tools: HTMLElement; button: HTMLButtonElement; status: HTMLElement; wrapper?: HTMLElement; busy: boolean; timer?: ReturnType<typeof setTimeout> }>();
    const requestIDs = new Set<string>();
    const timers = new Set<ReturnType<typeof setTimeout>>();
    let disposed = false;
    // Snapshot before line-number decoration. Quotes use these same snapshots for nested code.
    root.querySelectorAll<HTMLElement>('pre').forEach(pre => snapshots.set(pre, pre.querySelector('code')?.textContent ?? pre.textContent ?? ''));
    const controller: CopyController = {
        async copy(block) {
            const entry = entries.get(block);
            if (disposed || !entry || !root.contains(block) || entry.busy) return;
            if (entry.timer) { clearTimeout(entry.timer); timers.delete(entry.timer); }
            entry.tools.dataset.copyState = 'pending';
            entry.busy = true; entry.button.disabled = true; entry.status.textContent = strings[4];
            const id = String(++nextID); requestIDs.add(id);
            const text = blockPlainText(block);
            let success = false;
            // The same UTF-8 bound is enforced natively; never truncate silently.
            if (new TextEncoder().encode(text).length <= 4 * 1024 * 1024) {
                try { success = await send({ id, generation, text }); } catch { success = false; }
            }
            requestIDs.delete(id);
            if (disposed || !root.contains(block)) return;
            entry.busy = false; entry.button.disabled = false;
            entry.tools.querySelector('.block-copy-error')?.remove();
            entry.tools.dataset.copyState = success ? 'success' : 'error';
            entry.status.textContent = success ? strings[1] : '';
            if (success) {
                const timer = setTimeout(() => { entry.status.textContent = ''; delete entry.tools.dataset.copyState; timers.delete(timer); }, 2000);
                entry.timer = timer; timers.add(timer);
            } else {
                const failure = document.createElement('div'); failure.className = 'block-copy-error';
                const message = document.createElement('span'); message.textContent = strings[2];
                const select = document.createElement('button'); select.type = 'button'; select.textContent = strings[3];
                select.addEventListener('click', event => {
                    event.preventDefault(); event.stopPropagation();
                    const range = document.createRange(); range.selectNodeContents(block.tagName === 'PRE' ? block.querySelector('code') || block : block);
                    if (block.firstChild === entry.tools && entry.tools.nextSibling) range.setStartBefore(entry.tools.nextSibling);
                    const selection = window.getSelection(); selection?.removeAllRanges(); selection?.addRange(range);
                });
                failure.append(message, select); entry.tools.append(failure);
            }
        },
        dispose() {
            disposed = true;
            for (const id of requestIDs) pending.get(id)?.finish(false);
            for (const timer of timers) clearTimeout(timer);
            for (const [block, entry] of entries) {
                entry.tools.remove();
                if (entry.wrapper?.parentNode) entry.wrapper.replaceWith(block);
            }
            entries.clear();
        },
    };
    root.querySelectorAll<HTMLElement>('pre, blockquote, .markdown-alert').forEach(block => {
        if (block.tagName === 'PRE' && (!block.querySelector('code') || block.querySelector('.typst-placeholder, .language-vega, .language-vega-lite, .language-dot, .language-graphviz'))) return;
        const tools = document.createElement('div'); tools.className = 'block-copy-tools';
        const button = document.createElement('button'); button.type = 'button'; button.textContent = '⧉';
        button.title = strings[0]; button.setAttribute('aria-label', strings[0]);
        const status = document.createElement('span'); status.setAttribute('role', 'status'); status.setAttribute('aria-live', 'polite');
        tools.append(button, status);
        let wrapper: HTMLElement | undefined;
        if (block.tagName === 'PRE') {
            wrapper = document.createElement('div'); wrapper.className = 'block-copy-host';
            block.before(wrapper); wrapper.append(tools, block);
        } else block.prepend(tools);
        entries.set(block, { tools, button, status, wrapper, busy: false });
        button.addEventListener('click', event => {
            event.preventDefault(); event.stopPropagation();
            if (event.isTrusted) void controller.copy(block);
        });
    });
    return controller;
}
