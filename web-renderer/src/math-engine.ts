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
    errors: Array<{ sourceId: string; code: 'syntax' | 'output' | 'unresolved-reference' | 'input-limit' }>;
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
    // Direct paths avoid WebKit's additional SVG <use> shadow trees. The
    // resulting standalone SVG is larger; the 1000-item DOM budget is tested.
    const svg = new SVG<HTMLElement, Text, Document>({ fontCache: 'none', linebreaks: { inline: false }, displayOverflow: 'scroll' });
    const doc = mathjax.document(document, { InputJax: [createMathInput(namespace), new MathML()], OutputJax: svg,
        enableAssistiveMml: true });
    document.body.appendChild(stage);
    try {
        doc.findMath({ elements: [stage] });
        await doc.renderPromise();
        const outputFailed = new Set(nodes.filter(node => node.querySelector('.mjx-output-error')));
        const failed = new Set(nodes.filter(node => outputFailed.has(node) || node.querySelector('[data-mml-node="merror"], merror')));
        const errors: MathEngineResult['errors'] = [];
        nodes.forEach((node, index) => {
            if (failed.has(node)) errors.push({ sourceId: sources[index].id, code: outputFailed.has(node) ? 'output' : 'syntax' });
            let unresolved = false;
            const references: Array<{href:string;label:string}> = [];
            node.querySelectorAll('a').forEach(link => {
                const href = link.getAttribute('href') || link.getAttribute('data-mjx-href') || '';
                let id = '';
                try { if (href.startsWith('#')) id = decodeURIComponent(href.slice(1)); } catch { /* invalid fragment */ }
                const targets = Array.from(stage.querySelectorAll('[id]')).filter(target => target.id === id);
                if (!id || targets.length !== 1 || Array.from(failed).some(container => container.contains(targets[0]))) {
                    link.removeAttribute('href'); link.removeAttribute('data-mjx-href'); unresolved = true;
                } else {
                    const localHref = '#'+encodeURIComponent(id);
                    const semantic = Array.from(node.querySelectorAll('mjx-assistive-mml [href]')).find(item => item.getAttribute('href') === href);
                    references.push({href:localHref,label:semantic?.textContent?.trim() || sources[index].payload});
                    // Visual SVG stays aria-hidden. Navigation is exposed as an
                    // ordinary HTML link outside that hidden subtree below.
                    const group = document.createElementNS('http://www.w3.org/2000/svg','g');
                    for (const attr of Array.from(link.attributes)) {
                        if (!['href','data-mjx-href','tabindex'].includes(attr.name)) group.setAttribute(attr.name,attr.value);
                    }
                    group.append(...Array.from(link.childNodes));link.replaceWith(group);
                }
            });
            if (references.length) {
                const unique = references.filter((ref,i)=>references.findIndex(other=>other.href===ref.href)===i);
                const standalone = unique.length === 1 && /^\\(?:eqref|ref)\{[^{}]+\}$/.test(sources[index].payload.trim());
                if (standalone) {
                    const link = document.createElement('a');link.href=unique[0].href;link.setAttribute('aria-label',unique[0].label);
                    link.className='math-reference-link';link.append(...Array.from(node.childNodes));node.append(link);
                } else {
                    const links = document.createElement('span');links.className='math-reference-links';
                    for (const ref of unique) { const link=document.createElement('a');link.href=ref.href;link.textContent=ref.label;links.append(link); }
                    node.append(links);
                }
            }
            if (unresolved) errors.push({ sourceId: sources[index].id, code: 'unresolved-reference' });
        });
        nodes.forEach((node, index) => {
            if (outputFailed.has(node)) node.textContent = sources[index].raw;
        });
        return {
            items: nodes.map((node, index) => ({ id: sources[index].id, html: sanitizeMathHTML(node.innerHTML) })),
            errors,
            css: adaptor.textContent(svg.styleSheet(doc)),
        };
    } finally {
        // HTMLDocument installs the output stylesheet in the shared document.
        // The caller publishes the returned CSS only after its generation check.
        // Remove this exact session's sheet, never a newer session's replacement.
        const sheet = svg.styleSheet(doc);
        if (sheet.parentNode) sheet.remove();
        doc.clear();
        stage.remove();
    }
}
