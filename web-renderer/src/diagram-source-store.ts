/** The fenced source of a rendered diagram, kept out of the rendered HTML. */
const sourceByElement = new WeakMap<Element, { language: string; source: string }>();
export function rememberDiagramSource(element: Element, language: string, source: string): void {
    sourceByElement.set(element, { language, source });
}
export function originalDiagramSource(element: Element): { language: string; source: string } | undefined {
    return sourceByElement.get(element);
}
