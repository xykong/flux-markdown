import { copiedMessage, installSelectionCopy, selectionCopyEnabled } from '../src/selection-copy';
import { blockCopyResult } from '../src/block-copy';
import { installErrorFeedback, setFeedbackGeneration } from '../src/error-feedback';
import { TextEncoder } from 'util';
Object.assign(globalThis, {TextEncoder});
test.each(['app', 'finder', undefined])('never enables in %s context', context => {
    expect(selectionCopyEnabled({context, selectionCopy:true})).toBe(false);
    const root = document.createElement('main'); document.body.append(root);
    installSelectionCopy(root, 'one', {context, selectionCopy:true});
    expect(root.querySelector('.selection-copy-tools')).toBeNull();
});
test('the native Copy as Markdown menu item copies the current selection', async () => {
    document.body.innerHTML = '<main><p>hello <strong>world</strong></p></main>';
    const root = document.querySelector('main')!;
    const postMessage = jest.fn(request => blockCopyResult(request.id, request.generation, true));
    window.webkit = {messageHandlers:{logger:{postMessage:jest.fn()},linkClicked:{postMessage:jest.fn()},selectionCopy:{postMessage}}};
    const original = Object.getOwnPropertyDescriptor(Range.prototype, 'getClientRects');
    Object.defineProperty(Range.prototype, 'getClientRects', {configurable:true, value: () => [{left:0,right:100,top:0,bottom:20}]});
    const dispose = installSelectionCopy(root, 'menu', {context:'quicklook',selectionCopy:true});
    try {
        const selection = window.getSelection()!;
        const range = document.createRange(); range.selectNodeContents(root.querySelector('p')!);
        selection.removeAllRanges(); selection.addRange(range);
        window.copyQuickLookSelection?.('markdown');
        await Promise.resolve(); await Promise.resolve();
        expect(postMessage).toHaveBeenCalledWith(expect.objectContaining({text:'hello **world**'}));
    } finally {
        dispose(); delete window.webkit;
        if (original) Object.defineProperty(Range.prototype,'getClientRects',original);
        else Reflect.deleteProperty(Range.prototype,'getClientRects');
    }
});
test('a right-click keeps the selection toolbar where it is', async () => {
    document.body.innerHTML = '<main><p>selected text</p></main>';
    const root = document.querySelector('main')!;
    const dispose = installSelectionCopy(root, 'right-click', {context:'quicklook',selectionCopy:true,showCopyButtons:true});
    const original = Object.getOwnPropertyDescriptor(Range.prototype, 'getClientRects');
    Object.defineProperty(Range.prototype, 'getClientRects', {configurable:true, value: () => [{left:0,right:100,top:0,bottom:20}]});
    try {
        const range = document.createRange(); range.selectNodeContents(root.querySelector('p')!);
        const selection = window.getSelection()!; selection.removeAllRanges(); selection.addRange(range);
        document.dispatchEvent(new Event('selectionchange'));
        await new Promise(resolve => requestAnimationFrame(resolve));
        const tools = root.querySelector<HTMLElement>('.selection-copy-tools')!;
        expect(tools.hidden).toBe(false);
        root.querySelector('p')!.dispatchEvent(new MouseEvent('pointerdown', {bubbles:true,button:2}));
        document.dispatchEvent(new Event('selectionchange'));
        await new Promise(resolve => requestAnimationFrame(resolve));
        expect(tools.hidden).toBe(false);
    } finally {
        dispose();
        if (original) Object.defineProperty(Range.prototype,'getClientRects',original);
        else Reflect.deleteProperty(Range.prototype,'getClientRects');
    }
});
test('requires explicit capability and Markdown format', () => {
    expect(selectionCopyEnabled({context:'quicklook'})).toBe(false);
    expect(selectionCopyEnabled({context:'quicklook',selectionCopy:true,format:'tsv'})).toBe(false);
});
test('disposes UI and ignores synthetic copy activation', () => {
    const root = document.createElement('main'); document.body.append(root);
    const dispose = installSelectionCopy(root,'one',{context:'quicklook',selectionCopy:true,showCopyButtons:true});
    const buttons = Array.from(root.querySelectorAll('button'));
    expect(buttons.map(button => button.textContent)).toEqual(['⧉', 'MD']);
    expect(buttons.map(button => button.getAttribute('aria-label'))).toEqual(['Copy as Plain Text', 'Copy as Markdown']);
    const event = new Event('copy', {cancelable:true}); document.dispatchEvent(event);
    expect(event.defaultPrevented).toBe(false);
    dispose(); expect(root.querySelector('.selection-copy-tools')).toBeNull();
    expect(window.copyQuickLookSelection).toBeUndefined();
});

