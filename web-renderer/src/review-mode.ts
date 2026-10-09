import { diffArrays, diffWordsWithSpace } from 'diff';
import type { ChangeObject } from 'diff';

/**
 * Block-level document review mode.
 *
 * The module compares the rendered blocks of the current document to the
 * rendered blocks of a baseline document. It marks changed blocks, adds inline
 * word marks, records reviewed state, and shows a review toolbar.
 *
 * The module operates on the rendered DOM only. It does not change the
 * Markdown source. Links, bold text, headings, and tables stay intact.
 */

export type ReviewChangeType = 'added' | 'modified' | 'removed';

export interface ReviewBlock {
  el: HTMLElement;
  text: string;
}

export interface ReviewChange {
  id: string;
  type: ReviewChangeType;
  el?: HTMLElement;
  baselineEl?: HTMLElement;
  insertBefore?: HTMLElement | null;
  text: string;
}

export interface ReviewRenderContext {
  currentBody: string;
  baselineBody: string;
  documentKey: string;
  renderBaseline: (body: string) => string;
  log?: (message: string) => void;
}

export interface ReviewSummary {
  total: number;
  remaining: number;
}

interface TextNodeRange {
  node: Text;
  start: number;
  end: number;
}

interface InlineOperation {
  kind: 'add' | 'remove';
  start: number;
  end: number;
  text: string;
}

const LARGE_REWRITE_THRESHOLD = 0.4;
const STORE_PREFIX = 'flux-review:';

export function normalizeBlockText(text: string): string {
  return text.replace(/\s+/g, ' ').trim();
}

export function hashText(text: string): string {
  let hash = 5381;
  for (let i = 0; i < text.length; i++) {
    hash = ((hash << 5) + hash + text.charCodeAt(i)) | 0;
  }
  return (hash >>> 0).toString(36);
}

function blockChangeId(type: ReviewChangeType, text: string): string {
  return `${type}:${hashText(text)}`;
}

export function collectBlocks(root: HTMLElement): ReviewBlock[] {
  const blocks: ReviewBlock[] = [];
  for (const child of Array.from(root.children)) {
    const el = child as HTMLElement;
    if (!el.hasAttribute('data-source-line')) continue;
    blocks.push({ el, text: normalizeBlockText(el.textContent ?? '') });
  }
  return blocks;
}

/**
 * Compare the current blocks to the baseline blocks.
 * The function pairs a removed block and an added block as one modified block.
 */
export function computeBlockChanges(
  current: ReviewBlock[],
  baseline: ReviewBlock[]
): ReviewChange[] {
  const changes = diffArrays<string>(
    baseline.map((b) => b.text),
    current.map((c) => c.text)
  );
  const result: ReviewChange[] = [];
  let baseIdx = 0;
  let curIdx = 0;

  for (let i = 0; i < changes.length; i++) {
    const change: ChangeObject<string[]> = changes[i];
    const next = changes[i + 1];

    if (change.removed && next?.added) {
      const removed = change.value;
      const added = next.value;
      const pairCount = Math.min(removed.length, added.length);

      for (let j = 0; j < pairCount; j++) {
        const block = current[curIdx + j];
        result.push({
          id: blockChangeId('modified', block.text),
          type: 'modified',
          el: block.el,
          baselineEl: baseline[baseIdx + j].el,
          text: block.text,
        });
      }
      for (let j = pairCount; j < removed.length; j++) {
        const block = baseline[baseIdx + j];
        result.push({
          id: blockChangeId('removed', block.text),
          type: 'removed',
          baselineEl: block.el,
          insertBefore: current[curIdx + pairCount]?.el ?? null,
          text: block.text,
        });
      }
      for (let j = pairCount; j < added.length; j++) {
        const block = current[curIdx + j];
        result.push({
          id: blockChangeId('added', block.text),
          type: 'added',
          el: block.el,
          text: block.text,
        });
      }

      baseIdx += removed.length;
      curIdx += added.length;
      i++; // consume the added change
    } else if (change.removed) {
      for (const _value of change.value) {
        const block = baseline[baseIdx];
        result.push({
          id: blockChangeId('removed', block.text),
          type: 'removed',
          baselineEl: block.el,
          insertBefore: current[curIdx]?.el ?? null,
          text: block.text,
        });
        baseIdx++;
      }
    } else if (change.added) {
      for (const _value of change.value) {
        const block = current[curIdx];
        result.push({
          id: blockChangeId('added', block.text),
          type: 'added',
          el: block.el,
          text: block.text,
        });
        curIdx++;
      }
    } else {
      baseIdx += change.value.length;
      curIdx += change.value.length;
    }
  }

  return result;
}

