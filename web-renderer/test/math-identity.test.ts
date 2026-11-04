import { mathjax } from '@mathjax/src/js/mathjax.js';
import { liteAdaptor } from '@mathjax/src/js/adaptors/liteAdaptor.js';
import { RegisterHTMLHandler } from '@mathjax/src/js/handlers/html.js';
import { SerializedMmlVisitor } from '@mathjax/src/js/core/MmlTree/SerializedMmlVisitor.js';
import { createMathInput } from '../src/math-identity';

RegisterHTMLHandler(liteAdaptor());
function compile(source: string, namespace = 'test') {
    const tex = createMathInput(namespace);
    const doc = mathjax.document(source, { InputJax: tex });
    doc.findMath().compile();
    const visitor = new SerializedMmlVisitor();
    return { labels: tex.parseOptions.tags.allLabels,
        output: Array.from(doc.math).map(item => visitor.visitTree(item.root)).join('\n') };
}

describe('document-scoped equation identity', () => {
    test('space/underscore labels remain distinct and forward references resolve', () => {
        const result = compile(String.raw`\(\eqref{a b}\)\[x=1\tag{A}\label{a b}\]\[x=2\tag{B}\label{a_b}\]`);
        expect(result.labels['a b'].id).not.toBe(result.labels.a_b.id);
        expect(result.output).toContain('(A)');
        expect(result.output).not.toContain('merror');
    });
    test.each(['constructor','__proto__','toString','公式:α'])('accepts exact label %s', key => {
        const result = compile(`\\[x=1\\tag{A}\\label{${key}}\\]\\(\\eqref{${key}}\\)`);
        expect(result.labels[key].tag).toBe('A');
        expect(result.output).not.toContain('merror');
    });
    test('separates unnamed explicit tags from numbered labels', () => {
        const result = compile(String.raw`\[x=1\tag{1}\]\[x=2\tag{B}\label{1}\]`);
        const ids = [...result.output.matchAll(/id="([^"]+)"/g)].map(match => match[1]);
        expect(new Set(ids).size).toBe(2);
    });
    test('preserves upstream duplicate diagnostics', () => {
        expect(compile(String.raw`\[x=1\tag{A}\label{x}\]\[x=2\tag{B}\label{x}\]`).output).toContain('multiply defined');
    });
    test('does not share macros or labels across documents', () => {
        compile(String.raw`\(\newcommand{\shared}{42}\shared\)\[x=1\tag{A}\label{x}\]`);
        const next = compile(String.raw`\(\shared\)`, 'next');
        expect(next.output).toContain('Undefined control sequence');
        expect(Object.keys(next.labels)).toHaveLength(0);
    });
});