test('block-copy control interactions hide the selection popup and clear the selection without cancelling their click', async () => {
    document.body.innerHTML = '<main><p>selected text</p><div class="block-copy-tools"><button>Copy</button></div></main>';
    const root = document.querySelector('main')!;
    const originalRects = Object.getOwnPropertyDescriptor(Range.prototype, 'getClientRects');
    Object.defineProperty(Range.prototype,'getClientRects',{configurable:true,value:()=>[{left:0,right:100,top:0,bottom:20}]});
    const range = document.createRange(); range.selectNodeContents(root.querySelector('p')!);
    const selection = window.getSelection()!; selection.removeAllRanges(); selection.addRange(range);
    const dispose = installSelectionCopy(root, 'block-interaction', {context:'quicklook',selectionCopy:true,showCopyButtons:true});
    const tools = root.querySelector<HTMLElement>('.selection-copy-tools')!;
    tools.hidden = false;
    const button = root.querySelector<HTMLButtonElement>('.block-copy-tools button')!;
    const clicked = jest.fn(); button.addEventListener('click',clicked);
    try {
        button.dispatchEvent(new MouseEvent('pointerdown',{bubbles:true,cancelable:true,button:0}));
        button.dispatchEvent(new MouseEvent('pointerup',{bubbles:true,button:0}));
        button.click();
        await new Promise(resolve => requestAnimationFrame(resolve));
        expect(tools.hidden).toBe(true);
        expect(clicked).toHaveBeenCalledTimes(1);
        // The block button copies its block; the earlier selection is dropped so it does not look copied.
        expect(selection.toString()).toBe('');
    } finally {
        dispose();
        if (originalRects) Object.defineProperty(Range.prototype,'getClientRects',originalRects);
        else Reflect.deleteProperty(Range.prototype,'getClientRects');
    }
});

test('copied message names the line count and format in every language', () => {
    expect(copiedMessage('en', 'one', 'plain')).toBe('Copied 1 line as plain text');
    expect(copiedMessage('en', 'one\ntwo\nthree\n', 'markdown')).toBe('Copied 3 lines as Markdown');
    for (const language of ['zh', 'de', 'fr', 'es', 'ar']) expect(copiedMessage(language, 'a\nb', 'plain')).toContain('2');
});
test('the menu copy reports itself even when copy buttons are turned off, then clears', async () => {
    jest.useFakeTimers();
    document.body.innerHTML = '<main><p>first line</p><p>second line</p></main>';
    const root = document.querySelector('main')!;
    const original = Object.getOwnPropertyDescriptor(Range.prototype, 'getClientRects');
    Object.defineProperty(Range.prototype, 'getClientRects', {configurable:true, value: () => [{left:0,right:100,top:0,bottom:20}]});
    const postMessage = jest.fn(request => blockCopyResult(request.id, request.generation, true));
    window.webkit = {messageHandlers:{logger:{postMessage:jest.fn()},linkClicked:{postMessage:jest.fn()},selectionCopy:{postMessage}}};
    const dispose = installSelectionCopy(root, 'feedback', {context:'quicklook',selectionCopy:true,showCopyButtons:false});
    try {
        const range = document.createRange(); range.selectNodeContents(root);
        const selection = window.getSelection()!; selection.removeAllRanges(); selection.addRange(range);
        window.copyQuickLookSelection?.('markdown');
        await Promise.resolve(); await Promise.resolve();
        const tools = root.querySelector<HTMLElement>('.selection-copy-tools')!;
        const labels = () => Array.from(tools.querySelectorAll('button')).map(button => button.textContent);
        expect(tools.hidden).toBe(false);
        expect(tools.dataset.copyState).toBe('success');
        expect(tools.querySelector('[role=status]')?.textContent).toMatch(/^Copied \d+ lines? as Markdown$/);
        expect(labels()).toEqual(['⧉', '✓']);
        jest.advanceTimersByTime(2000);
        expect(tools.hidden).toBe(true);
        expect(tools.dataset.copyState).toBeUndefined();
        expect(labels()).toEqual(['⧉', 'MD']);
    } finally {
        dispose(); jest.useRealTimers();
        if (original) Object.defineProperty(Range.prototype,'getClientRects',original);
        else Reflect.deleteProperty(Range.prototype,'getClientRects');
        delete window.webkit;
    }
});

