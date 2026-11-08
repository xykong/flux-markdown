jest.mock('mermaid', () => ({ initialize: jest.fn(), render: jest.fn() }));
import '../src/index';

const heading = 'FluxMarkdown Quick Look Test';
const bold = 'Rendered Markdown';
const fixture = `# ${heading}\n\n**${bold}** confirms the extension was selected.`;
const verify = () => Reflect.get(window, 'verifyQuickLookProbe')?.(heading, bold) === true;

beforeEach(() => {
    document.body.innerHTML = '<div id="markdown-preview"></div>';
    jest.spyOn(HTMLElement.prototype, 'getBoundingClientRect').mockReturnValue({width: 600, height: 400} as DOMRect);
});
afterEach(() => jest.restoreAllMocks());

test('accepts the completed visible fixture', async () => {
    await window.renderMarkdown(fixture);
    expect(verify()).toBe(true);
});
test('rejects missing root even though render resolves', async () => {
    document.body.innerHTML = '';
    await window.renderMarkdown(fixture);
    expect(verify()).toBe(false);
});
test('rejects caught renderer failure and previously successful content', async () => {
    await window.renderMarkdown(fixture);
    const failure = jest.spyOn(crypto, 'getRandomValues').mockImplementation(() => { throw new Error('injected'); });
    await window.renderMarkdown(fixture);
    failure.mockRestore();
    expect(document.querySelector('.render-error')).not.toBeNull();
    expect(verify()).toBe(false);
});
test('rejects invalidated or source-mode generations', async () => {
    await window.renderMarkdown(fixture);
    window.invalidateRender();
    expect(verify()).toBe(false);
    await window.renderMarkdown(fixture);
    window.renderSource(fixture, 'light');
    expect(verify()).toBe(false);
});
test('rejects wrong content, hidden and zero-size roots', async () => {
    await window.renderMarkdown('# Wrong\n\n**Other**');
    expect(verify()).toBe(false);
    await window.renderMarkdown(fixture);
    const root = document.getElementById('markdown-preview')!;
    root.style.display = 'none';
    expect(verify()).toBe(false);
    root.style.display = '';
    jest.spyOn(root, 'getBoundingClientRect').mockReturnValue({width:0,height:0} as DOMRect);
    expect(verify()).toBe(false);
});

test('does not accept stale success while a newer render is pending', async () => {
    await window.renderMarkdown(fixture);
    const pending = window.renderMarkdown('$x$');
    expect(verify()).toBe(false);
    window.invalidateRender();
    await pending;
    expect(verify()).toBe(false);
});
