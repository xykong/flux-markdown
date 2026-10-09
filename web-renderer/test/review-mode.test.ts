import {
  collectBlocks,
  computeBlockChanges,
  hashText,
  inlineDiff,
  normalizeBlockText,
  ReviewController,
  clearReviewDom,
  stripReviewHtml,
} from '../src/review-mode';

function block(tag: string, text: string, start: number, end: number): string {
  return `<${tag} data-source-line="${start}" data-source-line-end="${end}">${text}</${tag}>`;
}

function makeContainer(html: string): HTMLElement {
  const container = document.createElement('div');
  container.innerHTML = html;
  document.body.appendChild(container);
  return container;
}

beforeAll(() => {
  Element.prototype.scrollIntoView = jest.fn();
});

beforeEach(() => {
  document.body.innerHTML = '';
  window.localStorage.clear();
});

describe('text helpers', () => {
  test('normalizeBlockText collapses whitespace', () => {
    expect(normalizeBlockText('  a\n\n  b  ')).toBe('a b');
  });

  test('hashText is stable and differs for different text', () => {
    expect(hashText('hello')).toBe(hashText('hello'));
    expect(hashText('hello')).not.toBe(hashText('world'));
  });
});

describe('collectBlocks', () => {
  test('collects only elements with data-source-line', () => {
    const container = makeContainer(block('p', 'one', 1, 1) + '<p>no line</p>' + block('h1', 'two', 3, 3));
    const blocks = collectBlocks(container);
    expect(blocks.map((b) => b.text)).toEqual(['one', 'two']);
  });

  test('skips rendered diagram containers', () => {
    const container = makeContainer('<div class="mermaid" data-source-line="3" data-source-line-end="5">graph</div>');
    expect(collectBlocks(container)).toHaveLength(0);
  });

  test('skips diagram fences in the baseline', () => {
    const container = makeContainer(block('p', 'same', 1, 1));
    const baseline = makeContainer(
      block('p', 'same', 1, 1) +
        '<pre data-source-line="3" data-source-line-end="5"><code class="language-mermaid">graph TD</code></pre>'
    );
    expect(computeBlockChanges(collectBlocks(container), collectBlocks(baseline))).toHaveLength(0);
  });
});

describe('computeBlockChanges', () => {
  test('detects an added block', () => {
    const container = makeContainer(block('p', 'a', 1, 1) + block('p', 'b', 3, 3));
    const baseline = makeContainer(block('p', 'a', 1, 1));
    const changes = computeBlockChanges(collectBlocks(container), collectBlocks(baseline));
    expect(changes).toHaveLength(1);
    expect(changes[0].type).toBe('added');
  });

  test('detects a removed block', () => {
    const container = makeContainer(block('p', 'a', 1, 1));
    const baseline = makeContainer(block('p', 'a', 1, 1) + block('p', 'b', 3, 3));
    const changes = computeBlockChanges(collectBlocks(container), collectBlocks(baseline));
    expect(changes).toHaveLength(1);
    expect(changes[0].type).toBe('removed');
    expect(changes[0].insertBefore).toBeNull();
  });

  test('pairs removed and added blocks as modified', () => {
    const container = makeContainer(block('p', 'hello world', 1, 1));
    const baseline = makeContainer(block('p', 'hello earth', 1, 1));
    const changes = computeBlockChanges(collectBlocks(container), collectBlocks(baseline));
    expect(changes).toHaveLength(1);
    expect(changes[0].type).toBe('modified');
  });

  test('returns no change for equal documents', () => {
    const container = makeContainer(block('p', 'same', 1, 1));
    const baseline = makeContainer(block('p', 'same', 1, 1));
    expect(computeBlockChanges(collectBlocks(container), collectBlocks(baseline))).toHaveLength(0);
  });
});

describe('inlineDiff', () => {
  test('wraps added words', () => {
    const html = inlineDiff('hello world', 'hello brave world');
    expect(html).toContain('review-word-added');
    expect(html).toContain('brave');
  });

  test('marks removed words with del elements', () => {
    const html = inlineDiff('hello brave world', 'hello world');
    expect(html).toContain('del class="review-word-removed"');
    expect(html).toContain('brave');
  });

  test('preserves link elements', () => {
    const oldHtml = 'visit <a href="https://example.com">site</a>';
    const newHtml = 'visit <a href="https://example.com">site now</a>';
    const html = inlineDiff(oldHtml, newHtml);
    expect(html).toContain('<a href="https://example.com">');
    expect(html).toContain('review-word-added');
  });

  test('returns null for a large rewrite', () => {
    expect(inlineDiff('alpha beta gamma delta', 'one two three four')).toBeNull();
  });

  test('returns null for a diagram', () => {
    expect(inlineDiff('<svg></svg>', '<svg></svg>')).toBeNull();
  });

  test('returns null when only tags changed', () => {
    expect(inlineDiff('<strong>same</strong>', '<em>same</em>')).toBeNull();
  });
});

