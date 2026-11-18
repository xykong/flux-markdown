import MarkdownIt from 'markdown-it';
import emoji from 'markdown-it-emoji';
import definitions from 'markdown-it-emoji/lib/data/full.json';
import shortcuts from 'markdown-it-emoji/lib/data/shortcuts';

const shortcutDefinitions: Record<string, string> = {};
for (const name of Object.keys(shortcuts)) shortcutDefinitions[name] = definitions[name];

/** Install the upstream replacement rule with the names that can occur in this window. */
export function largePreviewEmoji(parser: MarkdownIt): void {
    // Register the upstream renderer and position in the core rule chain.
    parser.use(emoji, {defs: {}, shortcuts: {}});
    parser.core.ruler.at('emoji', state => {
        const present = {...shortcutDefinitions};
        const candidates = state.tokens.filter(token => {
            if (token.type !== 'inline' || !token.children) return false;
            let found = false;
            for (const child of token.children) {
                // All bundled shortcuts contain a colon, a semicolon, '<', or '-)'.
                // Inspect decoded text so entities and escapes retain their meaning.
                if (child.type !== 'text' || !/[:;<]|-\)/.test(child.content)) continue;
                found = true;
                const parts = child.content.split(':');
                for (let i = 1; i < parts.length - 1; i++) {
                    const name = parts[i];
                    if (Object.prototype.hasOwnProperty.call(definitions, name)) present[name] = definitions[name];
                }
            }
            return found;
        });
        if (!candidates.length) return;

        const matcher = new MarkdownIt().use(emoji, {defs: present});
        matcher.core.ruler.enableOnly(['emoji']);
        const [replace] = matcher.core.ruler.getRules('');
        const original = state.tokens;
        state.tokens = candidates;
        try {
            replace(state);
        } finally {
            state.tokens = original;
        }
    });
}
