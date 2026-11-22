import MarkdownIt from 'markdown-it';
import emoji from 'markdown-it-emoji';
import { largePreviewEmoji } from '../src/emoji';

test('all configured shortcuts, named emoji, entity decoding, code and autolinks agree with upstream', () => {
    const definitions: Record<string, string> = require('markdown-it-emoji/lib/data/full.json');
    const shortcuts: Record<string, string[]> = require('markdown-it-emoji/lib/data/shortcuts');
    const before = new MarkdownIt({linkify: true}).use(emoji);
    const after = new MarkdownIt({linkify: true}).use(largePreviewEmoji);
    for (const text of [Object.keys(definitions).map(name => ':' + name + ':').join(' '), ...Object.values(shortcuts).flat(), ':smile:', '&#58;smile&#58;', ':unknown:smile:',
        '字 :smile: 字', 'https://example.com/:smile:', '`:smile:`', 'before:smile: after']) {
        expect(after.render(text)).toBe(before.render(text));
    }
});
