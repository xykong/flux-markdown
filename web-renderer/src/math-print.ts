/** Temporary semantic groups for WebKit pagination; original nodes are retained. */
export function prepareMathPrint(root: HTMLElement): () => void {
    const groups: HTMLElement[] = [];
    root.querySelectorAll('h1,h2,h3,h4,h5,h6,p').forEach(heading => {
        if (heading.tagName === 'P') {
            const text = heading.textContent?.trim() || '';
            if (text.length > 200 || !/[:：]$/.test(text) || heading.querySelector('mjx-container')) return;
        }
        const next = heading.nextElementSibling;
        if (!next?.matches('div.flux-math-source, .block-copy-host')) return;
        if (next.classList.contains('block-copy-host') && !next.querySelector('div.flux-math-source')) return;
        const group = document.createElement('div');
        group.className = 'math-print-group';
        heading.before(group);group.append(heading,next);groups.push(group);
    });
    return () => groups.forEach(group => { if (group.parentNode) group.replaceWith(...Array.from(group.childNodes)); });
}
