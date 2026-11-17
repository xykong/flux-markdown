import { diagramZoomAt } from './diagram-zoom-controls';
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
    root.style.setProperty('--diagram-controls-zoom', String(1 / zoom));
    // Grid's automatic inline size is calculated in the zoomed element's own units.
    // Avoid a percentage width (100% would overflow by the zoom factor in WebKit).
    root.style.setProperty('width', 'auto');
    if (zoom === 1) document.documentElement.style.removeProperty('--zoom-scale');
    else document.documentElement.style.setProperty('--zoom-scale', String(zoom));
    const after = anchor.target.getBoundingClientRect();
    window.scrollBy({top: after.top + after.height * anchor.fraction - anchor.viewportY, left: 0, behavior: 'instant' as ScrollBehavior});
}

let pending: (() => void) | undefined;
let scheduled = false;
function queueZoom(action: () => void): void {
    pending = action;
    if (scheduled) return;
    scheduled = true;
    requestAnimationFrame(() => {
        scheduled = false;
        const next = pending;
        pending = undefined;
        next?.();
    });
}
/** Coalesce native gesture samples to one layout/anchor correction per frame. */
export function requestReadingZoom(level: number, point?: ZoomPoint): void {
    if (Number.isFinite(level)) queueZoom(() => setReadingZoom(level, point));
}

type DiagramTarget = NonNullable<ReturnType<typeof diagramZoomAt>>;
interface PinchSession {
    id: number;
    diagram?: DiagramTarget;
    factor: number;
    x: number;
    y: number;
    fractionX: number;
    fractionY: number;
}
let pinch: PinchSession | undefined;

function preparePinch(base: number, delta: number, point: ZoomPoint): { level: number | null; apply: () => void } {
    if (!pinch || pinch.id !== point.gesture || (pinch.diagram && !pinch.diagram.host.isConnected)) {
        const diagram = diagramZoomAt(point);
        const rect = diagram?.drawing.getBoundingClientRect();
        pinch = { id: point.gesture, diagram, factor: diagram?.controls.factor ?? 1,
            x: point.x, y: point.y,
            fractionX: rect ? (point.x - rect.left) / rect.width : 0,
            fractionY: rect ? (point.y - rect.top) / rect.height : 0 };
    }
    const session = pinch;
    if (point.finished) pinch = undefined;
    const ratio = Math.max(0.01, 1 + delta);
    const level = session.diagram ? null : Math.max(0.5, Math.min(3, base * ratio));
    return { level, apply: () => {
        if (level !== null) { setReadingZoom(level, point); return; }
        const { diagram } = session;
        if (!diagram?.host.isConnected) return;
        diagram.controls.setFactor(session.factor * ratio);
        const rect = diagram.drawing.getBoundingClientRect();
        const viewport = diagram.viewport;
        const scale = viewport.getBoundingClientRect().width / Math.max(1, viewport.offsetWidth);
        viewport.scrollLeft += (rect.left + rect.width * session.fractionX - session.x) / scale;
        window.scrollBy({ top: rect.top + rect.height * session.fractionY - session.y,
            left: 0, behavior: 'instant' as ScrollBehavior });
    } };
}

export function applyPinchZoom(base: number, delta: number, point: ZoomPoint): number | null {
    const next = preparePinch(base, delta, point);
    pending = undefined;
    next.apply();
    return next.level;
}

export function requestPinchZoom(base: number, delta: number, point: ZoomPoint): number | null {
    const next = preparePinch(base, delta, point);
    queueZoom(next.apply);
    return next.level;
}

/** Smart magnify uses the same default as the diagram's percentage button. */
export function resetZoomAt(point: ZoomPoint): number | null {
    pending = undefined;
    pinch = undefined;
    gestureAnchor = undefined;
    const diagram = diagramZoomAt(point);
    if (diagram) {
        preparePinch(1, 1 / diagram.controls.factor - 1,
            { ...point, gesture: -1, finished: true }).apply();
        return null;
    }
    setReadingZoom(1, point);
    return 1;
}
