import { DiffAnimator } from '../src/diff-animator';
import { computeLineDiff } from '../src/diff-engine';

describe('DiffAnimator.buildSourceHTML', () => {
  let animator: DiffAnimator;

  beforeEach(() => {
    animator = new DiffAnimator();
  });

  test('equal lines render with line numbers, no diff classes', () => {
    const diffs = computeLineDiff('', 'hello\nworld');
    const html = animator.buildSourceHTML(diffs, 'light');
    expect(html).toContain('class="source-diff-line-num"');
    expect(html).toContain('>1<');
    expect(html).toContain('>2<');
    expect(html).not.toContain('diff-added');
    expect(html).not.toContain('diff-removed');
  });

  test('added line gets diff-added class on gutter and content', () => {
    const diffs = computeLineDiff('hello', 'hello\nworld');
    const html = animator.buildSourceHTML(diffs, 'light');
    expect(html).toContain('diff-added');
    expect(html).toContain('diff-entering');
  });

  test('removed line gets diff-removed and diff-exiting classes', () => {
    const diffs = computeLineDiff('hello\nworld', 'hello');
    const html = animator.buildSourceHTML(diffs, 'light');
    expect(html).toContain('diff-removed');
    expect(html).toContain('diff-exiting');
  });

  test('modified line contains char diff spans', () => {
    const diffs = computeLineDiff('hello world', 'hello earth');
    const html = animator.buildSourceHTML(diffs, 'light');
    expect(html).toContain('diff-char-removed');
    expect(html).toContain('diff-char-added');
  });

  test('empty lines preserve newline character so WebKit selection copying retains blank lines', () => {
    const diffs = computeLineDiff('', 'line 1\n\nline 3');
    const html = animator.buildSourceHTML(diffs, 'light');
    const container = document.createElement('div');
    container.innerHTML = html;
    const lines = container.querySelectorAll('.source-diff-line');
    expect(lines.length).toBe(3);
    expect(lines[0].textContent).toBe('line 1');
    expect(lines[1].textContent).toBe('\n');
    expect(lines[2].textContent).toBe('line 3');
  });
});

describe('DiffAnimator.annotateRenderDOM', () => {
  let animator: DiffAnimator;

  beforeEach(() => {
    animator = new DiffAnimator();
    document.body.innerHTML = '<div id="markdown-preview"></div>';
  });

  test('elements with data-source-line matching added lines get enter class', () => {
    const container = document.getElementById('markdown-preview')!;
    container.innerHTML = `
      <p data-source-line="1">Hello</p>
      <p data-source-line="2">World</p>
    `;
    const diffs = computeLineDiff('Hello', 'Hello\nWorld');
    animator.annotateRenderDOM(container, diffs);
    const p2 = container.querySelector('[data-source-line="2"]');
    expect(p2?.classList.contains('render-diff-block-enter')).toBe(true);
  });

  test('modified source lines get amber pulse class without corrupting rendered HTML', () => {
    const container = document.getElementById('markdown-preview')!;
    container.innerHTML = `<p data-source-line="1">hello world</p>`;
    const diffs = computeLineDiff('hello world', 'hello earth');
    animator.annotateRenderDOM(container, diffs);
    const p = container.querySelector('p')!;
    expect(p.classList.contains('render-diff-block-modified')).toBe(true);
    expect(p.innerHTML).toBe('hello world');
  });

  test('multi-line block gets animated when change is on non-first line', () => {
    const container = document.getElementById('markdown-preview')!;
    container.innerHTML = `<p data-source-line="1" data-source-line-end="3">Multi\nline\nblock</p>`;
    const diffs = computeLineDiff('Multi\nline\nold', 'Multi\nline\nnew');
    animator.annotateRenderDOM(container, diffs);
    const p = container.querySelector('p')!;
    expect(p.classList.contains('render-diff-block-modified')).toBe(true);
  });

  test('block spanning multiple lines does not animate when no change in its range', () => {
    const container = document.getElementById('markdown-preview')!;
    container.innerHTML = `
      <p data-source-line="1" data-source-line-end="2">Unchanged block</p>
      <p data-source-line="3" data-source-line-end="3">Changed block</p>
    `;
    const diffs = computeLineDiff('Unchanged block\n\nOld line', 'Unchanged block\n\nNew line');
    animator.annotateRenderDOM(container, diffs);
    const p1 = container.querySelectorAll('p')[0];
    const p2 = container.querySelectorAll('p')[1];
    expect(p1.classList.contains('render-diff-block-modified')).toBe(false);
    expect(p1.classList.contains('render-diff-block-enter')).toBe(false);
    expect(p2.classList.contains('render-diff-block-modified')).toBe(true);
  });

  test('deleted lines cause a marker chip to appear before the following surviving block', () => {
    const container = document.getElementById('markdown-preview')!;
    const oldDoc = 'Keep\nGone\nAlso gone\nSurvives';
    const newDoc = 'Keep\nSurvives';
    container.innerHTML = `
      <p data-source-line="1" data-source-line-end="1">Keep</p>
      <p data-source-line="2" data-source-line-end="2">Survives</p>
    `;
    const diffs = computeLineDiff(oldDoc, newDoc);
    animator.annotateRenderDOM(container, diffs);
    const markers = container.querySelectorAll('.render-diff-deleted-marker');
    expect(markers.length).toBeGreaterThan(0);
  });

  test('no deleted marker when no lines are removed', () => {
    const container = document.getElementById('markdown-preview')!;
    container.innerHTML = `<p data-source-line="1">Hello</p>`;
    const diffs = computeLineDiff('Hello', 'Hello world');
    animator.annotateRenderDOM(container, diffs);
    expect(container.querySelector('.render-diff-deleted-marker')).toBeNull();
  });
});
