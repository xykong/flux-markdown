interface SVGMetrics { width: number; textWidthInEm?: number }

function pixels(value: string | null): number | undefined {
    const match = value?.trim().match(/^([\d.]+)(px|pt|in|cm|mm)?$/i);
    if (!match) return undefined;
    const number = Number(match[1]) * ({px:1,pt:96/72,in:96,cm:96/2.54,mm:96/25.4}[match[2]?.toLowerCase() || 'px'] || 1);
    return Number.isFinite(number) && number > 0 ? number : undefined;
}

/** Read geometry only. The parsed document is never mounted or executed. */
function readSVG(source: string): SVGSVGElement | undefined {
    if (!/^data:image\/svg\+xml[;,]/i.test(source) || source.length > 12 * 1024 * 1024) return undefined;
    try {
        const comma = source.indexOf(',');
        const header = source.slice(0, comma);
        const payload = source.slice(comma + 1);
        const xml = /;base64$/i.test(header)
            ? new TextDecoder().decode(Uint8Array.from(atob(payload), c => c.charCodeAt(0)))
            : decodeURIComponent(payload);
        if (/<!DOCTYPE|<!ENTITY/i.test(xml)) return undefined;
        const doc = new DOMParser().parseFromString(xml, 'image/svg+xml');
        const svg = doc.documentElement;
        if (svg.localName !== 'svg' || doc.querySelector('parsererror')) return undefined;
        return svg as unknown as SVGSVGElement;
    } catch { return undefined; }
}

function metricsForSVG(svg: SVGSVGElement): SVGMetrics | undefined {
    const box = (svg.getAttribute('viewBox') || '').trim().split(/[\s,]+/).map(Number);
    const viewWidth = box.length === 4 && box.every(Number.isFinite) && box[2] > 0 && box[3] > 0 ? box[2] : undefined;
    const intrinsic = pixels(svg.getAttribute('width'));
    const declaredMax = pixels(svg.getAttribute('style')?.match(/(?:^|;)\s*max-width\s*:\s*([^;]+)/i)?.[1] || null);
    const widths = [viewWidth, intrinsic, declaredMax].filter((value): value is number => value !== undefined);
    const width = widths.length ? Math.min(...widths) : undefined;
    if (!width) return undefined;
    if (!svg.querySelector('text, tspan, foreignObject')) return { width };
    // A conservative cap from declared font sizes, including embedded CSS.
    // This is metadata, not computed CSS: no external styles/fonts are fetched.
    const declarations = Array.from(svg.querySelectorAll('style, [style], [font-size]'))
        .flatMap(node => [node.localName === 'style' ? node.textContent || '' : node.getAttribute('style') || '', `font-size:${node.getAttribute('font-size') || ''}`]).join(';');
    const values = Array.from(declarations.matchAll(/font-size\s*:\s*([\d.]+)\s*(px|pt|em|rem|%)?(?=\s*[;}!]|\s*$)/gi));
    let font = 16;
    for (const match of values) {
        if (!match[2] || /^(px|pt)$/i.test(match[2])) font = Math.max(font, pixels(match[1] + (match[2] || 'px')) || 16);
    }
    let relative = 1;
    for (const match of values) {
        if (/^(em|rem|%)$/i.test(match[2] || '')) relative = Math.max(relative, Number(match[1]) / (match[2] === '%' ? 100 : 1));
    }
    return { width, textWidthInEm: (viewWidth || width) / (font * relative) };
}

export function svgImageMetrics(source: string): SVGMetrics | undefined {
    const svg = readSVG(source);
    return svg ? metricsForSVG(svg) : undefined;
}

export function constrainSVGImage(img: HTMLImageElement, source: string): string {
    const svg = readSVG(source);
    const metrics = svg ? metricsForSVG(svg) : undefined;
    if (metrics && svg) {
        const limits = ['100%', `${metrics.width}px`];
        if (metrics.textWidthInEm) limits.push(`${metrics.textWidthInEm}em`);
        if (img.style.maxWidth && img.style.maxWidth !== 'none') limits.push(img.style.maxWidth);
        img.style.maxWidth = `min(${limits.join(', ')})`;
        const box = (svg.getAttribute('viewBox') || '').trim().split(/[\s,]+/).map(Number);
        if (box.length === 4 && box.every(Number.isFinite) && box[2] > 0 && box[3] > 0) {
            // WebKit can scale the viewport and the drawing independently for
            // percentage-sized SVG images. Normalize BOTH intrinsic dimensions
            // in the isolated image, not just the surrounding HTML image box.
            const width = metrics.width, height = width * box[3] / box[2];
            svg.setAttribute('width', String(width));
            svg.setAttribute('height', String(height));
            svg.style.setProperty('width', `${width}px`, 'important');
            svg.style.setProperty('height', `${height}px`, 'important');
            return 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(new XMLSerializer().serializeToString(svg));
        }
        return source;
    }
    // Non-inlined SVGs retain image isolation too. Use only the browser's
    // decoded intrinsic size rather than adding cross-origin/resource fetches.
    if (!/^data:image\/svg\+xml[;,]/i.test(source) && !/\.svg(?:[?#]|$)/i.test(source)) return source;
    const size = () => {
        if (img.naturalWidth > 0 && !img.style.maxWidth) img.style.maxWidth = `min(100%, ${img.naturalWidth}px)`;
    };
    img.addEventListener('load', size, { once:true });
    if (img.complete) size();
    return source;
}
