jest.mock('mermaid', () => ({ initialize: jest.fn(), render: jest.fn() }));
import '../src/index';

beforeEach(() => { document.body.innerHTML = '<div id="markdown-preview"></div>'; });

async function render(source: string): Promise<string> {
    await window.renderMarkdown(source);
    return document.getElementById('markdown-preview')!.textContent!;
}

test.each([
    '(a) (b) (c) (d)',
    '(A) (B) (C) (D)',
    '(a) first\n(b) second\n(c) third',
    '(a) first\n\n(b) second\n\n(c) third',
    '- (a) first\n- (b) second\n- (c) third',
    '(a) first **(b)** second *(c)* third',
    '(b) second [(c)](https://example.com)',
])('preserves letter sequences: %s', async source => {
    const text = await render(source);
    expect(text).toMatch(/\([cC]\)/);
    expect(text).not.toContain('©');
});

test('preserves other typography and a separate copyright after a sequence', async () => {
    expect(await render('(a) (b) (c)\n\n(c) 2026 (tm) (r) ... "quote" © &copy;'))
        .toContain('(a) (b) (c)\n© 2026 ™ ® … “quote” © ©');
});

test.each([
    '(c) 2026', '(b) (d) (c)', '(B) (c)', '`(b)` (c)',
    '<span title="(b)">text</span> (c)',
    '[link](https://example.com/\(b\)) (c)',
    '<https://example.com/(b)> (c)',
    '(b)\n\n# New section\n\n(c)',
    '(b)\n\n```text\nexample\n```\n\n(c)',
])('keeps independent copyright replacement: %s', async source => {
    expect(await render(source)).toContain('©');
});

test('does not leak sequence state between renders', async () => {
    await render('(a) (b)');
    expect(await render('(c)')).toBe('©\n');
});

test('preserves source, explicit escaping, code, link targets and HTML export', async () => {
    const source = '(a) (b) [(c)](https://example.com/target) ` (c) ` \\(c)';
    await render(source);
    expect(document.querySelector('a')?.getAttribute('href')).toBe('https://example.com/target');
    expect(document.querySelector('code')?.textContent).toBe('(c)');
    const exported = new DOMParser().parseFromString(window.exportHTML(), 'text/html');
    expect(exported.querySelector('a')?.textContent).toBe('(c)');
    window.renderSource(source, 'light');
    expect(document.getElementById('markdown-preview')?.textContent).toContain(source);
});