/**
 * Similarity value in the range [0, 1]. A value near 1 means the two texts are
 * almost equal. A value near 0 means the two texts are almost different.
 */
export function computeSimilarity(previous: string, current: string): number {
  if (!previous && !current) return 1;
  if (!previous || !current) return 0;
  const parts = diffWordsWithSpace(previous, current);
  let commonLength = 0;
  for (const part of parts) {
    if (!part.added && !part.removed) commonLength += part.value.length;
  }
  const totalLength = previous.length + current.length;
  return totalLength === 0 ? 1 : (2 * commonLength) / totalLength;
}

function collectTextRanges(root: HTMLElement): { ranges: TextNodeRange[]; text: string } {
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  const ranges: TextNodeRange[] = [];
  let text = '';
  let node = walker.nextNode();
  while (node) {
    const textNode = node as Text;
    const value = textNode.nodeValue ?? '';
    ranges.push({ node: textNode, start: text.length, end: text.length + value.length });
    text += value;
    node = walker.nextNode();
  }
  return { ranges, text };
}

function findRangeAt(ranges: TextNodeRange[], position: number): TextNodeRange | null {
  for (const range of ranges) {
    if (position >= range.start && position < range.end) return range;
  }
  return ranges.length > 0 ? ranges[ranges.length - 1] : null;
}

function wrapTextRange(root: HTMLElement, start: number, end: number): void {
  const { ranges } = collectTextRanges(root);
  const overlapping = ranges.filter((r) => r.end > start && r.start < end);
  for (const range of overlapping) {
    const value = range.node.nodeValue ?? '';
    const localStart = Math.max(0, start - range.start);
    const localEnd = Math.min(value.length, end - range.start);
    if (localEnd <= localStart) continue;

    const parent = range.node.parentNode;
    if (!parent) continue;

    const middle = value.slice(localStart, localEnd);
    const before = value.slice(0, localStart);
    const after = value.slice(localEnd);

    const span = document.createElement('span');
    span.className = 'review-word-added';
    span.textContent = middle;

    if (after.length > 0) {
      parent.insertBefore(document.createTextNode(after), range.node.nextSibling);
    }
    parent.insertBefore(span, range.node.nextSibling);
    if (before.length > 0) {
      range.node.nodeValue = before;
    } else {
      parent.removeChild(range.node);
    }
  }
}

function insertRemovedText(root: HTMLElement, position: number, text: string): void {
  const { ranges } = collectTextRanges(root);
  const range = findRangeAt(ranges, position);
  if (!range) {
    root.appendChild(makeRemovedMark(text));
    return;
  }

  const value = range.node.nodeValue ?? '';
  const local = Math.max(0, Math.min(value.length, position - range.start));
  const parent = range.node.parentNode;
  if (!parent) return;

  const mark = makeRemovedMark(text);
  if (local === 0) {
    parent.insertBefore(mark, range.node);
    return;
  }
  if (local >= value.length) {
    parent.insertBefore(mark, range.node.nextSibling);
    return;
  }

  const after = value.slice(local);
  range.node.nodeValue = value.slice(0, local);
  parent.insertBefore(mark, range.node.nextSibling);
  parent.insertBefore(document.createTextNode(after), mark.nextSibling);
}

function makeRemovedMark(text: string): HTMLElement {
  const mark = document.createElement('del');
  mark.className = 'review-word-removed';
  mark.textContent = text;
  return mark;
}

/**
 * Mark inline word changes between the baseline text and the current block.
 * The function operates on text nodes only. Tags stay in place.
 */
