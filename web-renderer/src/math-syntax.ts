import MarkdownIt from 'markdown-it';

export interface MathSource {
    kind?: 'tex' | 'mathml';
    id: string;
    raw: string;
    payload: string;
    display: boolean;
    firstLine: number;
    lastLine: number;
}
interface MathMeta { raw: string; payload: string; display: boolean; localLine?: number; localOffset?: number; source?: MathSource }

function escaped(source: string, position: number): boolean {
    let slashes = 0;
    while (position > 0 && source[--position] === '\\') slashes++;
    return slashes % 2 === 1;
}

/** Recognize math before Markdown escapes, leaving TeX interpretation to the engine. */
export function installMathSyntax(md: MarkdownIt, namespace = 'math'): MathSource[] {
    const sources: MathSource[] = [];
    let originalLines: string[] = [];
    md.core.ruler.before('normalize', 'flux_math_original_lines', state => {
        originalLines = state.src.match(/[^\r\n]*(?:\r\n|\r|\n|$)/g) || [];
    });
    md.inline.ruler.before('escape', 'flux_math_inline', (state, silent) => {
        const start = state.pos;
        // Raw HTML code containers are separate html_inline tokens. Respect
        // their boundaries before accepting delimiters inside their text.
        const protectedTags: string[] = [];
        for (const token of state.tokens) {
            if (token.type !== 'html_inline') continue;
            const tag = /^<\s*(\/?)\s*(code|pre|script|style|textarea)\b[^>]*>/i.exec(token.content);
            if (!tag) continue;
            const name = tag[2].toLowerCase();
            if (tag[1]) { const index = protectedTags.lastIndexOf(name); if (index >= 0) protectedTags.splice(index); }
            else if (!/\/\s*>$/.test(tag[0])) protectedTags.push(name);
        }
        if (protectedTags.length) return false;
        const reference = /^\\(?:eqref|ref)\{[^{}\n]+\}/.exec(state.src.slice(start));
        if (reference) {
            if (!silent) {
                const token = state.push('flux_math_inline', 'math', 0);
                token.content = reference[0];
                token.meta = { raw: reference[0], payload: reference[0], display: false, localOffset: start,
                    localLine: state.src.slice(0, start).split('\n').length - 1 } satisfies MathMeta;
            }
            state.pos += reference[0].length;
            return true;
        }
        const open = state.src.startsWith('\\(', start) ? '\\(' : state.src[start] === '$' ? '$' : '';
        if (!open || (open === '$' && (state.src[start - 1] === '$' || state.src[start + 1] === '$' || /\s/.test(state.src[start + 1] || ' ')))) return false;
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
            token.content = payload;
            token.meta = { raw: state.src.slice(start, end + close.length), payload, display: false, localOffset: start,
                localLine: state.src.slice(0, start).split('\n').length - 1 } satisfies MathMeta;
        }
        state.pos = end + close.length;
        return true;
    });

    md.block.ruler.before('fence', 'flux_math_block', (state, start, end, silent) => {
        if (state.sCount[start] - state.blkIndent >= 4) return false;
        const line = state.src.slice(state.bMarks[start] + state.tShift[start], state.eMarks[start]).trim();
        const environment = /^\\begin\{((?:equation|align|gather)\*?)\}/.exec(line);
        const open = environment ? environment[0] : line.startsWith('$$') ? '$$' : line.startsWith('\\[') ? '\\[' : '';
        if (!open) return false;
        const close = environment ? `\\end{${environment[1]}}` : open === '$$' ? '$$' : '\\]';
        let last = start;
        let payload: string;
        if (line.length > open.length && line.endsWith(close)) {
            payload = line.slice(open.length, -close.length);
        } else {
            if (line !== open) return false;
            for (last = start + 1; last < end; last++) {
                if (state.sCount[last] < state.blkIndent && state.src.slice(state.bMarks[last], state.eMarks[last]).trim()) return false;
                const candidate = state.src.slice(state.bMarks[last] + state.tShift[last], state.eMarks[last]).trim();
                if (candidate === close) break;
                // A new explicit display opener cannot nest in this display
                // environment. Leave the unmatched source readable so the later
                // independent block can be parsed normally.
                if (open !== close && candidate.startsWith(open)) return false;
            }
            if (last === end) return false;
            payload = state.getLines(start + 1, last, state.blkIndent, false);
        }
        if (silent) return true;
        if (environment) payload = state.getLines(start, last + 1, state.blkIndent, false);
        const token = state.push('flux_math_block', 'math', 0);
        token.block = true;
        token.map = [start, last + 1];
        token.meta = { payload, raw: state.getLines(start, last + 1, state.blkIndent, false), display: true } satisfies MathMeta;
        state.line = last + 1;
        return true;
    }, { alt: ['paragraph', 'reference', 'blockquote', 'list'] });

    md.core.ruler.after('inline', 'flux_math_sources', state => {
        sources.length = 0;
        const ranges: Array<[number, number] | null> = [];
        let table: { original: string; normalized: string; offsets: number[]; cursor: number } | null = null;
        for (const token of state.tokens) {
            if (token.type === 'tr_open') {
                const original = originalLines[token.map?.[0] ?? -1] || '';
                table = {original, normalized:'', offsets:[], cursor:0};
                for (let index=0; index<original.length; index++) {
                    // Match the table parser's escape transformation and retain
                    // offsets into the original row, once per row rather than cell.
                    if (original[index] === '\\' && original[index+1] === '|') continue;
                    table.offsets.push(index);table.normalized += original[index];
                }
            }
            if (token.type === 'tr_close') table = null;
            if (token.nesting === -1) { ranges.pop(); continue; }
            if (token.nesting === 1) ranges.push(token.map || ranges[ranges.length - 1] || null);
            const sourceRange = token.map || ranges[ranges.length - 1];
            let tableStart = -1;
            if (token.type === 'inline' && !token.map && table) {
                tableStart = table.normalized.indexOf(token.content, table.cursor);
                if (tableStart >= 0) table.cursor = tableStart + token.content.length;
            }
            if (token.type === 'fence' && token.info.trim().split(/\s+/)[0] === 'math') {
                token.type = 'flux_math_block';
                const range = token.map!;
                token.meta = { payload: token.content, raw: state.src.split('\n').slice(range[0], range[1]).join('\n'), display: true } satisfies MathMeta;
            }
            for (const child of token.type === 'inline' ? token.children || [] : [token]) {
                if (!child.type.startsWith('flux_math_')) continue;
                const meta = child.meta as MathMeta;
                if (table && tableStart >= 0 && meta.localOffset !== undefined) {
                    const first = table.offsets[tableStart + meta.localOffset];
                    const last = table.offsets[tableStart + meta.localOffset + meta.raw.length - 1];
                    if (first !== undefined && last !== undefined) meta.raw = table.original.slice(first, last + 1);
                }
                if (meta.display && token.map) {
                    // Markdown-it normalizes CRLF before parsing. Recover the
                    // exact original block for copy/fallback from its source map.
                    meta.raw = originalLines.slice(token.map[0], token.map[1]).join('').replace(/(?:\r\n|\r|\n)$/, '');
                } else if (meta.raw.includes('\n') && token.map) {
                    const first = token.map[0] + (meta.localLine || 0);
                    const lines = meta.raw.split('\n');
                    meta.raw = lines.map((line, index) => line + (index === lines.length - 1 ? '' :
                        originalLines[first + index]?.match(/(\r\n|\r|\n)$/)?.[0] || '\n')).join('');
                }
                const firstLine = (sourceRange?.[0] || 0) + (meta.localLine || 0) + 1 + Number(state.env.sourceLineOffset || 0);
                const source: MathSource = { id: `${namespace}-${sources.length}`, raw: meta.raw, payload: meta.payload,
                    display: meta.display, firstLine, lastLine: firstLine + meta.raw.split(/\r\n|\r|\n/).length - 1 };
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
