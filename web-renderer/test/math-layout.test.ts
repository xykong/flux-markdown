import { installMathLayout } from '../src/math-layout';
import { rememberMathSource } from '../src/math-source-store';

test('confines oversized trusted inline math and restores ordinary baseline behavior after resize', () => {
    document.body.innerHTML='<div id="root"><p><span class="flux-math-source"><svg></svg></span></p></div>';
    const root=document.getElementById('root')!;const block=root.querySelector('p')!;const formula=root.querySelector<HTMLElement>('span')!;
    let width=80;Object.defineProperty(block,'clientWidth',{get:()=>width});
    formula.querySelector('svg')!.getBoundingClientRect=()=>({width:100} as DOMRect);
    const untrusted=installMathLayout(root);expect(formula.classList.contains('math-inline-overflow')).toBe(false);untrusted();
    rememberMathSource(formula,'$x$');const stop=installMathLayout(root);
    expect(formula.classList.contains('math-inline-overflow')).toBe(true);
    expect(formula.tabIndex).toBe(0);
    width=200;window.dispatchEvent(new Event('resize'));
    expect(formula.classList.contains('math-inline-overflow')).toBe(false);
    expect(formula.hasAttribute('tabindex')).toBe(false);
    stop();width=80;window.dispatchEvent(new Event('resize'));
    expect(formula.classList.contains('math-inline-overflow')).toBe(false);
});
