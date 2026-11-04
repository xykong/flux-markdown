/** Split an enclosing document link around a formula with its own destinations. */
export function separateMathLinks(formula: Element): void {
    const outer = formula.parentElement?.closest('a');
    if (!outer || !formula.querySelector('a[href]')) return;
    const before = document.createRange();
    before.selectNodeContents(outer); before.setEndBefore(formula);
    const prefix = before.extractContents();
    const after = document.createRange();
    after.selectNodeContents(outer); after.setStartAfter(formula);
    const suffix = after.extractContents();
    const replacement = document.createDocumentFragment();
    let parts = 0;
    const appendPart = (part: DocumentFragment) => {
        if (!part.textContent && !part.querySelector('img')) return;
        const link = outer.cloneNode(false) as Element;
        link.removeAttribute('id');link.appendChild(part);replacement.appendChild(link);
        parts++;
    };
    appendPart(prefix);
    replacement.appendChild(formula);
    appendPart(suffix);
    if (!parts) {
        const alternative = outer.cloneNode(false) as Element;
        alternative.removeAttribute('id');alternative.textContent=outer.getAttribute('href') || '';
        alternative.classList.add('math-enclosing-link');replacement.append(alternative);
    }
    // Preserve an explicit anchor identity without duplicating it on split links.
    if (outer.id) { const anchor = document.createElement('span');anchor.id=outer.id;replacement.prepend(anchor); }
    outer.replaceWith(replacement);
}
