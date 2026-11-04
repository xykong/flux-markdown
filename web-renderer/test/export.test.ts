import '../src/index';

describe('Export HTML', () => {
    beforeEach(() => {
        document.body.innerHTML = `
            <div id="markdown-preview"></div>
            <div id="toc-container"></div>
            <div id="search-container"></div>
            <div id="outline-panel" style="display: block;">TOC content</div>
        `;
    });

    test('exportHTML returns a string containing <html', () => {
        const result = window.exportHTML();
        expect(typeof result).toBe('string');
        expect(result).toContain('<html');
    });
    test('SVG math export omits unused webfont rules but retains document styles', () => {
        const style=document.createElement('style');
        style.textContent='@font-face { font-family: KaTeX_Test; src: url("flux-renderer://bundle/test.woff2"); } .export-test { color: red; }';
        document.head.append(style);
        try {
            const html=window.exportHTML();
            expect(html).not.toContain('flux-renderer://bundle/test.woff2');
            expect(html).toContain('.export-test');
        } finally {style.remove();}
    });

    test('exportHTML returns DOCTYPE declaration', () => {
        const result = window.exportHTML();
        expect(result).toContain('<!DOCTYPE html>');
    });

    test('exportHTML hides outline-panel in output', () => {
        const result = window.exportHTML();
        const parser = new DOMParser();
        const doc = parser.parseFromString(result, 'text/html');
        const panel = doc.getElementById('outline-panel');
        if (panel) {
            expect(panel.style.display).toBe('none');
        }
    });
});

describe('Export PDF print styles', () => {
    test('exportHTML function is defined on window', () => {
        expect(typeof window.exportHTML).toBe('function');
    });

    test('exportHTML output does not contain outline-panel when present', () => {
        document.body.innerHTML = `
            <div id="markdown-preview"></div>
            <div id="outline-panel" style="display:block">TOC</div>
        `;
        const result = window.exportHTML();
        const parser = new DOMParser();
        const doc = parser.parseFromString(result, 'text/html');
        const panel = doc.getElementById('outline-panel') as HTMLElement | null;
        if (panel) {
            expect(panel.style.display).toBe('none');
        }
    });
});
