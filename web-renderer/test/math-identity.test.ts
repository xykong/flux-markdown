import { mathjax } from '@mathjax/src/js/mathjax.js';
import { liteAdaptor } from '@mathjax/src/js/adaptors/liteAdaptor.js';
import { RegisterHTMLHandler } from '@mathjax/src/js/handlers/html.js';
import { SerializedMmlVisitor } from '@mathjax/src/js/core/MmlTree/SerializedMmlVisitor.js';
import { createMathInput } from '../src/math-identity';
import { readFileSync } from 'fs';
import { resolve } from 'path';

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

    test('matches the independently compiled TeX reference numbering', () => {
        const expected = JSON.parse(readFileSync(resolve(__dirname, '../../docs/research/issue64/oracle/manifest.json'), 'utf8')).labelsExpected;
        const result = compile(String.raw`
        \[a^2+b^2=c^2\tag{1}\label{eq:pythagoras}\]
        Forward \eqref{oracle:forward}.
        \begin{equation}x=y\tag{A}\label{oracle:forward}\end{equation}
        \begin{equation}a=b\label{oracle:auto}\end{equation}
        \begin{equation*}c=d\end{equation*}
        \begin{align}x&=1\label{oracle:row}\\y&=2\notag\end{align}
        \[z=3\tag*{B}\label{oracle:tagstar}\]
        \(\ref{oracle:tagstar},\eqref{oracle:tagstar}\)`);
        expect(Object.fromEntries(Object.entries(result.labels).map(([key,value])=>[key,value.tag]))).toEqual(expected);
        expect(result.output).not.toContain('merror');
        expect(result.output).toContain('(A)');
        expect(result.output).toContain('(B)');
    });

    test.each(['a b','a_b','constructor','__proto__','公式:α','𝛼:一'])('consistent label rename preserves tag and distinct identity: %s', label => {
        const result=compile(`\\(\\eqref{${label}}\\)\\[x=1\\tag{A}\\label{${label}}\\]`);
        expect(result.labels[label].tag).toBe('A');
        expect(result.labels[label].id).toMatch(/^test-l-[0-9a-f]+$/);
        expect(result.output).toContain('(A)');
        expect(result.output).not.toContain('merror');
    });

    test('moving an explicitly tagged equation across its reference preserves the resolved value', () => {
        const equation=String.raw`\[x=1\tag{A}\label{x}\]`;
        const ref=String.raw`\(\eqref{x}\)`;
        for (const input of [ref+equation,equation+ref,'Unrelated paragraph.\n\n'+ref+equation]) {
            const result=compile(input);
            expect(result.labels.x.tag).toBe('A');
            expect(result.output).toContain('(A)');
            expect(result.output).not.toContain('???');
        }
    });
});