export function markInlineDiff(blockEl: HTMLElement, baselineText: string): void {
  const { text: currentText } = collectTextRanges(blockEl);
  if (currentText.length === 0) return;

  const parts = diffWordsWithSpace(baselineText, currentText);
  const operations: InlineOperation[] = [];
  let cursor = 0;

  for (const part of parts) {
    if (part.removed) {
      operations.push({ kind: 'remove', start: cursor, end: cursor, text: part.value });
    } else if (part.added) {
      operations.push({ kind: 'add', start: cursor, end: cursor + part.value.length, text: part.value });
      cursor += part.value.length;
    } else {
      cursor += part.value.length;
    }
  }

  const additions = operations.filter((op) => op.kind === 'add').sort((a, b) => b.start - a.start);
  for (const op of additions) {
    wrapTextRange(blockEl, op.start, op.end);
  }

  const removals = operations.filter((op) => op.kind === 'remove').sort((a, b) => b.start - a.start);
  for (const op of removals) {
    insertRemovedText(blockEl, op.start, op.text);
  }
}

class ReviewStore {
  private readonly key: string;
  private readonly logger?: (message: string) => void;
  private readonly reviewed = new Set<string>();

  constructor(documentKey: string, logger?: (message: string) => void) {
    this.key = `${STORE_PREFIX}${documentKey}`;
    this.logger = logger;
    try {
      const raw = window.localStorage.getItem(this.key);
      if (raw) {
        const parsed: unknown = JSON.parse(raw);
        if (Array.isArray(parsed)) {
          for (const value of parsed) {
            if (typeof value === 'string') this.reviewed.add(value);
          }
        }
      }
    } catch (error) {
      this.logger?.(`ReviewStore: localStorage read failed: ${String(error)}`);
    }
  }

  has(id: string): boolean {
    return this.reviewed.has(id);
  }

  set(id: string, reviewed: boolean): void {
    if (reviewed) this.reviewed.add(id);
    else this.reviewed.delete(id);
    try {
      window.localStorage.setItem(this.key, JSON.stringify([...this.reviewed]));
    } catch (error) {
      this.logger?.(`ReviewStore: localStorage write failed: ${String(error)}`);
    }
  }

  clear(): void {
    this.reviewed.clear();
    try {
      window.localStorage.removeItem(this.key);
    } catch (error) {
      this.logger?.(`ReviewStore: localStorage clear failed: ${String(error)}`);
    }
  }
}

interface ReviewBridge {
  webkit?: {
    messageHandlers?: {
      reviewStatus?: { postMessage: (payload: ReviewSummary) => void };
    };
  };
}

export class ReviewController {
  private container: HTMLElement;
  private readonly log?: (message: string) => void;
  private store: ReviewStore;
  private changes: ReviewChange[] = [];
  private toolbar: HTMLElement | null = null;
  private countEl: HTMLElement | null = null;
  private navIndex = -1;
  private reviewed = new Map<string, boolean>();

  constructor(container: HTMLElement, documentKey: string, log?: (message: string) => void) {
    this.container = container;
    this.log = log;
    this.store = new ReviewStore(documentKey, log);
  }

  activate(context: ReviewRenderContext): ReviewSummary {
    this.clear(false);
    this.store = new ReviewStore(context.documentKey, this.log);

    const baselineRoot = document.createElement('div');
    baselineRoot.innerHTML = context.renderBaseline(context.baselineBody);

    const currentBlocks = collectBlocks(this.container);
    const baselineBlocks = collectBlocks(baselineRoot);
    this.changes = computeBlockChanges(currentBlocks, baselineBlocks);
    this.navIndex = -1;

    if (this.changes.length === 0) return { total: 0, remaining: 0 };

    this.buildToolbar();
    for (const change of this.changes) {
      this.renderChange(change);
    }
    this.updateSummary();
    return this.getSummary();
  }

  clear(removeStore = false): void {
    this.clearDom();
    this.changes = [];
    this.reviewed.clear();
    this.navIndex = -1;
    this.countEl = null;
    if (removeStore) this.store.clear();
  }

