/** Source is kept out of rendered HTML and diagnostic payloads. */
const sourceByElement = new WeakMap<Element, string>();
export function rememberMathSource(element: Element, source: string): void {
    sourceByElement.set(element, source);
}
export function originalMathSource(element: Element): string | undefined {
    return sourceByElement.get(element);
}
