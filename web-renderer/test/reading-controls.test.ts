import { updateReadingControlsLayout, captureReadingAnchor } from '../src/reading-controls';
import { BlockquoteCollapse } from '../src/blockquote-collapse';
beforeEach(() => {
    document.documentElement.dataset.context = 'app';
    document.body.innerHTML = '<div id="reading-controls"><div id="reading-toolbar"><div id="toc-button-container" hidden><button>Contents</button></div><div id="collapse-btn-container" hidden></div></div></div><div id="search-container" style="display:none"></div><div id="markdown-preview"></div>';
});
test('no reading tools leaves no reserved empty row', () => {
    updateReadingControlsLayout(); expect(document.getElementById('reading-toolbar')?.hidden).toBe(true); expect(document.documentElement.dataset.readingControls).toBe('false');
});
test('floating search never changes reserved toolbar height', () => {
    document.getElementById('toc-button-container')!.hidden = false;
    const toolbar = document.getElementById('reading-toolbar')!;
    toolbar.getBoundingClientRect = jest.fn(() => ({ height: 32 } as DOMRect));
    updateReadingControlsLayout();
    expect(document.documentElement.style.getPropertyValue('--reading-controls-height')).toBe('32px');
    document.getElementById('search-container')!.style.display = 'flex';
    document.getElementById('reading-controls')!.getBoundingClientRect = jest.fn(() => ({ height: 98 } as DOMRect));
    updateReadingControlsLayout();
    expect(document.documentElement.style.getPropertyValue('--reading-controls-height')).toBe('32px');
    document.documentElement.dataset.context = 'finder'; updateReadingControlsLayout();
    expect(document.documentElement.dataset.readingControls).toBe('false');
    expect(document.documentElement.style.getPropertyValue('--reading-controls-height')).toBe('0px');
});
test('search without directory or quotes does not create an empty toolbar row', () => {
    document.getElementById('search-container')!.style.display = 'flex';
    updateReadingControlsLayout();
    expect(document.getElementById('reading-toolbar')!.hidden).toBe(true);
    expect(document.documentElement.dataset.readingControls).toBe('false');
});
test('blockquote controls only appear with targets and expose expanded state', () => {
    const bc = new BlockquoteCollapse('collapse-btn-container', 'markdown-preview'); bc.setInitialState(false);
    expect(document.getElementById('collapse-btn-container')!.hidden).toBe(true);
    document.getElementById('markdown-preview')!.innerHTML = '<blockquote>Quote</blockquote>'; bc.setInitialState(false);
    expect(document.getElementById('collapse-btn-container')!.hidden).toBe(false); expect(document.querySelector('.blockquote-collapse-toggle')?.getAttribute('aria-expanded')).toBe('true');
    bc.setInitialState(true); bc.setInitialState(true); expect(document.querySelectorAll('.blockquote-placeholder')).toHaveLength(1);
    expect(document.querySelector('.blockquote-collapse-toggle')?.getAttribute('aria-expanded')).toBe('false');
});

test('reading anchor is sampled below the floating search instead of the input', () => {
    const preview = document.getElementById('markdown-preview')!;
    preview.innerHTML = '<p id="reading-block">Text</p>';
    preview.getBoundingClientRect = jest.fn(() => ({ left: 20, width: 720 } as DOMRect));
    const search = document.getElementById('search-container')!;
    search.style.display = 'flex';
    search.getBoundingClientRect = jest.fn(() => ({ bottom: 152 } as DOMRect));
    const paragraph = document.getElementById('reading-block')!;
    Object.defineProperty(window, 'scrollY', { configurable: true, value: 300 });
    Object.defineProperty(document, 'elementFromPoint', { configurable: true, value: jest.fn((_x, y) => y >= 160 ? paragraph : search) });
    expect(captureReadingAnchor()?.element).toBe(paragraph);
    Object.defineProperty(window, 'scrollY', { configurable: true, value: 0 });
});

test('rightmost directory reserves its measured width for the native circle group', () => {
    document.documentElement.dataset.tocSide = 'right';
    const slot = document.getElementById('toc-button-container')!;
    slot.hidden = false;
    slot.getBoundingClientRect = jest.fn(() => ({ width: 48 } as DOMRect));
    const postMessage = jest.fn();
    window.webkit = { messageHandlers: { logger: { postMessage: jest.fn() }, linkClicked: { postMessage: jest.fn() }, readingToolsLayout: { postMessage } } };
    updateReadingControlsLayout();
    expect(postMessage).toHaveBeenLastCalledWith({ rightInset: 68 });
    document.documentElement.dataset.tocSide = 'left';
    updateReadingControlsLayout();
    expect(postMessage).toHaveBeenLastCalledWith({ rightInset: 0 });
    delete window.webkit;
});
test('Quick Look reserves room for the native Follow button when it is shown', () => {
    const reserve = () => document.documentElement.style.getPropertyValue('--reading-native-reserve');
    document.documentElement.dataset.context = 'quicklook';
    delete document.documentElement.dataset.followControl;
    updateReadingControlsLayout();
    expect(reserve()).toBe('318px');
    document.documentElement.dataset.followControl = 'true';
    updateReadingControlsLayout();
    expect(reserve()).toBe('356px');
    document.documentElement.dataset.context = 'app';
    updateReadingControlsLayout();
    expect(reserve()).toBe('280px');
    delete document.documentElement.dataset.followControl;
});
test('a visible scroll bar is included in the room native controls leave for Contents', () => {
    document.documentElement.dataset.tocSide = 'right';
    const slot = document.getElementById('toc-button-container')!;
    slot.hidden = false;
    slot.getBoundingClientRect = jest.fn(() => ({ width: 48 } as DOMRect));
    // The page is laid out left of a 15 px scroll bar; native controls measure from the view edge.
    Object.defineProperty(document.documentElement, 'clientWidth', { configurable: true, value: window.innerWidth - 15 });
    const postMessage = jest.fn();
    window.webkit = { messageHandlers: { logger: { postMessage: jest.fn() }, linkClicked: { postMessage: jest.fn() }, readingToolsLayout: { postMessage } } };
    updateReadingControlsLayout();
    expect(postMessage).toHaveBeenLastCalledWith({ rightInset: 83 });
    delete (document.documentElement as unknown as { clientWidth?: number }).clientWidth;
    delete window.webkit;
});
