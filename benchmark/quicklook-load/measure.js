// The Swift probe passes the fixture as `source` after navigating a fresh WKWebView.
while (typeof window.renderMarkdown !== 'function') {
    await new Promise(resolve => setTimeout(resolve, 15));
}
const options = {
    context: 'quicklook', followFile: true, showCopyButtons: true,
    showLineNumbers: mode === 'lines', documentGeneration: 'bench'
};
if (mode === 'follow') {
    await window.renderMarkdown('initial', options);
    window.setQuickLookFollow(true);
    options.sourceLineStart = 60000;
}
const root = document.getElementById('markdown-preview');
let firstDOM = null, firstHasEnd = false, firstBlockCount = 0;
const started = performance.now();
let lastTurn = started, maxTurnGap = 0, turns = 0;
let lastTimer = started, maxTimerDelay = 0, timerTicks = 0;
let running = true;
const queue = new MessageChannel();
queue.port1.onmessage = () => {
    const now = performance.now();
    maxTurnGap = Math.max(maxTurnGap, now - lastTurn);
    lastTurn = now;
    turns++;
    if (running) queue.port2.postMessage(null);
};
queue.port2.postMessage(null);
const timer = setInterval(() => {
    const now = performance.now();
    maxTimerDelay = Math.max(maxTimerDelay, now - lastTimer - 16);
    lastTimer = now;
    timerTicks++;
}, 16);
const observer = new MutationObserver(() => {
    if (firstDOM === null && root.querySelector('[data-source-line]')) {
        firstDOM = performance.now() - started;
        firstBlockCount = root.childElementCount;
        firstHasEnd = root.lastElementChild?.textContent.includes('LAST-MARKER') ?? false;
        observer.disconnect();
    }
});
observer.observe(root, {childList: true});
await window.renderMarkdown(source, options);
const end = performance.now();
maxTurnGap = Math.max(maxTurnGap, end - lastTurn);
maxTimerDelay = Math.max(maxTimerDelay, end - lastTimer - 16);
running = false;
clearInterval(timer);
queue.port1.close();
queue.port2.close();
observer.disconnect();
if (firstDOM === null || !root.textContent.trimEnd().endsWith('LAST-MARKER')) {
    throw new Error('The complete fixture was not rendered');
}
// Hash outside the timed region to compare the rendered DOM across builds.
let hash = 2166136261;
const html = root.innerHTML;
for (let i = 0; i < html.length; i++) hash = Math.imul(hash ^ html.charCodeAt(i), 16777619);
return {
    visibility: document.visibilityState, bytes: new TextEncoder().encode(source).length,
    firstDOM, maxTurnGap, maxTimerDelay, complete: end - started, timerTicks, turns,
    firstBlockCount, firstHasEnd, blocks: root.childElementCount, domHash: hash >>> 0,
    guideLinks: root.querySelectorAll('a[href="https://example.com/guide"]').length
};
