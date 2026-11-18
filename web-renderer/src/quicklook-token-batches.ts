import type MarkdownIt from 'markdown-it';

type Token = ReturnType<MarkdownIt['parse']>[number];
interface TokenBatch { start: number; end: number }

function needsWholeFragment(token: Token): boolean {
    // A raw element can open in one Markdown block and close in another.
    if (token.type === 'html_block' || token.type === 'html_inline') return true;
    if (token.type === 'fence' && /^(?:mermaid|typst(?:-math)?|vega(?:-lite)?|dot|graphviz)\b/i.test(token.info.trim())) return true;
    return token.children?.some(needsWholeFragment) ?? false;
}

/** Group already-resolved tokens in display order, keeping whole top-level blocks together. */
export function quickLookTokenBatches(tokens: Token[], fromEnd: boolean): TokenBatch[] {
    const batches: TokenBatch[] = [];
    const step = fromEnd ? -1 : 1;
    let boundary = fromEnd ? tokens.length : 0;
    let depth = 0;
    let chars = 0;
    for (let index = fromEnd ? tokens.length - 1 : 0; index >= 0 && index < tokens.length; index += step) {
        const token = tokens[index];
        if (needsWholeFragment(token)) return [];
        depth += token.nesting * step;
        if (depth < 0) return [];
        chars += token.content.length;
        if (depth !== 0) continue;
        const start = fromEnd ? index : boundary;
        const end = fromEnd ? boundary : index + 1;
        const first = batches.length === 0;
        const lastBlock = fromEnd ? index === 0 : index === tokens.length - 1;
        if (!lastBlock && chars < (first ? 16_000 : 128_000) && end - start < (first ? 256 : 8192)) continue;
        batches.push({ start, end });
        boundary = fromEnd ? start : end;
        chars = 0;
    }
    return depth === 0 && batches.length > 1 ? batches : [];
}
