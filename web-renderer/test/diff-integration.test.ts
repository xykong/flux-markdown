jest.mock('mermaid', () => ({
  initialize: jest.fn(),
  render: jest.fn().mockResolvedValue({ svg: '<svg>mocked diagram</svg>' }),
}));

import '../src/index';

describe('Task 4: renderSource with prevContent parameter', () => {
  beforeEach(() => {
    document.body.innerHTML = '<div id="markdown-preview"></div>';
  });

  test('renderSource without prevContent uses source-diff-wrap structure with line numbers', () => {
    window.renderSource('hello\nworld', 'light');
    const preview = document.getElementById('markdown-preview')!;
    const wrap = preview.querySelector('.source-diff-wrap');
    expect(wrap).toBeTruthy();
    expect(wrap!.querySelector('.source-diff-gutter')).toBeTruthy();
    expect(wrap!.querySelector('.source-diff-content')).toBeTruthy();
    const gutterText = wrap!.querySelector('.source-diff-gutter')!.textContent;
    expect(gutterText).toContain('1');
    expect(gutterText).toContain('2');
  });

  test('renderSource without prevContent shows no diff classes', () => {
    window.renderSource('line one\nline two', 'light');
    const preview = document.getElementById('markdown-preview')!;
    expect(preview.innerHTML).not.toContain('diff-added');
    expect(preview.innerHTML).not.toContain('diff-removed');
    expect(preview.innerHTML).not.toContain('diff-modified');
  });

  test('renderSource with prevContent shows diff annotations for added lines', () => {
    window.renderSource('hello\nnew line', 'light', 'hello');
    const preview = document.getElementById('markdown-preview')!;
    expect(preview.innerHTML).toContain('diff-added');
    expect(preview.innerHTML).toContain('diff-entering');
  });

  test('renderSource with prevContent shows diff annotations for modified lines', () => {
    window.renderSource('hello earth', 'light', 'hello world');
    const preview = document.getElementById('markdown-preview')!;
    expect(preview.innerHTML).toContain('diff-modified');
    expect(preview.innerHTML).toContain('diff-char-added');
    expect(preview.innerHTML).toContain('diff-char-removed');
  });

  test('renderSource with prevContent shows removed line annotations', () => {
    window.renderSource('hello', 'dark', 'hello\nworld');
    const preview = document.getElementById('markdown-preview')!;
    expect(preview.innerHTML).toContain('diff-removed');
  });

  test('renderSource accepts third parameter in type signature', () => {
    expect(() => window.renderSource('text', 'light', 'old text')).not.toThrow();
    expect(() => window.renderSource('text', 'light')).not.toThrow();
    expect(() => window.renderSource('text', 'light', undefined)).not.toThrow();
  });
});

describe('Task 5: data-source-line attribute injection in buildMd', () => {
  beforeEach(() => {
    document.body.innerHTML = '<div id="markdown-preview"></div>';
  });

  test('rendered block elements have data-source-line attribute', async () => {
    const markdown = '# Heading\n\nParagraph text\n\n- list item';
    await window.renderMarkdown(markdown);
    const preview = document.getElementById('markdown-preview')!;
    const elementsWithLine = preview.querySelectorAll('[data-source-line]');
    expect(elementsWithLine.length).toBeGreaterThan(0);
  });

  test('heading element has correct data-source-line', async () => {
    const markdown = '# Hello';
    await window.renderMarkdown(markdown);
    const preview = document.getElementById('markdown-preview')!;
    const heading = preview.querySelector('h1');
    expect(heading).toBeTruthy();
    expect(heading!.getAttribute('data-source-line')).toBe('1');
  });

  test('second paragraph has correct data-source-line', async () => {
    const markdown = 'First paragraph\n\nSecond paragraph';
    await window.renderMarkdown(markdown);
    const preview = document.getElementById('markdown-preview')!;
    const paragraphs = preview.querySelectorAll('p');
    expect(paragraphs.length).toBeGreaterThanOrEqual(2);
    expect(paragraphs[1].getAttribute('data-source-line')).toBe('3');
  });
});

