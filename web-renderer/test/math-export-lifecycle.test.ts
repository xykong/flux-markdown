jest.mock('mermaid', () => ({ initialize: jest.fn(), render: jest.fn() }));
import '../src/index';
import { prepareExport } from '../src/export-readiness';

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

test('export preparation reports a bounded mathematical blocker and recovers after correction', async () => {
    document.body.innerHTML='<div id="markdown-preview"></div>';
    await window.renderMarkdown('$\\unknownMarkdownPreviewCommand{x}$');
    expect(await window.prepareExport()).toEqual({status:'mathematics'});
    await window.renderMarkdown('$x=1$');
    expect(await window.prepareExport()).toEqual({status:'ready'});
});

test('unrelated failures remain failures instead of mathematical blockers', async () => {
    const failure = new Error('Export resources timed out');
    await expect(prepareExport(() => Promise.reject(failure))).rejects.toBe(failure);
});
