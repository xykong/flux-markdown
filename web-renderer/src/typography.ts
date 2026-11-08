import type MarkdownIt from 'markdown-it';

/** Keep letter-sequence markers out of markdown-it's copyright replacement. */
export function preserveLetterSequences(md: MarkdownIt): void {
    md.core.ruler.before('replacements', 'letter-sequences', state => {
        let previousLetter = '';
        for (const block of state.tokens) {
            if (['heading_open', 'heading_close', 'fence', 'code_block', 'hr'].includes(block.type)) {
                previousLetter = '';
            }
            if (block.type !== 'inline' || !block.children) continue;
            let insideAutolink = false;
            block.children = block.children.flatMap(token => {
                if (token.type === 'link_open' && token.info === 'auto') insideAutolink = true;
                if (token.type === 'link_close') insideAutolink = false;
                if (token.type !== 'text' || insideAutolink) return [token];

                const parts = [];
                let start = 0;
                for (const match of token.content.matchAll(/\(([a-z])\)/gi)) {
                    const letter = match[1];
                    const protect = (letter === 'c' && previousLetter === 'b') ||
                        (letter === 'C' && previousLetter === 'B');
                    previousLetter = letter;
                    if (!protect) continue;

                    const index = match.index!;
                    if (index > start) {
                        parts.push(Object.assign(new state.Token('text', '', 0), token, {
                            content: token.content.slice(start, index)
                        }));
                    }
                    // markdown-it's text_join restores this to ordinary text after
                    // typography; no sentinels or generated-HTML rewriting needed.
                    parts.push(Object.assign(new state.Token('text_special', '', 0), {
                        content: match[0], level: token.level
                    }));
                    start = index + match[0].length;
                }
                if (!parts.length) return [token];
                if (start < token.content.length) {
                    parts.push(Object.assign(new state.Token('text', '', 0), token, {
                        content: token.content.slice(start)
                    }));
                }
                return parts;
            });
        }
    });
}