describe('Task 6: renderMarkdown with prevContent diff annotation', () => {
  beforeEach(() => {
    document.body.innerHTML = '<div id="markdown-preview"></div>';
  });

  test('renderMarkdown with prevContent adds render-diff-block-enter class to added blocks when review mode is off', async () => {
    const oldContent = '# Title\n\nFirst paragraph';
    const newContent = '# Title\n\nFirst paragraph\n\nNew paragraph';

    await window.renderMarkdown(newContent, { prevContent: oldContent, reviewMode: false });
    const preview = document.getElementById('markdown-preview')!;
    const entering = preview.querySelectorAll('.render-diff-block-enter');
    expect(entering.length).toBeGreaterThan(0);
  });

  test('renderMarkdown without prevContent does not add diff classes', async () => {
    await window.renderMarkdown('# Hello\n\nWorld');
    const preview = document.getElementById('markdown-preview')!;
    expect(preview.querySelector('.render-diff-block-enter')).toBeNull();
    expect(preview.querySelector('.render-diff-block-modified')).toBeNull();
  });

  test('renderMarkdown with empty prevContent does not add diff classes', async () => {
    await window.renderMarkdown('# Hello\n\nWorld', { prevContent: '' });
    const preview = document.getElementById('markdown-preview')!;
    expect(preview.querySelector('.render-diff-block-enter')).toBeNull();
  });

  test('RenderOptions accepts prevContent property', async () => {
    await expect(
      window.renderMarkdown('# Test', { prevContent: 'old content' })
    ).resolves.not.toThrow();
  });

  test('renderMarkdown with YAML front matter only animates changed body blocks when review mode is off', async () => {
    const oldContent = '---\ntitle: Test\n---\n\n# Heading\n\nOld paragraph';
    const newContent = '---\ntitle: Test\n---\n\n# Heading\n\nNew paragraph';

    await window.renderMarkdown(newContent, { prevContent: oldContent, reviewMode: false });
    const preview = document.getElementById('markdown-preview')!;

    const heading = preview.querySelector('h1');
    expect(heading?.classList.contains('render-diff-block-enter')).toBe(false);
    expect(heading?.classList.contains('render-diff-block-modified')).toBe(false);

    const modified = preview.querySelectorAll('.render-diff-block-modified, .render-diff-block-enter');
    expect(modified.length).toBeGreaterThan(0);
  });

  test('rendered block elements have data-source-line-end attribute', async () => {
    await window.renderMarkdown('# Heading\n\nParagraph text');
    const preview = document.getElementById('markdown-preview')!;
    const heading = preview.querySelector('h1');
    expect(heading?.getAttribute('data-source-line-end')).toBeTruthy();
  });
});

describe('Review mode integration', () => {
  beforeEach(() => {
    document.body.innerHTML = '<div id="markdown-preview"></div>';
    window.localStorage.clear();
  });

  test('shows inline removed text and skips the transient animation', async () => {
    const oldText = 'This document describes where the app stores cookies and sessions';
    const newText = 'This document describes where the app stores sessions';

    await window.renderMarkdown(newText, { prevContent: oldText });
    const preview = document.getElementById('markdown-preview')!;

    expect(preview.querySelector('.review-toolbar')).toBeTruthy();
    const removed = preview.querySelector('.review-word-removed');
    expect(removed).toBeTruthy();
    expect(removed?.textContent).toContain('cookies and');
    expect(preview.querySelector('.render-diff-block-modified')).toBeNull();
  });

  test('shows inline added text', async () => {
    const oldText = 'This document describes where the app stores sessions';
    const newText = 'This document describes where the app stores cookies and sessions';

    await window.renderMarkdown(newText, { prevContent: oldText });
    const preview = document.getElementById('markdown-preview')!;

    const added = preview.querySelector('.review-word-added');
    expect(added).toBeTruthy();
    expect(added?.textContent).toContain('cookies');
  });
});
