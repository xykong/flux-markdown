import type { MathSource } from './math-syntax';

export const MATH_LIMITS = Object.freeze({ expressionBytes: 64 * 1024, documentBytes: 2 * 1024 * 1024, items: 5000 });

// Count Unicode scalar values directly: no large temporary encoded buffer and
// consistent behavior in the browser and test environments.
function utf8Bytes(text: string): number {
    let bytes = 0;
    for (const char of text) {
        const code = char.codePointAt(0)!;
        bytes += code <= 0x7f ? 1 : code <= 0x7ff ? 2 : code <= 0xffff ? 3 : 4;
        if (bytes > MATH_LIMITS.expressionBytes) break;
    }
    return bytes;
}

export function partitionMathSources(sources: readonly MathSource[]): { accepted: MathSource[]; rejected: MathSource[] } {
    const accepted: MathSource[] = [], rejected: MathSource[] = [];
    let total = 0;
    let exhausted = false;
    for (const source of sources) {
        const bytes = utf8Bytes(source.payload);
        if (bytes > MATH_LIMITS.expressionBytes) { rejected.push(source); continue; }
        if (accepted.length >= MATH_LIMITS.items || total + bytes > MATH_LIMITS.documentBytes) exhausted = true;
        if (exhausted) { rejected.push(source); continue; }
        total += bytes;
        accepted.push(source);
    }
    return { accepted, rejected };
}
