import MarkdownIt from 'markdown-it';
import { installMathSyntax } from '../src/math-syntax';
const footnote: MarkdownIt.PluginSimple = require('markdown-it-footnote');

function parse(source: string) {
    const md = new MarkdownIt({ html: true });
    const math = installMathSyntax(md);
    md.render(source);
    return math;
}

describe('math syntax without an output engine', () => {
    test.each([
        ['$x$', 'x', false], [String.raw`\(x\)`, 'x', false],
        ['$$\nx\n$$', 'x', true], ['\\[\nx\n\\]', 'x', true],
        ['```math\nx\n```', 'x', true], ['~~~math\nx\n~~~', 'x', true],
        ['> \\[\n> x\n> \\]', 'x', true],
        ['- Formula\n\n  ```math\n  x\n  ```', 'x', true],
    ])('recognizes %s', (source, payload, display) => {
        const math = parse(source);
        expect(math).toHaveLength(1);
        expect(math[0].payload.trim()).toBe(payload);
        expect(math[0].display).toBe(display);
    });
    test.each(['`$x$`', '```text\n$x$\n```', '    $x$', String.raw`\$5 and \$10`,
        '<span title="$x$">text</span>', '<!-- $x$ -->', String.raw`\(unclosed`])('protects %s', source => {
        expect(parse(source)).toHaveLength(0);
    });
    test('preserves raw delimiters and source order across block/inline parsing', () => {
        const math = parse('$a$\n\n$$\nb\n$$\n\n'+String.raw`\(c\)`);
        expect(math.map(item => item.payload.trim())).toEqual(['a','b','c']);
        expect(math.map(item => item.firstLine)).toEqual([1,3,7]);
        expect(math[0].raw).toBe('$a$');
    });
    test('does not turn the tail of an unmatched double dollar into inline math', () => {
        expect(parse('$$not a closed block$')).toHaveLength(0);
    });
    test('keeps mathematics inside raw code elements literal', () => {
        expect(parse('<code>$x$ \\(y\\)</code>')).toHaveLength(0);
    });
    test('records an inline formula after a leading non-math code span', () => {
        const math=parse('`literal` then $x$');
        expect(math.map(item=>item.payload)).toEqual(['x']);
    });
    test('keeps source order when footnotes are moved to the end of the rendered document', () => {
        const md=new MarkdownIt().use(footnote);
        const sources=installMathSyntax(md);
        md.render('[^note]: $a$\n\nBody $b$.[^note]');
        expect(sources.map(source=>source.payload)).toEqual(['a','b']);
        expect(sources.map(source=>source.firstLine)).toEqual([1,3]);
    });
});