test('a late successful clipboard acknowledgment respects Escape', async () => {
    document.body.innerHTML = '<main><p>selected</p></main>';
    const root = document.querySelector('main')!;
    const postMessage = jest.fn();
    window.webkit = {messageHandlers:{logger:{postMessage:jest.fn()},linkClicked:{postMessage:jest.fn()},selectionCopy:{postMessage}}};
    const dispose = installSelectionCopy(root, 'one', {context:'quicklook',selectionCopy:true,showCopyButtons:true});
    const range = document.createRange();
    range.selectNodeContents(root.querySelector('p')!);
    const selection = window.getSelection()!;
    selection.removeAllRanges();
    selection.addRange(range);
    try {
        window.copyQuickLookSelection?.('markdown');
        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
        const {id, generation} = postMessage.mock.calls[0][0];
        blockCopyResult(id, generation, true);
        await Promise.resolve(); await Promise.resolve();
        expect(root.querySelector<HTMLElement>('.selection-copy-tools')!.hidden).toBe(true);
    } finally { dispose(); delete window.webkit; }
});

test('Copy as Markdown does not reuse a cleared selection', async () => {
    document.body.innerHTML = '<main><p>old selection</p></main>';
    const root = document.querySelector('main')!;
    const postMessage = jest.fn();
    window.webkit = {messageHandlers:{logger:{postMessage:jest.fn()},linkClicked:{postMessage:jest.fn()},selectionCopy:{postMessage}}};
    const dispose = installSelectionCopy(root, 'one', {context:'quicklook',selectionCopy:true});
    const selection = window.getSelection()!;
    const range = document.createRange();
    range.selectNodeContents(root);
    selection.removeAllRanges();
    selection.addRange(range);
    try {
        document.dispatchEvent(new Event('selectionchange'));
        await new Promise(resolve => requestAnimationFrame(resolve));
        selection.removeAllRanges();
        window.copyQuickLookSelection?.('markdown');
        expect(postMessage).not.toHaveBeenCalled();
    } finally { dispose(); delete window.webkit; }
});

test('an unconfirmed copy records shared feedback and ignores a late acknowledgement', async () => {
    jest.useFakeTimers();
    document.body.innerHTML = '<main><p>selection text</p></main>';
    const root = document.querySelector('main')!;
    const previousRects = Object.getOwnPropertyDescriptor(Range.prototype, 'getClientRects');
    Object.defineProperty(Range.prototype, 'getClientRects', {configurable:true, value: () => [{left:0,right:100,top:0,bottom:20}]});
    const copy = jest.fn(), feedback = jest.fn();
    window.webkit = {messageHandlers:{logger:{postMessage:jest.fn()},linkClicked:{postMessage:jest.fn()},
        selectionCopy:{postMessage:copy},errorFeedback:{postMessage:feedback}}};
    setFeedbackGeneration('copy-timeout');
    const stopFeedback = installErrorFeedback(root);
    const dispose = installSelectionCopy(root, 'copy-timeout', {context:'quicklook',selectionCopy:true});
    try {
        const range = document.createRange();
        range.selectNodeContents(root.querySelector('p')!);
        const selection = window.getSelection()!;
        selection.removeAllRanges();
        selection.addRange(range);
        window.copyQuickLookSelection?.('markdown');
        const request = copy.mock.calls[0][0];
        jest.advanceTimersByTime(5000);
        await Promise.resolve(); await Promise.resolve();
        const toolbar = root.querySelector<HTMLElement>('.selection-copy-tools')!;
        expect(toolbar.dataset.copyState).toBe('error');
        expect(feedback).toHaveBeenCalledWith({action:'record', kind:'copy', generation:'copy-timeout',
            id:expect.any(String), reason:'operationFailed'});
        expect(toolbar.querySelector('[data-feedback-action=inspect]')).not.toBeNull();
        blockCopyResult(request.id, request.generation, true);
        await Promise.resolve();
        expect(toolbar.dataset.copyState).toBe('error');
        document.dispatchEvent(new KeyboardEvent('keydown', {key:'Escape'}));
        expect(toolbar.querySelector('[data-feedback-action=inspect]')).toBeNull();
    } finally {
        dispose(); stopFeedback(); setFeedbackGeneration(''); delete window.webkit;
        if (previousRects) Object.defineProperty(Range.prototype, 'getClientRects', previousRects);
        else Reflect.deleteProperty(Range.prototype, 'getClientRects');
        jest.useRealTimers();
    }
});
