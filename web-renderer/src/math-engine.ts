import { ensureMathCompatibility } from './math-compat';
import { mathjax } from '@mathjax/src/js/mathjax.js';
import { browserAdaptor } from '@mathjax/src/js/adaptors/browserAdaptor.js';
import { RegisterHTMLHandler } from '@mathjax/src/js/handlers/html.js';
import { AssistiveMmlHandler } from '@mathjax/src/js/a11y/assistive-mml.js';
import { SVG } from '@mathjax/src/js/output/svg.js';
import { MathML } from '@mathjax/src/js/input/mathml.js';
import { createMathInput } from './math-identity';
import { installMathFontLoader } from './math-font-loader';
import { sanitizeMathHTML } from './safe-html';
import type { MathSource } from './math-syntax';
import { partitionMathSources } from './math-limits';

const adaptor = browserAdaptor();
AssistiveMmlHandler(RegisterHTMLHandler(adaptor));
installMathFontLoader();

export interface MathEngineResult {
    items: Array<{ id: string; html: string }>;
    errors: Array<{ sourceId: string; code: 'syntax' | 'unresolved-reference' | 'input-limit' }>;
    css: string;
}

/** One isolated semantic document; the caller owns publication/generation checks. */
export async function renderMathSources(sources: readonly MathSource[], namespace: string, host?: HTMLElement): Promise<MathEngineResult> {
    ensureMathCompatibility();
    const { accepted, rejected } = partitionMathSources(sources);
    if (rejected.length) {
        const result = accepted.length ? await renderMathSources(accepted, namespace, host) : { items: [], errors: [], css: '' } satisfies MathEngineResult;
        const rendered = new Map(result.items.map(item => [item.id, item.html]));
        for (const source of rejected) {
            const text = document.createElement('span');
            text.textContent = source.raw;
            rendered.set(source.id, text.innerHTML);
        }
        return { items: sources.map(source => ({ id: source.id, html: rendered.get(source.id)! })),
            errors: [...rejected.map(source => ({sourceId:source.id,code:'input-limit' as const})), ...result.errors], css: result.css };
    }
    const stage = document.createElement('div');
    const style = host ? getComputedStyle(host) : null;
    const padding = style ? (parseFloat(style.paddingLeft) || 0) + (parseFloat(style.paddingRight) || 0) : 0;
    const width = Math.max(1, (host?.clientWidth || document.documentElement.clientWidth || 800) - padding);
    stage.style.cssText = 'position:absolute;left:-100000px;visibility:hidden;pointer-events:none;direction:ltr;';
    stage.dataset.mathMeasurement = namespace;
    stage.style.width = `${width}px`;
    stage.style.fontSize = style?.fontSize || '18px';
    stage.style.fontFamily = style?.fontFamily || 'system-ui';
    stage.style.fontWeight = style?.fontWeight || 'normal';
    stage.setAttribute('aria-hidden', 'true');
    const nodes = sources.map(source => {
        const node = document.createElement(source.display ? 'div' : 'span');
        if (source.kind === 'mathml') node.innerHTML = sanitizeMathHTML(source.payload);
        else node.textContent = (source.display ? '\\[' : '\\(') + source.payload + (source.display ? '\\]' : '\\)');
        stage.appendChild(node);
        return node;
    });
    document.body.appendChild(stage);
    const svg = new SVG<HTMLElement, Text, Document>({ fontCache: 'local', linebreaks: { inline: false }, displayOverflow: 'scroll' });
    const doc = mathjax.document(document, { InputJax: [createMathInput(namespace), new MathML()], OutputJax: svg,
        enableAssistiveMml: true });
    try {
        doc.findMath({ elements: [stage] });
        await doc.renderPromise();
        const failed = new Set(nodes.filter(node => node.querySelector('[data-mml-node="merror"], merror')));
        const errors: MathEngineResult['errors'] = [];
        nodes.forEach((node, index) => {
            if (failed.has(node)) errors.push({ sourceId: sources[index].id, code: 'syntax' });
            let unresolved = false;
            node.querySelectorAll('a').forEach(link => {
                const href = link.getAttribute('href') || link.getAttribute('data-mjx-href') || '';
                let id = '';
                try { if (href.startsWith('#')) id = decodeURIComponent(href.slice(1)); } catch { /* invalid fragment */ }
                const targets = Array.from(stage.querySelectorAll('[id]')).filter(target => target.id === id);
                if (!id || targets.length !== 1 || Array.from(failed).some(container => container.contains(targets[0]))) {
                    link.removeAttribute('href'); link.removeAttribute('data-mjx-href'); unresolved = true;
                } else {
                    link.setAttribute('href', '#'+encodeURIComponent(id));
                    link.setAttribute('tabindex', '0');
                }
            });
            if (unresolved) errors.push({ sourceId: sources[index].id, code: 'unresolved-reference' });
        });
        return {
            items: nodes.map((node, index) => ({ id: sources[index].id, html: sanitizeMathHTML(node.innerHTML) })),
            errors,
            css: adaptor.textContent(svg.styleSheet(doc)),
        };
    } finally {
        doc.clear();
        stage.remove();
    }
}
