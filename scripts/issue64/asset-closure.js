// Import every emitted SVG glyph module through the real bundle scheme handler.
// This checks executable resource closure, not visual correctness of every glyph.
const input = JSON.parse(source);
if (!input.modules.length) throw new Error('No dynamic mathematical modules enumerated');
for (const file of input.modules) {
    await import(new URL(file, document.baseURI).href);
}
await window.renderMarkdown('$\\mathbb{abcdefghijklmnopqrstuvwxyz}$', {context:'app'});
await window.waitForExportReady();
const root = document.getElementById('markdown-preview');
if (root.querySelector('.math-error') || !root.querySelector('mjx-container svg path')) {
    throw new Error('Mathematical rendering failed after complete glyph module import');
}
return {loadedModules:input.modules.length, renderedAfterImports:true};
