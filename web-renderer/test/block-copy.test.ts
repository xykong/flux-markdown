import { TextEncoder } from 'util';
Object.assign(globalThis, { TextEncoder });
import { blockPlainText, installBlockCopy, CopyRequest } from '../src/block-copy';

function fixture(html: string): HTMLElement {
    document.body.innerHTML = `<main>${html}</main>`;
    return document.querySelector('main')!;
}

test('code preserves tabs, decoded entities, blank lines and final newline', () => {
    const root = fixture('<pre><code>\t中文 &lt;x&gt; 😀\n\n  end\n</code></pre>');
    expect(blockPlainText(root.querySelector('pre')!)).toBe('\t中文 <x> 😀\n\n  end\n');
});

test('quotes retain semantic boundaries, alt and labels, without controls or duplicate nested text', () => {
    const root = fixture('<blockquote><p>Hello <a href="https://example.com">link</a> <img alt="diagram"></p><ul><li>one</li><li>two</li></ul><blockquote><p>nested</p></blockquote><pre><code>\tx\n  y\n</code></pre><span class="block-copy-tools">Copy</span><div class="error-feedback-controls">Report</div></blockquote>');
    expect(blockPlainText(root.querySelector('blockquote')!)).toBe('Hello link diagram\n\none\ntwo\n\nnested\n\n\tx\n  y\n');
});

test('alert title is retained without its decorative icon', () => {
    const root = fixture('<div class="markdown-alert"><p class="markdown-alert-title"><svg><title>icon</title></svg>Note</p><p>Body &amp; text</p></div>');
    expect(blockPlainText(root.firstElementChild!)).toBe('Note\n\nBody & text');
});

test('controls snapshot code before line number transformation and acknowledge actual results', async () => {
    const root = fixture('<pre><code>a\n</code></pre>');
    const send = jest.fn<Promise<boolean>, [CopyRequest]>().mockResolvedValue(true);
    const controller = installBlockCopy(root, 'generation', send);
    root.querySelector('code')!.textContent = 'a';
    await controller.copy(root.querySelector('pre')!);
    expect(send).toHaveBeenCalledWith(expect.objectContaining({ text: 'a\n', generation: 'generation' }));
    expect(root.querySelector('[role="status"]')!.textContent).toBe('Copied');
    controller.dispose();
    expect(root.querySelector('.block-copy-tools')).toBeNull();
});

test('failure and late acknowledgement never show false success', async () => {
    const root = fixture('<pre><code>hello</code></pre>');
    let resolve!: (success: boolean) => void;
    const controller = installBlockCopy(root, 'old', () => new Promise(r => { resolve = r; }));
    const pending = controller.copy(root.querySelector('pre')!);
    controller.dispose(); resolve(true); await pending;
    expect(root.textContent).toBe('hello');
    const failed = installBlockCopy(root, 'new', async () => false);
    await failed.copy(root.querySelector('pre')!);
    expect(root.querySelector('.block-copy-error')).not.toBeNull();
    expect(root.querySelector('[role="status"]')!.textContent).not.toBe('Copied');
    failed.dispose();
});

test('synthetic clicks cannot write and duplicate installation does not duplicate controls', () => {
    const root = fixture('<pre><code>x</code></pre><blockquote><p>q</p></blockquote>');
    const send = jest.fn(async () => true);
    const first = installBlockCopy(root, 'one', send);
    root.querySelector<HTMLButtonElement>('button')!.click();
    expect(send).not.toHaveBeenCalled();
    first.dispose();
    const second = installBlockCopy(root, 'two', send);
    expect(root.querySelectorAll('.block-copy-tools')).toHaveLength(2);
    second.dispose();
});


test('oversized content is refused without truncation or native writes', async () => {
    const root = fixture('<pre><code></code></pre>');
    root.querySelector('code')!.textContent = '中'.repeat(1400000);
    const send = jest.fn(async () => true);
    const controller = installBlockCopy(root, 'large', send);
    await controller.copy(root.querySelector('pre')!);
    expect(send).not.toHaveBeenCalled();
    expect(root.querySelector('.block-copy-error')).not.toBeNull();
    controller.dispose();
});

test('pending copies are coalesced and native timeout remains a failure', async () => {
    jest.useFakeTimers();
    const root = fixture('<pre><code>private fixture</code></pre>');
    const postMessage = jest.fn();
    window.webkit = {messageHandlers:{logger:{postMessage:jest.fn()},linkClicked:{postMessage:jest.fn()},blockCopy:{postMessage}}};
    const controller = installBlockCopy(root, 'timeout');
    const first = controller.copy(root.querySelector('pre')!);
    await controller.copy(root.querySelector('pre')!);
    expect(postMessage).toHaveBeenCalledTimes(1);
    jest.advanceTimersByTime(5001); await first;
    expect(root.querySelector('.block-copy-error')).not.toBeNull();
    controller.dispose(); jest.useRealTimers();
});

test('copy failures use contextual feedback without document text', async () => {
    const { installErrorFeedback, setFeedbackGeneration } = await import('../src/error-feedback');
    const postMessage = jest.fn();
    window.webkit = { messageHandlers: { logger:{postMessage:jest.fn()}, linkClicked:{postMessage:jest.fn()}, errorFeedback:{postMessage} } };
    setFeedbackGeneration('incident-generation');
    const root = fixture('<blockquote><p>private document text</p><pre><code>nested</code></pre></blockquote>');
    const feedback = installErrorFeedback(root);
    const controller = installBlockCopy(root, 'incident-generation', async () => false);
    await controller.copy(root.querySelector('blockquote')!);
    await new Promise(resolve => setTimeout(resolve, 0));
    root.querySelector<HTMLButtonElement>('[data-feedback-action="report"]')!.click();
    expect(postMessage.mock.calls.map(call => call[0].action)).toEqual(['record','report']);
    expect(postMessage.mock.calls[1][0]).toMatchObject({kind:'copy', generation:'incident-generation'});
    expect(JSON.stringify(postMessage.mock.calls)).not.toContain('private document');
    const select = Array.from(root.querySelectorAll<HTMLButtonElement>('button')).find(b=>b.textContent==='Select Text')!;
    select.click();
    expect(window.getSelection()?.toString()).toContain('private document text');
    controller.dispose(); feedback();
});

test('copy lifecycle pins feedback visible until success expires, and keeps errors reachable', async () => {
    jest.useFakeTimers();
    const root = fixture('<pre><code>x</code></pre>');
    let resolve!: (success: boolean) => void;
    const controller = installBlockCopy(root, 'visibility', () => new Promise(r => { resolve = r; }));
    const tools = root.querySelector<HTMLElement>('.block-copy-tools')!;
    expect(tools.dataset.copyState).toBeUndefined();
    const copying = controller.copy(root.querySelector('pre')!);
    expect(tools.dataset.copyState).toBe('pending');
    resolve(true); await copying;
    expect(tools.dataset.copyState).toBe('success');
    jest.advanceTimersByTime(2001);
    expect(tools.dataset.copyState).toBeUndefined();
    const failed = controller.copy(root.querySelector('pre')!);
    resolve(false); await failed;
    expect(tools.dataset.copyState).toBe('error');
    jest.advanceTimersByTime(10000);
    expect(tools.dataset.copyState).toBe('error');
    controller.dispose(); jest.useRealTimers();
});
