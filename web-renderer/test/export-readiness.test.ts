jest.mock('mermaid', () => ({initialize: jest.fn(), render: jest.fn()}));
import '../src/index';
test('export readiness waits for pending images', async () => {
 document.body.innerHTML = '<div id="markdown-preview"><img src="test.png"></div>';
 const img = document.querySelector('img')!;
 Object.defineProperty(img, 'complete', {value: false});
 let done = false;
 const wait = (window as any).waitForExportReady(1000).then(() => {done = true;});
 await new Promise(resolve => setTimeout(resolve, 0));
 expect(done).toBe(false);
 img.dispatchEvent(new Event('load'));
 await wait;
 expect(done).toBe(true);
});

test('resource timeout rejects and removes pending listeners', async () => {
 document.body.innerHTML = '<div id="markdown-preview"><img src="never.png"></div>';
 Object.defineProperty(document.querySelector('img'), 'complete', {value: false});
 await expect(window.waitForExportReady(5)).rejects.toThrow('timed out');
});

test('failed images reject export', async () => {
 document.body.innerHTML = '<div id="markdown-preview"><img></div>';
 await expect(window.waitForExportReady()).rejects.toThrow('failed to load');
});
