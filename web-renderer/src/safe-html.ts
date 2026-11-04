import DOMPurify from 'dompurify';

export function sanitizeMathHTML(html: string): string {
    const fragment = DOMPurify.sanitize(html, {
        USE_PROFILES: { html: true, svg: true, mathMl: true },
        ADD_TAGS: ['mjx-container', 'mjx-assistive-mml', 'use'],
        ADD_ATTR: ['jax', 'display', 'overflow'],
        FORBID_TAGS: ['style', 'script', 'iframe', 'object', 'embed', 'form', 'input', 'button', 'textarea', 'select', 'base', 'link', 'meta', 'foreignObject', 'img', 'audio', 'video', 'source'],
        FORBID_ATTR: ['srcdoc', 'name', 'autofocus'],
        RETURN_DOM_FRAGMENT: true,
    });
    const identities = new Map<string, Element[]>();
    fragment.querySelectorAll('[id]').forEach(node => {
        const id = node.getAttribute('id')!;
        identities.set(id, [...(identities.get(id) || []), node]);
    });
    fragment.querySelectorAll('use').forEach(node => {
        const refs = Array.from(node.attributes).filter(attr => attr.localName === 'href').map(attr => attr.value);
        const valid = refs.length > 0 && refs.every(ref => {
            if (!/^#[^\s]+$/.test(ref)) return false;
            const targets = identities.get(ref.slice(1));
            return targets?.length === 1 && targets[0].matches('path, g') && !!targets[0].closest('defs');
        });
        if (!valid || new Set(refs).size !== 1) node.remove();
    });
    // Math links are internal references. Their actual targets are validated by
    // the document session after all mathematical items have been collected.
    fragment.querySelectorAll('a').forEach(node => {
        for (const attribute of Array.from(node.attributes)) {
            if (attribute.localName === 'href' && !/^#[^\s]+$/.test(attribute.value)) node.removeAttributeNode(attribute);
        }
    });
    fragment.querySelectorAll('[style]').forEach(node => {
        if (/url\s*\(|@import|expression\s*\(/i.test(node.getAttribute('style') || '')) node.removeAttribute('style');
    });
    const container = document.createElement('div');
    container.appendChild(fragment);
    return container.innerHTML;
}

/** Documents may contain presentation HTML, never executable page content. */
export function sanitizeDocumentHTML(html: string): string {
    return DOMPurify.sanitize(html, {
        USE_PROFILES: { html: true, svg: true, mathMl: true },
        FORBID_TAGS: ['style', 'script', 'iframe', 'object', 'embed', 'form', 'button', 'textarea', 'select', 'base', 'link', 'meta', 'foreignObject'],
        FORBID_ATTR: ['srcdoc', 'name', 'autofocus'],
        ADD_URI_SAFE_ATTR: ['data-source-line', 'data-source-line-end'],
        ALLOWED_URI_REGEXP: /^(?:(?:https?|mailto|local-md|file):|[^a-z]|[a-z+.\-]+(?:[^a-z+.\-:]|$))/i,
    });
}

/** Diagram engines also embed user-provided links; sanitize their SVG output. */
export function sanitizeDiagramHTML(html: string): string {
    const fragment = DOMPurify.sanitize(html, {
        USE_PROFILES: { html: true, svg: true, svgFilters: true, mathMl: true },
        ADD_TAGS: ['foreignobject', 'use'],
        HTML_INTEGRATION_POINTS: { foreignobject: true, 'annotation-xml': true },
        FORBID_TAGS: ['script', 'iframe', 'object', 'embed', 'form', 'input', 'button', 'base', 'link', 'meta'],
        FORBID_ATTR: ['srcdoc', 'autofocus'],
        RETURN_DOM_FRAGMENT: true,
    });
    // Typst represents glyphs with local SVG use references. Never permit use
    // to load external SVG content even when other diagram links use https.
    fragment.querySelectorAll('use').forEach(node => {
        const references = Array.from(node.attributes).filter(attr => attr.localName === 'href').map(attr => attr.value);
        if (references.length === 0 || references.some(href => !/^#[^\s]+$/.test(href))) node.remove();
    });
    const container = document.createElement('div');
    container.appendChild(fragment);
    return container.innerHTML;
}
