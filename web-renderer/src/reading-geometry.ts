// Older WebKit divides client rects by CSS zoom even though pointer and
// scrolling APIs use viewport coordinates. Detect the behavior, not the OS.
let legacyElements: boolean | undefined;
let legacyRanges: boolean | undefined;

function measureClientRects(): void {
    const probe = document.createElement('span');
    probe.style.cssText = 'position:fixed;top:0;left:0;visibility:hidden;pointer-events:none;font:16px monospace';
    probe.textContent = 'MMMM';
    document.body.append(probe);
    const range = document.createRange();
    range.selectNodeContents(probe);
    const elementWidth = probe.getBoundingClientRect().width;
    const rangeWidth = range.getBoundingClientRect().width;
    probe.style.setProperty('zoom', '2');
    legacyElements = elementWidth > 0 && probe.getBoundingClientRect().width < elementWidth * 1.5;
    legacyRanges = rangeWidth > 0 && range.getBoundingClientRect().width < rangeWidth * 1.5;
    probe.remove();
}

export function readingRect(target: Element | Range): DOMRect {
    const rect = target.getBoundingClientRect();
    const isRange = target instanceof Range;
    const node = isRange ? target.commonAncestorContainer : target;
    const element = node instanceof Element ? node : node.parentElement;
    const root = element?.closest<HTMLElement>('#markdown-preview');
    const zoom = parseFloat(root?.style.getPropertyValue('zoom') || '') || 1;
    if (zoom === 1 || element?.closest('.diagram-tools')) return rect;
    if (legacyElements === undefined) measureClientRects();
    if (!(isRange ? legacyRanges : legacyElements)) return rect;
    // WebKit subtracts the document scroll offset after removing zoom from
    // the document-space rect. Undo that subtraction before scaling.
    return new DOMRect(
        (rect.x + window.scrollX) * zoom - window.scrollX,
        (rect.y + window.scrollY) * zoom - window.scrollY,
        rect.width * zoom,
        rect.height * zoom,
    );
}
