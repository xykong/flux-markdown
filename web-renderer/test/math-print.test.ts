import { prepareMathPrint } from '../src/math-print';
test('keeps adjacent heading and display mathematics together only during printing',()=>{
    document.body.innerHTML='<div id="markdown-preview"><h2 id="title">Title</h2><div class="flux-math-source">Formula</div><p>Next</p></div>';
    const root=document.getElementById('markdown-preview')!;
    const before=root.innerHTML;
    const restore=prepareMathPrint(root);
    expect(root.querySelector('.math-print-group h2')?.id).toBe('title');
    expect(root.querySelector('.math-print-group .flux-math-source')).not.toBeNull();
    expect(root.lastElementChild?.tagName).toBe('P');
    restore();restore();
    expect(root.innerHTML).toBe(before);
});
test('does not join unrelated paragraphs or inline formulas',()=>{
    document.body.innerHTML='<div id="markdown-preview"><h2>Title</h2><p>Text <span class="flux-math-source">x</span></p></div>';
    const root=document.getElementById('markdown-preview')!;
    const restore=prepareMathPrint(root);
    expect(root.querySelector('.math-print-group')).toBeNull();restore();
});
