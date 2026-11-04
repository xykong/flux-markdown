import MarkdownIt from 'markdown-it';

export interface MathSource {
    id: string;
    raw: string;
    payload: string;
    display: boolean;
    firstLine: number;
    lastLine: number;
}
interface MathMeta { raw: string; payload: string; display: boolean; localLine?: number; source?: MathSource }

function escaped(source: string, position: number): boolean {
    let slashes = 0;
    while (position > 0 && source[--position] === '\\') slashes++;
    return slashes % 2 === 1;
}

/** Recognize math before Markdown escapes, leaving TeX interpretation to the engine. */
export function installMathSyntax(md: MarkdownIt): MathSource[] {
    const sources: MathSource[] = [];
    md.inline.ruler.before('escape', 'flux_math_inline', (state, silent) => {
        const start = state.pos;
        const open = state.src.startsWith('\\(', start) ? '\\(' : state.src[start] === '$' ? '$' : '';
        if (!open || (open === '$' && (state.src[start + 1] === '$' || /\s/.test(state.src[start + 1] || ' ')))) return false;
        const close = open === '$' ? '$' : '\\)';
        let end = start + open.length;
        while ((end = state.src.indexOf(close, end)) >= 0) {
            if (!escaped(state.src, end) && (open !== '$' || (!/\s/.test(state.src[end - 1]) && !/\d/.test(state.src[end + 1] || '')))) break;
            end += close.length;
        }
        if (end < 0) return false;
        const payload = state.src.slice(start + open.length, end);
        if (!payload || /\n\s*\n/.test(payload)) return false;
        if (!silent) {
            const token = state.push('flux_math_inline', 'math', 0);
            token.meta = { raw: state.src.slice(start, end + close.length), payload, display: false,
                localLine: state.src.slice(0, start).split('\n').length - 1 } satisfies MathMeta;
        }
        state.pos = end + close.length;
        return true;
    });

    md.block.ruler.before('fence', 'flux_math_block', (state, start, end, silent) => {
        if (state.sCount[start] - state.blkIndent >= 4) return false;
        const line = state.src.slice(state.bMarks[start] + state.tShift[start], state.eMarks[start]).trim();
        const open = line.startsWith('$$') ? '$$' : line.startsWith('\\[') ? '\\[' : '';
        if (!open) return false;
        const close = open === '$$' ? '$$' : '\\]';
        let last = start;
        let payload: string;
        if (line.length > open.length && line.endsWith(close)) {
            payload = line.slice(open.length, -close.length);
        } else {
            if (line !== open) return false;
            for (last = start + 1; last < end; last++) {
                if (state.sCount[last] < state.blkIndent && state.src.slice(state.bMarks[last], state.eMarks[last]).trim()) return false;
                if (state.src.slice(state.bMarks[last] + state.tShift[last], state.eMarks[last]).trim() === close) break;
            }
            if (last === end) return false;
            payload = state.getLines(start + 1, last, state.blkIndent, false);
        }
        if (silent) return true;
        const token = state.push('flux_math_block', 'math', 0);
        token.block = true;
        token.map = [start, last + 1];
        token.meta = { payload, raw: state.getLines(start, last + 1, state.blkIndent, false), display: true } satisfies MathMeta;
        state.line = last + 1;
        return true;
    }, { alt: ['paragraph', 'reference', 'blockquote', 'list'] });

    md.core.ruler.after('inline', 'flux_math_sources', state => {
        sources.length = 0;
        for (const token of state.tokens) {
            if (token.type === 'fence' && token.info.trim().split(/\s+/)[0] === 'math') {
                token.type = 'flux_math_block';
                const range = token.map!;
                token.meta = { payload: token.content, raw: state.src.split('\n').slice(range[0], range[1]).join('\n'), display: true } satisfies MathMeta;
            }
            for (const child of token.type === 'inline' ? token.children || [] : [token]) {
                if (!child.type.startsWith('flux_math_')) continue;
                const meta = child.meta as MathMeta;
                const firstLine = (token.map?.[0] || 0) + (meta.localLine || 0) + 1;
                const source: MathSource = { id: `math-${sources.length}`, raw: meta.raw, payload: meta.payload,
                    display: meta.display, firstLine, lastLine: firstLine + meta.raw.split('\n').length - 1 };
                meta.source = source;
                sources.push(source);
            }
        }
    });
    const render: NonNullable<typeof md.renderer.rules.text> = (tokens, index) => {
        const meta = tokens[index].meta as MathMeta;
        const tag = meta.display ? 'div' : 'span';
        return `<${tag} class="flux-math-source" data-math-id="${meta.source!.id}">${md.utils.escapeHtml(meta.raw)}</${tag}>`;
    };
    md.renderer.rules.flux_math_inline = render;
    md.renderer.rules.flux_math_block = render;
    return sources;
}
