import { sourceSegments } from '../src/segments';

const join = (segments: { text: string }[]) => segments.map(segment => segment.text).join('');

test('segments cover the text exactly and record their first line', () => {
    const text = Array.from({ length: 50 }, (_, i) => `## Turn ${i}\n\nline ${i}\n\n`).join('');
    const segments = sourceSegments(text, 100);
    expect(segments.length).toBeGreaterThan(5);
    expect(join(segments)).toBe(text);
    for (const segment of segments) {
        expect(segment.line).toBe(text.slice(0, text.indexOf(segment.text)).split('\n').length - 1);
        expect(segment.text).toMatch(/^(## Turn|line)/);
    }
});

test('never splits inside a fence, a list or an indented block', () => {
    const fenced = '# A\n\n```text\n' + 'x\n\nWord inside code\n\n'.repeat(20) + '```\n\n# B\n\nend\n';
    const fencedSegments = sourceSegments(fenced, 10);
    expect(join(fencedSegments)).toBe(fenced);
    expect(fencedSegments.map(segment => segment.text.split('\n')[0])).toEqual(['# A', '# B']);
    const list = '- one\n\n- two\n\n  continued\n\n3. three\n\n    code\n\nParagraph\n';
    expect(sourceSegments(list, 5).map(segment => segment.text.split('\n')[0])).toEqual(['- one', 'Paragraph']);
});

test('text whose meaning can cross segments stays whole', () => {
    for (const text of ['# A\n\n[x][r]\n\n# B\n\n[r]: https://e.com\n', 'A[^1]\n\n# B\n\n[^1]: n\n', '*[HTML]: H\n\n# B\n\nHTML\n', '<div>\n\n# B\n\n</div>\n']) {
        expect(sourceSegments(text.repeat(5), 10)).toHaveLength(1);
    }
});