  getSummary(): ReviewSummary {
    let remaining = 0;
    for (const change of this.changes) {
      if (!this.isReviewed(change.id)) remaining++;
    }
    return { total: this.changes.length, remaining };
  }

  focusNext(): void {
    this.focusStep(1);
  }

  focusPrev(): void {
    this.focusStep(-1);
  }

  markAllReviewed(): void {
    for (const change of this.changes) {
      this.reviewed.set(change.id, true);
      this.store.set(change.id, true);
      this.applyReviewedClass(change, true);
    }
    this.updateSummary();
  }

  private getChangeElement(change: ReviewChange): HTMLElement | null {
    if (change.el) return change.el.closest<HTMLElement>('.review-item') ?? change.el;
    const marker = this.container.querySelector<HTMLElement>(`[data-review-id="${change.id}"]`);
    return marker;
  }

  private focusStep(direction: number): void {
    if (this.changes.length === 0) return;
    const count = this.changes.length;
    const start = this.navIndex;
    for (let step = 1; step <= count; step++) {
      const index = (((start + direction * step) % count) + count) % count;
      const change = this.changes[index];
      if (this.isReviewed(change.id)) continue;
      const target = this.getChangeElement(change);
      if (!target) continue;
      this.navIndex = index;
      target.scrollIntoView({ behavior: 'smooth', block: 'center' });
      return;
    }
  }

  private isReviewed(id: string): boolean {
    const cached = this.reviewed.get(id);
    if (cached !== undefined) return cached;
    const stored = this.store.has(id);
    this.reviewed.set(id, stored);
    return stored;
  }

  private setReviewed(change: ReviewChange, reviewed: boolean): void {
    this.reviewed.set(change.id, reviewed);
    this.store.set(change.id, reviewed);
    this.applyReviewedClass(change, reviewed);
    this.updateSummary();
  }

  private applyReviewedClass(change: ReviewChange, reviewed: boolean): void {
    const item = change.el?.closest<HTMLElement>('.review-item');
    if (item) item.classList.toggle('is-reviewed', reviewed);
    const marker = this.container.querySelector<HTMLElement>(`[data-review-id="${change.id}"]`);
    if (marker) marker.classList.toggle('is-reviewed', reviewed);
    const button = this.container.querySelector<HTMLButtonElement>(`button[data-review-control="${change.id}"]`);
    if (button) {
      button.setAttribute('aria-pressed', String(reviewed));
      button.textContent = reviewed ? '✓ Reviewed' : 'Mark reviewed';
    }
  }

  private buildToolbar(): void {
    const toolbar = document.createElement('div');
    toolbar.className = 'review-toolbar';
    toolbar.setAttribute('role', 'toolbar');

    this.countEl = document.createElement('span');
    this.countEl.className = 'review-count';

    toolbar.appendChild(this.countEl);
    toolbar.appendChild(this.makeToolbarButton('Previous', () => this.focusPrev()));
    toolbar.appendChild(this.makeToolbarButton('Next', () => this.focusNext()));
    toolbar.appendChild(this.makeToolbarButton('Mark all reviewed', () => this.markAllReviewed()));
    toolbar.appendChild(this.makeToolbarButton('Exit review', () => this.clearDom()));

    this.container.insertBefore(toolbar, this.container.firstChild);
    this.toolbar = toolbar;
  }

  private makeToolbarButton(label: string, onClick: () => void): HTMLButtonElement {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'review-toolbar-button';
    button.textContent = label;
    button.addEventListener('click', onClick);
    return button;
  }

  private renderChange(change: ReviewChange): void {
    if (change.type === 'removed') {
      this.renderRemoved(change);
      return;
    }

    const blockEl = change.el;
    if (!blockEl) return;

    if (change.type === 'modified' && change.baselineEl) {
      const previousText = change.baselineEl.textContent ?? '';
      const similarity = computeSimilarity(previousText, blockEl.textContent ?? '');
      if (similarity < LARGE_REWRITE_THRESHOLD) {
        this.insertBeforeDisclosure(change, blockEl, change.baselineEl);
      } else {
        markInlineDiff(blockEl, previousText);
      }
    }

    const item = document.createElement('div');
    item.className = `review-item review-${change.type}`;
    item.setAttribute('data-review-id', change.id);
    blockEl.parentNode?.insertBefore(item, blockEl);
    item.appendChild(blockEl);
    item.appendChild(this.makeFooter(change));
    this.applyReviewedClass(change, this.isReviewed(change.id));
  }

