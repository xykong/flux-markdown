/** Source is kept out of rendered HTML and diagnostic payloads. */
const sourceByElement = new WeakMap<Element, string>();
export function rememberMathSource(element: Element, source: string): void {
    sourceByElement.set(element, source);
}
export function originalMathSource(element: Element): string | undefined {
    return sourceByElement.get(element);
}

/** Index a whole document once; ambiguous IDs must never acquire trusted source. */
export function uniqueMathTargets(root: ParentNode, ids: Iterable<string>): Map<string, Element | null> {
    const requested = new Set(ids);
    const targets = new Map<string, Element | null>();
    if (!requested.size) return targets;
    for (const node of root.querySelectorAll('[data-math-id]')) {
        const id = node.getAttribute('data-math-id')!;
        if (requested.has(id)) targets.set(id, targets.has(id) ? null : node);
    }
    for (const id of requested) if (!targets.has(id)) targets.set(id, null);
    return targets;
}
