/**
 * Splits Markdown source into segments that markdown-it can parse one at a time
 * with the same result as parsing the whole text, so a large window can be parsed
 * and sanitized in short tasks.
 *
 * A segment starts at a line that begins a new top-level block whatever came
 * before it: the line follows a blank line, is outside any fenced code block, and
 * starts at column 0 with an ATX heading marker or a letter (so it cannot continue
 * a list, block quote or indented code block, or be a list item or definition).
 *
 * Text that later definitions or open HTML blocks can affect across segments is
 * returned whole: link reference definitions, footnotes, abbreviations and any
 * line that may start an HTML block.
 */
export interface SourceSegment { text: string; line: number }

const notSplittable = [
    /^ {0,3}\[[^\]\n]+\]:/m,   // link reference definition
    /\[\^/,                    // footnote reference or definition
    /^\*\[[^\]\n]*\]:/m,       // abbreviation definition
    /^ {0,3}<[!?A-Za-z/]/m,    // possible HTML block
];
const blockStart = /^(?:#{1,6}(?:[ \t]|$)|\p{L})/u;
const fence = /^ {0,3}(`{3,}|~{3,})(.*)$/;

export function sourceSegments(text: string, size: number): SourceSegment[] {
    if (text.length <= size || notSplittable.some(pattern => pattern.test(text))) return [{ text, line: 0 }];
    const segments: SourceSegment[] = [];
    let open: { marker: string; length: number } | undefined;
    let previousBlank = true;
    let start = 0, startLine = 0, offset = 0, line = 0;
    while (offset < text.length) {
        const end = text.indexOf('\n', offset);
        const next = end < 0 ? text.length : end + 1;
        const content = text.slice(offset, end < 0 ? text.length : end).replace(/\r$/, '');
        if (!open && previousBlank && offset - start >= size && blockStart.test(content)) {
            segments.push({ text: text.slice(start, offset), line: startLine });
            start = offset; startLine = line;
        }
        const match = fence.exec(content);
        if (match) {
            const marker = match[1][0], length = match[1].length;
            if (!open) open = { marker, length };
            else if (marker === open.marker && length >= open.length && !match[2].trim()) open = undefined;
        }
        previousBlank = content.trim() === '';
        offset = next; line++;
    }
    segments.push({ text: text.slice(start), line: startLine });
    return segments;
}