  private renderRemoved(change: ReviewChange): void {
    if (!change.baselineEl) return;
    const details = this.buildBeforeDetails(change.baselineEl, change.id);
    const anchor = change.insertBefore;
    if (anchor && anchor.parentNode) {
      anchor.parentNode.insertBefore(details, anchor);
    } else {
      this.container.appendChild(details);
    }
    this.applyReviewedClass(change, this.isReviewed(change.id));
  }

  private insertBeforeDisclosure(change: ReviewChange, blockEl: HTMLElement, baselineEl: HTMLElement): void {
    const details = this.buildBeforeDetails(baselineEl, change.id);
    blockEl.parentNode?.insertBefore(details, blockEl);
  }

  private buildBeforeDetails(baselineEl: HTMLElement, changeId: string): HTMLElement {
    const details = document.createElement('details');
    details.className = 'review-before';
    details.setAttribute('data-review-id', changeId);

    const summary = document.createElement('summary');
    summary.textContent = 'Before';

    const body = document.createElement('div');
    body.className = 'review-before-body';
    body.appendChild(baselineEl.cloneNode(true));

    details.appendChild(summary);
    details.appendChild(body);
    details.appendChild(this.makeFooterById(changeId));
    return details;
  }

  private makeFooter(change: ReviewChange): HTMLElement {
    return this.makeFooterById(change.id);
  }

  private makeFooterById(changeId: string): HTMLElement {
    const footer = document.createElement('div');
    footer.className = 'review-footer';

    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'review-check';
    button.setAttribute('data-review-control', changeId);
    const reviewed = this.isReviewed(changeId);
    button.setAttribute('aria-pressed', String(reviewed));
    button.textContent = reviewed ? '✓ Reviewed' : 'Mark reviewed';
    button.addEventListener('click', () => {
      const change = this.changes.find((c) => c.id === changeId);
      if (change) this.setReviewed(change, !this.isReviewed(changeId));
    });

    footer.appendChild(button);
    return footer;
  }

  private updateSummary(): void {
    const summary = this.getSummary();
    if (this.countEl) {
      const noun = summary.remaining === 1 ? 'change' : 'changes';
      this.countEl.textContent = `${summary.remaining} ${noun} remaining`;
    }
    const bridge = window as unknown as ReviewBridge;
    bridge.webkit?.messageHandlers?.reviewStatus?.postMessage(summary);
  }

  private clearDom(): void {
    clearReviewDom(this.container);
    this.toolbar = null;
    this.countEl = null;
  }
}

/** Remove all review annotations from the container. */
export function clearReviewDom(container: HTMLElement): void {
  container.querySelectorAll('.review-toolbar').forEach((el) => el.remove());
  container.querySelectorAll('.review-before').forEach((el) => el.remove());

  container.querySelectorAll<HTMLElement>('.review-item').forEach((item) => {
    const children = Array.from(item.childNodes);
    for (const child of children) {
      if (child instanceof HTMLElement && child.classList.contains('review-footer')) {
        item.removeChild(child);
      } else {
        item.parentNode?.insertBefore(child, item);
      }
    }
    item.remove();
  });

  container.querySelectorAll<HTMLElement>('.review-word-added').forEach((span) => {
    const text = document.createTextNode(span.textContent ?? '');
    span.parentNode?.replaceChild(text, span);
  });
  container.querySelectorAll('.review-word-removed').forEach((el) => el.remove());
  container.querySelectorAll<HTMLElement>('.is-reviewed').forEach((el) => el.classList.remove('is-reviewed'));
}

/** Remove review annotations from an HTML string. Used for export. */
export function stripReviewHtml(html: string): string {
  const holder = document.createElement('div');
  holder.innerHTML = html;
  clearReviewDom(holder);
  return holder.innerHTML;
}
