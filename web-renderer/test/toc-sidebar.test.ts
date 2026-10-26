import type { HeadingNode } from '../src/outline';
import { TableOfContents } from '../src/table-of-contents';
const headings: HeadingNode[] = [{ level: 2, text: 'Title', id: 'title', children: [{ level: 3, text: 'Child', id: 'child', children: [] }]}];
let toc: TableOfContents;
beforeAll(() => { Object.defineProperty(window, "IntersectionObserver", { writable: true, value: class { observe() {} disconnect() {} } }); });
const resize = (width: number) => { Object.defineProperty(window, 'innerWidth', { configurable: true, value: width }); window.dispatchEvent(new Event('resize')); };
const visible = () => document.querySelector('.toc-nav')?.classList.contains('visible');
beforeEach(() => {
    document.body.innerHTML = '<div id="reading-controls"><div id="reading-toolbar"><div id="toc-button-container"></div></div></div><div id="toc-container"></div><div id="markdown-preview"><h2 id="title">Title</h2><h3 id="child">Child</h3></div>';
    document.documentElement.dataset.context = 'app';
    Object.defineProperty(window, 'innerWidth', { configurable: true, value: 1100 });
    window.__fluxLang = 'en'; toc = new TableOfContents('toc-container'); toc.render(headings);
});
afterEach(() => { toc?.dispose(); delete window.__fluxLang; });
test('wide contents docks, but shrinking never automatically opens an overlay', () => {
    expect(document.documentElement.dataset.tocDocked).toBe('true'); resize(700);
    expect(document.documentElement.dataset.tocDocked).toBe('false'); expect(visible()).toBe(false);
    resize(1100); expect(document.documentElement.dataset.tocDocked).toBe('true');
});
test('overlay choices do not overwrite docked preference across resize and reload', () => {
    toc.hide(); resize(700); toc.show(); toc.render(headings); expect(visible()).toBe(true);
    resize(1100); toc.render(headings); expect(visible()).toBe(false);
    toc.show(); resize(700); toc.show(); toc.hide(); resize(1100); expect(visible()).toBe(true);
});
test.each([899, 900, 901])('docking boundary at %i CSS pixels', width => {
    resize(width); expect(document.documentElement.dataset.tocDocked).toBe(String(width >= 900));
});
test('successful overlay navigation closes while invalid anchors keep it open', () => {
    resize(700); toc.show(); const target = document.getElementById('child')!; target.scrollIntoView = jest.fn();
    document.querySelector<HTMLAnchorElement>('[href="#child"]')!.click();
    expect(target.scrollIntoView).toHaveBeenCalled(); expect(visible()).toBe(false);
    toc.show(); target.remove(); document.querySelector<HTMLAnchorElement>('[href="#child"]')!.click(); expect(visible()).toBe(true);
});
test('docked navigation remains open with accessible current item', () => {
    document.getElementById('child')!.scrollIntoView = jest.fn(); document.querySelector<HTMLAnchorElement>('[href="#child"]')!.click();
    expect(visible()).toBe(true); expect(document.querySelector('[href="#child"]')?.getAttribute('aria-current')).toBe('location');
});
test('outside clicks close overlays; only app Escape is consumed and restores button focus', () => {
    resize(700); toc.show(); document.getElementById('markdown-preview')!.click(); expect(visible()).toBe(false); toc.show();
    const escape = new KeyboardEvent('keydown', { key: 'Escape', bubbles: true, cancelable: true }); document.dispatchEvent(escape);
    expect(escape.defaultPrevented).toBe(true); expect(visible()).toBe(false); expect(document.activeElement?.classList.contains('toc-toggle')).toBe(true);
    document.documentElement.dataset.context = 'quicklook'; toc.show();
    const systemEscape = new KeyboardEvent('keydown', { key: 'Escape', bubbles: true, cancelable: true }); document.dispatchEvent(systemEscape);
    expect(systemEscape.defaultPrevented).toBe(false); expect(visible()).toBe(true);
});
test('no headings and compact Finder hide controls without losing docked preference', () => {
    toc.hide(); toc.render([]); expect(document.querySelector<HTMLElement>('#toc-button-container')?.hidden).toBe(true);
    toc.render(headings); expect(visible()).toBe(false); document.documentElement.dataset.context = 'finder'; toc.render(headings);
    expect(document.documentElement.dataset.tocDocked).toBe('false'); expect(document.querySelector<HTMLElement>('#toc-button-container')?.hidden).toBe(true);
});
test('toolbar labels localize and indentation starts at the shallowest heading', () => {
    window.__fluxLang = 'zh'; toc.render(headings); expect(document.querySelector('.toc-toggle')?.getAttribute('aria-label')).toBe('目录');
    window.__fluxLang = 'ar'; toc.render(headings); expect(document.querySelector('.toc-toggle')?.getAttribute('aria-label')).toBe('المحتويات');
    expect(document.querySelector('[href="#title"]')?.getAttribute('data-depth')).toBe('0'); expect(document.querySelector('[href="#child"]')?.getAttribute('data-depth')).toBe('1');
    expect(document.querySelector('[href="#title"]')?.getAttribute('title')).toBe('Title');
});
test('disposed instances no longer close overlays in another document view', () => {
    resize(700); toc.show(); toc.dispose(); document.getElementById('markdown-preview')!.click(); expect(visible()).toBe(true);
});
test('active heading includes the reserved gap and navigation scroll margin', () => {
    document.getElementById('reading-controls')!.getBoundingClientRect = jest.fn(() => ({ bottom: 98 } as DOMRect));
    document.getElementById('title')!.getBoundingClientRect = jest.fn(() => ({ top: -100 } as DOMRect));
    document.getElementById('child')!.getBoundingClientRect = jest.fn(() => ({ top: 122 } as DOMRect));
    toc.render(headings);
    expect(document.querySelector('[aria-current="location"]')?.getAttribute('href')).toBe('#child');
});
