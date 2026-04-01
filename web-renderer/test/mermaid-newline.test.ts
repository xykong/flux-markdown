import { preprocessMermaidNewlines } from '../src/index';

describe('preprocessMermaidNewlines', () => {
    describe('sequenceDiagram participant quote stripping', () => {
        test('strips quotes from participant alias', () => {
            const input = 'participant U as "用户（飞书）"';
            expect(preprocessMermaidNewlines(input)).toBe('participant U as 用户（飞书）');
        });

        test('strips quotes from actor alias', () => {
            const input = 'actor U as "用户（飞书）"';
            expect(preprocessMermaidNewlines(input)).toBe('actor U as 用户（飞书）');
        });

        test('strips quotes from multiple participants', () => {
            const input = [
                'sequenceDiagram',
                '    participant U as "用户（飞书）"',
                '    participant FWS as "飞书平台"',
                '    participant GW as "Gateway（Python）"',
            ].join('\n');
            const result = preprocessMermaidNewlines(input);
            expect(result).toContain('participant U as 用户（飞书）');
            expect(result).toContain('participant FWS as 飞书平台');
            expect(result).toContain('participant GW as Gateway（Python）');
        });

        test('strips quotes and also converts \\n in same label', () => {
            const input = 'participant PLG as "插件（TypeScript\\n运行在用户设备）"';
            expect(preprocessMermaidNewlines(input)).toBe('participant PLG as 插件（TypeScript<br/>运行在用户设备）');
        });
    });

    describe('double-quoted node labels', () => {
        test('replaces \\n inside double-quoted label', () => {
            const input = 'A["line1\\nline2"]';
            expect(preprocessMermaidNewlines(input)).toBe('A["line1<br/>line2"]');
        });

        test('replaces multiple \\n in a single quoted label', () => {
            const input = 'A["原始写法\\n6x get_json_object\\n173 秒"]';
            expect(preprocessMermaidNewlines(input)).toBe('A["原始写法<br/>6x get_json_object<br/>173 秒"]');
        });

        test('replaces \\n across several quoted nodes in one diagram', () => {
            const input = [
                'graph LR',
                '    A["原始写法\\n6x get_json_object\\n173 秒"] -->|"2x 提速"| B["优化写法\\n子对象 + json_tuple\\n52~82 秒"]',
                '    B -->|"未来进一步优化"| C["ETL 拍平\\n独立字段列\\n预计再提速 10x+"]',
            ].join('\n');
            const result = preprocessMermaidNewlines(input);
            expect(result).toContain('"原始写法<br/>6x get_json_object<br/>173 秒"');
            expect(result).toContain('"优化写法<br/>子对象 + json_tuple<br/>52~82 秒"');
            expect(result).toContain('"ETL 拍平<br/>独立字段列<br/>预计再提速 10x+"');
        });

        test('handles escaped quote inside label without corrupting surrounding text', () => {
            const input = 'A["say \\"hello\\"\\nworld"]';
            expect(preprocessMermaidNewlines(input)).toBe('A["say \\"hello\\"<br/>world"]');
        });

        test('handles \\n at the very start of a quoted label', () => {
            const input = 'A["\\nfoo"]';
            expect(preprocessMermaidNewlines(input)).toBe('A["<br/>foo"]');
        });

        test('handles \\n at the very end of a quoted label', () => {
            const input = 'A["foo\\n"]';
            expect(preprocessMermaidNewlines(input)).toBe('A["foo<br/>"]');
        });

        test('does not double-process already-converted <br/>', () => {
            const input = 'A["foo<br/>bar"]';
            expect(preprocessMermaidNewlines(input)).toBe('A["foo<br/>bar"]');
        });

        test('handles multiple quoted strings on the same line', () => {
            const input = 'A["foo\\nbar"] --> B["baz\\nqux"]';
            expect(preprocessMermaidNewlines(input)).toBe('A["foo<br/>bar"] --> B["baz<br/>qux"]');
        });

        test('handles label with no \\n as a no-op', () => {
            const input = 'A["just a label"]';
            expect(preprocessMermaidNewlines(input)).toBe('A["just a label"]');
        });
    });

    describe('unquoted square-bracket labels', () => {
        test('replaces \\n inside unquoted square-bracket label', () => {
            const input = 'A1[Sightengine\\n主检测]';
            expect(preprocessMermaidNewlines(input)).toBe('A1[Sightengine<br/>主检测]');
        });

        test('replaces multiple \\n in unquoted square-bracket label', () => {
            const input = 'A[line1\\nline2\\nline3]';
            expect(preprocessMermaidNewlines(input)).toBe('A[line1<br/>line2<br/>line3]');
        });

        test('does not touch square-bracket labels without \\n', () => {
            const input = 'A[just a label]';
            expect(preprocessMermaidNewlines(input)).toBe('A[just a label]');
        });

        test('does not affect double-quoted square-bracket labels (handled by quoted pass)', () => {
            const input = 'A["quoted\\nlabel"]';
            expect(preprocessMermaidNewlines(input)).toBe('A["quoted<br/>label"]');
        });

        test('handles flowchart with mixed quoted and unquoted labels', () => {
            const input = [
                'flowchart LR',
                '    A1[Sightengine\\n主检测] --> A3[结果输出]',
                '    A2[C2PA\\n辅助验证] --> A3',
            ].join('\n');
            const result = preprocessMermaidNewlines(input);
            expect(result).toContain('A1[Sightengine<br/>主检测]');
            expect(result).toContain('A2[C2PA<br/>辅助验证]');
            expect(result).toContain('A3[结果输出]');
        });
    });

    describe('unquoted round-bracket labels', () => {
        test('replaces \\n inside unquoted round-bracket label', () => {
            const input = 'A(line1\\nline2)';
            expect(preprocessMermaidNewlines(input)).toBe('A(line1<br/>line2)');
        });

        test('does not touch round-bracket labels without \\n', () => {
            const input = 'A(just a label)';
            expect(preprocessMermaidNewlines(input)).toBe('A(just a label)');
        });
    });

    describe('unquoted curly-bracket labels (diamond/hexagon nodes)', () => {
        test('replaces \\n inside unquoted curly-bracket label', () => {
            const input = 'G{热图阈值化\\n> 0.7 = 修改区域}';
            expect(preprocessMermaidNewlines(input)).toBe('G{热图阈值化<br/>> 0.7 = 修改区域}');
        });

        test('replaces multiple \\n in curly-bracket label', () => {
            const input = 'G{line1\\nline2\\nline3}';
            expect(preprocessMermaidNewlines(input)).toBe('G{line1<br/>line2<br/>line3}');
        });

        test('does not touch curly-bracket labels without \\n', () => {
            const input = 'G{decision}';
            expect(preprocessMermaidNewlines(input)).toBe('G{decision}');
        });
    });

    describe('does not touch content outside quotes', () => {
        test('leaves bare node labels untouched', () => {
            const input = 'A --> B';
            expect(preprocessMermaidNewlines(input)).toBe('A --> B');
        });

        test('leaves diagram keywords untouched', () => {
            const input = 'graph LR\n    A --> B';
            expect(preprocessMermaidNewlines(input)).toBe('graph LR\n    A --> B');
        });

        test('leaves edge labels without \\n untouched', () => {
            const input = 'A -->|"some label"| B';
            expect(preprocessMermaidNewlines(input)).toBe('A -->|"some label"| B');
        });
    });

    describe('edge cases', () => {
        test('returns empty string unchanged', () => {
            expect(preprocessMermaidNewlines('')).toBe('');
        });
    });
});
