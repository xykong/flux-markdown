jest.mock('mermaid', () => ({ initialize: jest.fn(), render: jest.fn() }));
import '../src/index';

test('an immediate export waits for new mathematics instead of exporting previous content', async () => {
    document.body.innerHTML = '<div id="markdown-preview">Previous document</div>';
    const render = window.renderMarkdown(String.raw`\[x^2\tag{A}\label{a}\]`);
    await window.waitForExportReady();
    expect(document.querySelector('mjx-container')).not.toBeNull();
    expect(document.getElementById('markdown-preview')?.textContent).not.toContain('Previous document');
    await render;
});

test('export rejects a generation that was replaced during resource readiness', async () => {
    document.body.innerHTML = '<div id="markdown-preview"></div>';
    await window.renderMarkdown('$x=1$');
    const image = document.createElement('img');
    Object.defineProperty(image, 'complete', { value: false });
    document.getElementById('markdown-preview')!.append(image);
    const ready = window.waitForExportReady(1000);
    const rejection = expect(ready).rejects.toThrow(/changed/i);
    await window.renderMarkdown('$y=2$');
    image.dispatchEvent(new Event('load'));
    await rejection;
});
