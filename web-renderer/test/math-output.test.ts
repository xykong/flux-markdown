import { sanitizeMathHTML } from '../src/safe-html';

describe('safe mathematical output', () => {
    function parse(html: string): HTMLDivElement {
        const root = document.createElement('div');
        root.innerHTML = sanitizeMathHTML(html);
        return root;
    }
    test('preserves the math container, local glyph and assistive semantics', () => {
        const root = parse('<mjx-container jax="SVG" display="true"><svg aria-hidden="true"><defs><path id="glyph" d="M0 0L1 1"/></defs><use href="#glyph"/></svg><mjx-assistive-mml><math><msup><mi>x</mi><mn>2</mn></msup></math></mjx-assistive-mml></mjx-container>');
        expect(root.querySelector('mjx-container')?.getAttribute('jax')).toBe('SVG');
        expect(root.querySelector('use')?.getAttribute('href')).toBe('#glyph');
        expect(root.querySelector('mjx-assistive-mml math msup')).not.toBeNull();
    });
    test('keeps standard equation links and keyboard access', () => {
        const root = parse('<mjx-container><svg><g id="eq-one"></g><a href="#eq-one" tabindex="0" aria-label="Equation 1"><text>(1)</text></a></svg></mjx-container>');
        expect(root.querySelector('a')?.getAttribute('href')).toBe('#eq-one');
        expect(root.querySelector('a')?.getAttribute('tabindex')).toBe('0');
    });
    test('rejects active content, unexpected custom elements and external glyphs', () => {
        const root = parse('<mjx-untrusted onclick="attack()">text</mjx-untrusted><script>attack()</script><svg onload="attack()"><foreignObject><iframe src="https://example.com"></iframe></foreignObject><use href="https://example.com/glyph.svg#x"/><a href="javascript:attack()">bad</a></svg>');
        expect(root.querySelector('script,iframe,foreignObject,mjx-untrusted,[onclick],[onload],use,a[href]')).toBeNull();
    });
    test('rejects missing, ambiguous and mixed-namespace glyph references', () => {
        const root = parse('<svg><defs><path id="dup"/><path id="dup"/><path id="ok"/></defs><use href="#missing"/><use href="#dup"/><use href="#ok" xlink:href="https://example.com/glyph"/></svg>');
        expect(root.querySelector('use')).toBeNull();
    });
});

test('mathematical SVG output cannot retain external image resources', () => {
    const root=document.createElement('div');
    root.innerHTML=sanitizeMathHTML('<svg><image href="https://example.invalid/glyph.svg" width="10" height="10"/></svg>');
    expect(root.querySelector('image')).toBeNull();
});
