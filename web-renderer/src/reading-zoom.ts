/** Zoom the reading column without scaling application chrome. */
export interface ZoomPoint { x: number; y: number; gesture?: number; finished?: boolean }
interface ReadingAnchor {
    root: HTMLElement;
    target: Range | Element;
    fraction: number;
    viewportY: number;
    gesture?: number;
}
let gestureAnchor: ReadingAnchor | undefined;

function captureAnchor(root: HTMLElement, point?: ZoomPoint): ReadingAnchor {

    const bounds = root.getBoundingClientRect();
    const x = point?.x ?? Math.max(0, bounds.left) + Math.min(bounds.width, innerWidth - Math.max(0, bounds.left)) / 2;
    const y = point?.y ?? innerHeight / 2;
    // Ignore chrome hit targets: fall back to a visible point inside the reading column.
    const hitX = Math.max(bounds.left + 2, Math.min(bounds.right - 2, x));
    const hitY = Math.max(2, Math.min(innerHeight - 2, y));
    const hit = document.elementFromPoint(hitX, hitY);
    const caret = (document as Document & { caretRangeFromPoint?: (x: number, y: number) => Range | null })
        .caretRangeFromPoint?.(hitX, hitY);
    let anchor: Range | undefined;
    if (caret && root.contains(caret.startContainer) && caret.startContainer.nodeType === Node.TEXT_NODE) {
        anchor = caret.cloneRange();
        const length = caret.startContainer.textContent?.length ?? 0;
        if (length > 0) {
            const offset = Math.min(caret.startOffset, length - 1);
            anchor.setStart(caret.startContainer, offset);
            anchor.setEnd(caret.startContainer, offset + 1);
        }
    }
    const element = hit && root.contains(hit) ? hit : root;
    const before = (anchor ?? element).getBoundingClientRect();
    const fraction = anchor ? 0 : Math.max(0, Math.min(1, (hitY - before.top) / Math.max(1, before.height)));
    return { root, target: anchor ?? element, fraction,
        viewportY: before.top + before.height * fraction, gesture: point?.gesture };
}

export function setReadingZoom(level: number, point?: ZoomPoint): void {
    if (!Number.isFinite(level)) return;
    pending = undefined;
    const root = document.getElementById('markdown-preview');
    if (!root) return;
    const zoom = Math.max(0.5, Math.min(3, level));
    const targetConnected = gestureAnchor?.target instanceof Range
        ? gestureAnchor.target.startContainer.isConnected : gestureAnchor?.target.isConnected;
    const anchor = point?.gesture !== undefined && gestureAnchor?.gesture === point.gesture
        && gestureAnchor.root === root && targetConnected ? gestureAnchor : captureAnchor(root, point);
    gestureAnchor = point?.gesture !== undefined && !point.finished ? anchor : undefined;
    root.style.transform = '';
    root.style.transformOrigin = '';
    root.style.setProperty('zoom', String(zoom));
    // Grid's automatic inline size is calculated in the zoomed element's own units.
    // Avoid a percentage width (100% would overflow by the zoom factor in WebKit).
    root.style.setProperty('width', 'auto');
    if (zoom === 1) document.documentElement.style.removeProperty('--zoom-scale');
    else document.documentElement.style.setProperty('--zoom-scale', String(zoom));
    const after = anchor.target.getBoundingClientRect();
    window.scrollBy({top: after.top + after.height * anchor.fraction - anchor.viewportY, left: 0, behavior: 'instant' as ScrollBehavior});
}

let pending: { level: number; point?: ZoomPoint } | undefined;
let scheduled = false;
/** Coalesce native gesture samples to one layout/anchor correction per frame. */
export function requestReadingZoom(level: number, point?: ZoomPoint): void {
    if (!Number.isFinite(level)) return;
    pending = { level, point };
    if (scheduled) return;
    scheduled = true;
    requestAnimationFrame(() => {
        scheduled = false;
        const next = pending;
        pending = undefined;
        if (next) setReadingZoom(next.level, next.point);
    });
}
