import { sanitizeDocumentHTML } from '../src/safe-html';

describe('document resource URI policy', () => {
  test.each(['plugin/assets/plugin.svg', 'assets/pic.png', './assets/pic.svg', '../pic.svg', 'chapter2/pic.svg', 'pic.svg', 'https://example.com/pic.svg', 'local-md:///tmp/pic.svg'])(
    'preserves passive resource reference %s', source => {
      const root = document.createElement('div');
      root.innerHTML = sanitizeDocumentHTML(`<img src="${source}"><a href="${source}">link</a>`);
      expect(root.querySelector('img')?.getAttribute('src')).toBe(source);
      expect(root.querySelector('a')?.getAttribute('href')).toBe(source);
    });

  test.each(['javascript:alert(1)', 'JaVaScRiPt:alert(1)', 'java&#x09;script:alert(1)', 'vbscript:msgbox(1)', 'custom-scheme:payload'])(
    'rejects unsupported executable URI %s', source => {
      const root = document.createElement('div');
      root.innerHTML = sanitizeDocumentHTML(`<img src="${source}" onerror="alert(1)"><a href="${source}">link</a>`);
      expect(root.querySelector('[src], [href], [onerror]')).toBeNull();
    });
});