describe('ReviewController', () => {
  const baselineHtml = block('p', 'hello world', 1, 1);

  function activate(container: HTMLElement, currentHtml: string): ReviewController {
    container.innerHTML = currentHtml;
    const controller = new ReviewController(container, 'doc-key');
    controller.activate({
      currentBody: '',
      baselineBody: '',
      documentKey: 'doc-key',
      renderBaseline: () => baselineHtml,
    });
    return controller;
  }

  test('shows the toolbar and the remaining count for a modified block', () => {
    const container = makeContainer('');
    const controller = activate(container, block('p', 'hello there', 1, 1));
    expect(container.querySelector('.review-toolbar')).toBeTruthy();
    expect(controller.getSummary()).toEqual({ total: 1, remaining: 1 });
    expect(container.querySelector('.review-count')?.textContent).toContain('1 change remaining');
  });

  test('marks a block as reviewed with the control', () => {
    const container = makeContainer('');
    const controller = activate(container, block('p', 'hello there', 1, 1));
    const check = container.querySelector<HTMLButtonElement>('.review-check');
    check?.click();
    expect(controller.getSummary().remaining).toBe(0);
    expect(container.querySelector('.review-item')?.classList.contains('is-reviewed')).toBe(true);
  });

  test('persists reviewed state across controllers', () => {
    const first = makeContainer('');
    const controller = activate(first, block('p', 'hello there', 1, 1));
    containerButton(first).click();
    expect(controller.getSummary().remaining).toBe(0);

    const second = makeContainer('');
    const reopened = activate(second, block('p', 'hello there', 1, 1));
    expect(reopened.getSummary().remaining).toBe(0);
    expect(second.querySelector('.review-item')?.classList.contains('is-reviewed')).toBe(true);
  });

  test('reopens a block after the text changes', () => {
    const first = makeContainer('');
    activate(first, block('p', 'hello there', 1, 1));
    containerButton(first).click();

    const second = makeContainer('');
    const reopened = activate(second, block('p', 'hello there friends', 1, 1));
    expect(reopened.getSummary().remaining).toBe(1);
  });

  test('mark all reviewed sets the remaining count to zero', () => {
    const container = makeContainer('');
    const controller = activate(container, block('p', 'hello there', 1, 1));
    controller.markAllReviewed();
    expect(controller.getSummary().remaining).toBe(0);
  });

  test('shows a before disclosure for a removed block', () => {
    const container = makeContainer('');
    container.innerHTML = block('p', 'kept', 1, 1);
    const controller = new ReviewController(container, 'doc-key');
    controller.activate({
      currentBody: '',
      baselineBody: '',
      documentKey: 'doc-key',
      renderBaseline: () => block('p', 'kept', 1, 1) + block('p', 'gone', 3, 3),
    });
    expect(controller.getSummary().total).toBe(1);
    expect(container.querySelector('.review-before')).toBeTruthy();
    expect(container.querySelector('.review-before')?.textContent).toContain('gone');
  });

  test('shows a before disclosure for a large rewrite', () => {
    const container = makeContainer('');
    container.innerHTML = block('p', 'one two three four', 1, 1);
    const controller = new ReviewController(container, 'doc-key');
    controller.activate({
      currentBody: '',
      baselineBody: '',
      documentKey: 'doc-key',
      renderBaseline: () => block('p', 'alpha beta gamma delta', 1, 1),
    });
    expect(container.querySelector('.review-before')).toBeTruthy();
    expect(container.querySelector('.review-word-added')).toBeNull();
  });

  test('next navigation moves to an unreviewed change', () => {
    const container = makeContainer('');
    container.innerHTML = block('p', 'a1', 1, 1) + block('p', 'b1', 3, 3);
    const controller = new ReviewController(container, 'doc-key');
    controller.activate({
      currentBody: '',
      baselineBody: '',
      documentKey: 'doc-key',
      renderBaseline: () => block('p', 'a0', 1, 1) + block('p', 'b0', 3, 3),
    });
    controller.focusNext();
    expect(Element.prototype.scrollIntoView).toHaveBeenCalledTimes(1);
  });
});

function containerButton(container: HTMLElement): HTMLButtonElement {
  const button = container.querySelector<HTMLButtonElement>('.review-check');
  if (!button) throw new Error('review check button not found');
  return button;
}

describe('clearReviewDom and stripReviewHtml', () => {
  test('clearReviewDom removes review elements and restores blocks', () => {
    const container = makeContainer('');
    container.innerHTML = block('p', 'hello there', 1, 1);
    const controller = new ReviewController(container, 'doc-key');
    controller.activate({
      currentBody: '',
      baselineBody: '',
      documentKey: 'doc-key',
      renderBaseline: () => block('p', 'hello world', 1, 1),
    });
    expect(container.querySelector('.review-toolbar')).toBeTruthy();

    clearReviewDom(container);
    expect(container.querySelector('.review-toolbar')).toBeNull();
    expect(container.querySelector('.review-item')).toBeNull();
    expect(container.querySelector('p')?.parentElement).toBe(container);
  });

  test('stripReviewHtml removes review elements from an HTML string', () => {
    const html = `<div class="review-toolbar">x</div><div class="review-item"><p>text</p><div class="review-footer">y</div></div>`;
    const stripped = stripReviewHtml(html);
    expect(stripped).not.toContain('review-toolbar');
    expect(stripped).not.toContain('review-item');
    expect(stripped).toContain('<p>text</p>');
  });
});
