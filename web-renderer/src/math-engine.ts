import { ensureMathCompatibility } from './math-compat';
import { mathjax } from '@mathjax/src/js/mathjax.js';
import { browserAdaptor } from '@mathjax/src/js/adaptors/browserAdaptor.js';
import { RegisterHTMLHandler } from '@mathjax/src/js/handlers/html.js';
import { AssistiveMmlHandler } from '@mathjax/src/js/a11y/assistive-mml.js';
import { SVG } from '@mathjax/src/js/output/svg.js';
import { MathML } from '@mathjax/src/js/input/mathml.js';
import { STATE } from '@mathjax/src/js/core/MathItem.js';
import { createMathInput } from './math-identity';
import { installMathFontLoader } from './math-font-loader';
import { sanitizeMathHTML, sanitizeMathOutput } from './safe-html';
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
export async function renderMathSources(sources: readonly MathSource[], namespace: string, host?: HTMLElement, isCurrent: () => boolean = () => true): Promise<MathEngineResult> {
    const checkCurrent = () => { if (!isCurrent()) throw new Error('Mathematical render superseded'); };
    checkCurrent();
    ensureMathCompatibility();
    const { accepted, rejected } = partitionMathSources(sources);
    if (rejected.length) {
        const result = accepted.length ? await renderMathSources(accepted, namespace, host, isCurrent) : { items: [], errors: [], css: '' } satisfies MathEngineResult;
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
        enableAssistiveMml: true,
        renderActions: {
            currentBeforeCompile: [STATE.COMPILED - 1, () => { checkCurrent(); return false; }, '', false],
            currentBeforeTypeset: [STATE.TYPESET - 1, () => { checkCurrent(); return false; }, '', false],
        },
    });
    document.body.appendChild(stage);
    try {
        doc.findMath({ elements: [stage] });
        await doc.renderPromise();
        checkCurrent();
        const outputFailed = new Set(nodes.filter(node => node.querySelector('.mjx-output-error')));
        const failed = new Set(nodes.filter(node => outputFailed.has(node) || node.querySelector('[data-mml-node="merror"], merror')));
        const stageTargets = new Map<string, { count: number; failed: boolean }>();
        for (const node of nodes) {
            for (const target of node.querySelectorAll('[id]')) {
                const previous = stageTargets.get(target.id);
                stageTargets.set(target.id, { count: (previous?.count || 0) + 1, failed: failed.has(node) || previous?.failed === true });
            }
        }
        const errors: MathEngineResult['errors'] = [];
        nodes.forEach((node, index) => {
            if (failed.has(node)) errors.push({ sourceId: sources[index].id, code: outputFailed.has(node) ? 'output' : 'syntax' });
            let unresolved = false;
            const references: Array<{href:string;label:string}> = [];
            const referenceLabels = new Map<string, string>();
            node.querySelectorAll('mjx-assistive-mml [href]').forEach(item => {
                const href = item.getAttribute('href')!;
                if (!referenceLabels.has(href)) referenceLabels.set(href, item.textContent?.trim() || sources[index].payload);
            });
            node.querySelectorAll('a').forEach(link => {
                const href = link.getAttribute('href') || link.getAttribute('data-mjx-href') || '';
                let id = '';
                try { if (href.startsWith('#')) id = decodeURIComponent(href.slice(1)); } catch { /* invalid fragment */ }
                const target = stageTargets.get(id);
                if (!id || target?.count !== 1 || target.failed) {
                    link.removeAttribute('href'); link.removeAttribute('data-mjx-href'); unresolved = true;
                } else {
                    const localHref = '#'+encodeURIComponent(id);
                    references.push({href:localHref,label:referenceLabels.get(href) || sources[index].payload});
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
                const seen = new Set<string>();
                const unique = references.filter(ref => { if (seen.has(ref.href)) return false; seen.add(ref.href); return true; });
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
        const cleaned = nodes.map((node, index) => {
            const result = sanitizeMathOutput(node.innerHTML);
            if (result.paths !== node.querySelectorAll('svg path').length || result.formulas !== node.querySelectorAll('mjx-container').length) {
                errors.push({sourceId:sources[index].id, code:'output'});
            }
            return result;
        });
        const targets = new Map<string, string[]>();
        cleaned.forEach((item,index)=>item.ids.forEach(id=>targets.set(id,[...(targets.get(id)||[]),sources[index].id])));
        const dependants = new Map<string, Set<string>>();
        const invalid = new Set(errors.map(error=>error.sourceId));
        const unresolved = (sourceId: string) => {
            if (invalid.has(sourceId)) return;
            invalid.add(sourceId);errors.push({sourceId,code:'unresolved-reference'});
        };
        cleaned.forEach((item,index)=>item.links.forEach(href=>{
            let id='';try {id=decodeURIComponent(href.slice(1));} catch {unresolved(sources[index].id);return;}
            const owners=targets.get(id);
            if (!owners || owners.length!==1) {unresolved(sources[index].id);return;}
            const refs=dependants.get(owners[0]) || new Set<string>();
            refs.add(sources[index].id);dependants.set(owners[0],refs);
        }));
        const queue=Array.from(invalid);
        for (let index=0; index<queue.length; index++) {
            for (const sourceId of dependants.get(queue[index]) || []) {
                if (!invalid.has(sourceId)) {unresolved(sourceId);queue.push(sourceId);}
            }
        }

        const fallbackSources = new Set(errors.filter(error=>error.code==='output'||error.code==='unresolved-reference').map(error=>error.sourceId));
        return {
            items: cleaned.map((item,index)=>{
                if (fallbackSources.has(sources[index].id)) {
                    const text=document.createElement('span');text.textContent=sources[index].raw;
                    return {id:sources[index].id,html:text.innerHTML};
                }
                return {id:sources[index].id,html:item.html};
            }),
            errors,
            css: adaptor.textContent(svg.styleSheet(doc)),
        };
    } finally {
        // HTMLDocument installs the output stylesheet in the shared document.
        // The caller publishes the returned CSS only after its generation check.
        // Remove this exact session's sheet, never a newer session's replacement.
        const sheet = svg.styleSheet(doc);
        if (sheet.parentNode) sheet.remove();
        // The returned output consists of sanitized strings, not these staging
        // elements. Break their native descendant graphs before dropping the
        // MathJax list; delayed collection of a wrapper must not retain its SVG.
        for (const item of doc.math) {
            if (item.typesetRoot instanceof Element) item.typesetRoot.replaceChildren();
        }
        for (const node of nodes) node.replaceChildren();
        stage.replaceChildren();
        doc.clear();
        stage.remove();
    }
}
