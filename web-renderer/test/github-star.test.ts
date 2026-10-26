jest.mock('mermaid', () => ({initialize: jest.fn(), render: jest.fn()}));
import '../src/index';
import { HelpOverlay } from '../src/help-overlay';

describe('GitHub support entry', () => {
 beforeEach(() => { document.body.innerHTML = ''; localStorage.clear(); });
 test.each(['app', 'quicklook'])('opens the canonical repository from %s help', context => {
  window.__fluxContext = context; window.__fluxLang = 'zh';
  const overlay = new HelpOverlay(); overlay.show();
  const link = document.querySelector<HTMLAnchorElement>('.help-github-star');
  expect(link?.href).toBe('https://github.com/xykong/flux-markdown');
  expect(link?.textContent).toContain('Star');
  expect(link?.title).toContain('GitHub');
  expect(document.body.textContent).not.toContain('已点赞');
  overlay.hide();
 });
 test.each(['en','de','fr','ar'])('localized support link is present for %s', language => {
  window.__fluxLang = language;
  const overlay = new HelpOverlay(); overlay.show();
  expect(document.querySelector('.help-github-star')?.textContent).toContain('GitHub');
 });
});


test('click hands the exact repository URL to the native browser bridge', () => {
 document.body.innerHTML = '';
 window.__fluxContext = 'quicklook';
 const open = jest.fn();
 window.webkit = { messageHandlers: {logger: {postMessage: jest.fn()},linkClicked: {postMessage: open}} };
 const overlay = new HelpOverlay(); overlay.show();
 document.querySelector<HTMLAnchorElement>('.help-github-star')!.click();
 expect(open).toHaveBeenCalledTimes(1);
 expect(open).toHaveBeenCalledWith('https://github.com/xykong/flux-markdown');
 delete window.webkit;
});
