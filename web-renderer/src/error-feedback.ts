import './styles/error-feedback.css';

type ErrorKind = 'renderer' | 'source' | 'mermaid' | 'typst' | 'graphviz' | 'vega' | 'math' | 'search' | 'images' | 'copy';
let generation = '';
export function feedbackGeneration(): string { return generation; }
let nextID = 0;
const groupIDs = new Map<string, string>();
export function setFeedbackGeneration(value: string): void {
    if (value !== generation) groupIDs.clear();
    generation = value;
}
const selectors: Array<[string, ErrorKind]> = [
    ['.block-copy-error', 'copy'], ['.mermaid-error', 'mermaid'], ['.typst-error', 'typst'], ['.graphviz-error', 'graphviz'], ['.vega-error', 'vega'],
    ['.math-error', 'math'], ['.katex-error', 'math'], ['.search-error', 'search'], ['.render-error', 'renderer'], ['.source-render-error', 'source'], ['img.image-load-failed', 'images'],
];

export function installErrorFeedback(root: HTMLElement): () => void {
    const attached = new WeakMap<Element, string>();
    const externalControls = new Map<HTMLElement, HTMLElement>();
    function scan(): void {
        for (const [element, controls] of externalControls) {
            if (!root.contains(element) || (element.tagName === 'IMG' && !element.classList.contains('image-load-failed'))) {
                const region = controls.parentElement;
                controls.remove(); externalControls.delete(element); attached.delete(element);
                if (region?.classList.contains('error-feedback-region')) region.replaceWith(...Array.from(region.childNodes));
            }
        }
        for (const [selector, kind] of selectors) {
            root.querySelectorAll<HTMLElement>(selector).forEach(element => {
                if (!generation || element.style.display === 'none') return;
                if (element.parentElement?.closest(selectors.map(([selector]) => selector).join(','))) return;
                if (attached.get(element) === generation && (element.querySelector('.error-feedback-controls') || externalControls.get(element)?.isConnected)) return;
                attached.set(element, generation);
                const eventGeneration = generation;
                // Equivalent module failures in one document share a bounded incident.
                const mathReasons: Record<string, string> = { syntax: 'mathSyntax', output: 'mathOutput', 'unresolved-reference': 'mathReference', 'input-limit': 'mathLimit' };
                const mathReason = kind === 'math' ? mathReasons[element.dataset.mathFailure || ''] : undefined;
                const reason = element.classList.contains('module-load-error') ? 'moduleUnavailable' : kind === 'images' || element.classList.contains('math-resource-unsupported') ? 'resourceUnavailable' : kind === 'search' ? 'invalidInput' : mathReason || 'operationFailed';
                const group = kind + ':' + reason;
                const sourceBlock = element.closest<HTMLElement>('[data-source-line]');
                const first = Number(element.dataset.mathFirst ?? sourceBlock?.dataset.sourceLine);
                const last = Number(element.dataset.mathLast ?? sourceBlock?.dataset.sourceLineEnd);
                const sourceRange = Number.isInteger(first) && Number.isInteger(last) && first > 0 && last >= first && last - first < 100 && last <= 1000000 ? {lineStart:first, lineEnd:last} : {};
                const shareIncident = reason === 'moduleUnavailable' || (kind !== 'math' && sourceRange.lineStart === undefined);
                const id = (shareIncident ? groupIDs.get(group) : undefined) || String(++nextID);
                if (shareIncident) groupIDs.set(group, id);
                const language = (window.__fluxLang || navigator.language).split('-')[0];
                const labels: Record<string, string> = {en:'Feedback', zh:'反馈', de:'Feedback', fr:'Signaler', es:'Informar', ar:'ملاحظات'};
                const controls = document.createElement('span'); controls.className = 'error-feedback-controls';
                const trigger = document.createElement('button'); trigger.type = 'button';
                trigger.className = 'error-feedback-trigger'; trigger.dataset.feedbackAction = 'inspect';
                trigger.setAttribute('aria-haspopup', 'dialog');
                const icon = document.createElement('span'); icon.textContent = '!'; icon.setAttribute('aria-hidden','true');
                const label = document.createElement('span'); label.textContent = labels[language] || labels.en;
                trigger.append(icon, document.createTextNode(' '), label);
                const post = (action: 'record' | 'inspect'): void => {
                    if (generation !== eventGeneration || !root.contains(element)) return;
                    const bridge = window.webkit?.messageHandlers.errorFeedback;
                    if (bridge) bridge.postMessage({action, kind, generation:eventGeneration, id, reason, ...sourceRange});
                    else if (action === 'inspect') {
                        const fallback: Record<string,string> = {en:'Open FluxMarkdown → Help → Report an Issue.', zh:'请打开 FluxMarkdown → 帮助 → 报告问题。', de:'Öffne FluxMarkdown → Hilfe → Problem melden.', fr:'Ouvrez FluxMarkdown → Aide → Signaler un problème.', es:'Abre FluxMarkdown → Ayuda → Informar de un problema.', ar:'افتح FluxMarkdown ← مساعدة ← الإبلاغ عن مشكلة.'};
                        trigger.title = fallback[language] || fallback.en;
                        trigger.setAttribute('aria-description',trigger.title);
                    }
                };
                trigger.addEventListener('click',event=>{event.preventDefault();event.stopPropagation();post('inspect');});
                controls.append(trigger);
                const inline = element.tagName === 'IMG' || element.tagName === 'SPAN';
                const region = document.createElement(inline ? 'span' : 'div');
                region.className = 'error-feedback-region' + (inline ? ' error-feedback-region-inline' : '');
                element.before(region); region.append(element, controls);
                externalControls.set(element,controls);
                post('record');
            });
        }
    }
    const observer = new MutationObserver(scan);
    observer.observe(root, { childList: true, subtree: true, attributes: true, attributeFilter: ['class', 'style'] });
    scan();
    return () => observer.disconnect();
}
