import { diffArrays } from 'diff';
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

const DIAGRAM_BLOCK = /language-(?:mermaid|vega|vega-lite|dot|graphviz)\b/;

export function collectBlocks(root: HTMLElement): ReviewBlock[] {
  const blocks: ReviewBlock[] = [];
  for (const child of Array.from(root.children)) {
    const el = child as HTMLElement;
    if (!el.hasAttribute('data-source-line')) continue;
    // A diagram is a code fence in the baseline but a rendered container in the
    // live DOM. Skip it on both sides, or every diagram reads as a removed block.
    if (
      el.classList.contains('mermaid') ||
      el.classList.contains('vega-diagram') ||
      el.classList.contains('graphviz-diagram')
    ) {
      continue;
    }
    if (DIAGRAM_BLOCK.test(el.innerHTML)) continue;
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

// ─── Inline HTML word diff ───────────────────────────────────────────────
//
// This runs on the rendered HTML of the two block versions, not on the
// Markdown source. Marking the source would break the syntax the marks land
// in. An HTML token stream is safe to diff as long as a tag never splits from
// its partner.
//
// Tokens are "optional whitespace + one tag or one word". Matching ignores
// whitespace, so a reflowed paragraph is not one big change. Output uses the
// token verbatim, so spacing survives.

const BLOCK_TAG =
  /^<\/?(?:address|article|aside|blockquote|dd|details|div|dl|dt|figcaption|figure|footer|h[1-6]|header|hr|li|main|nav|ol|p|pre|section|summary|table|tbody|td|tfoot|th|thead|tr|ul)\b/i;

// Adjacent changes separated by at most this many unchanged words are merged,
// so a rewritten sentence reads as one phrase rather than a row of confetti.
const BRIDGE_WORDS = 3;
// Past these, the paragraph has been rewritten rather than edited, and an
// inline diff is less readable than simply showing the two versions.
const MIN_SIMILARITY = 0.4;
const MAX_GROUPS = 12;
const MAX_HTML = 200_000;

const VOID_TAGS = new Set([
  'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
  'link', 'meta', 'param', 'source', 'track', 'wbr',
]);

type InlineOp = 'eq' | 'add' | 'del';

interface InlineGroup {
  t: InlineOp;
  tokens: string[];
}

function tokenizeHtml(html: string): string[] {
  return html.match(/\s*(?:<[^>]+>|[^<\s]+)/g) ?? [];
}

function normalizeToken(token: string): string {
  return token.replace(/\s+/g, ' ').trim();
}

function isTagToken(token: string): boolean {
  return token.trimStart().startsWith('<');
}

function isBlockToken(token: string): boolean {
  return BLOCK_TAG.test(token.trimStart());
}

function isWordToken(token: string): boolean {
  return !isTagToken(token) && normalizeToken(token) !== '';
}

/**
 * Indices of tags whose partner lies outside `tokens`. A mark may not span one
 * of these, or it would interleave with an element it does not contain —
 * `<strong><ins>x</strong>y</ins>` and friends.
 */
function findUnpairedTags(tokens: string[]): Set<number> {
  const open: { name: string; index: number }[] = [];
  const loose = new Set<number>();
  tokens.forEach((token, index) => {
    if (!isTagToken(token)) return;
    const match = /^<(\/?)([a-zA-Z][\w-]*)/.exec(token.trimStart());
    if (!match) return; // comment or doctype: harmless
    const closing = match[1];
    const name = match[2];
    if (VOID_TAGS.has(name.toLowerCase()) || token.trimEnd().endsWith('/>')) return;
    if (!closing) {
      open.push({ name, index });
    } else if (open.length > 0 && open[open.length - 1].name === name) {
      open.pop();
    } else {
      loose.add(index); // closes something opened before this run
    }
  });
  for (const entry of open) loose.add(entry.index); // closed after this run
  return loose;
}

/** Wrap `body` without swallowing the whitespace that positions it. */
function markTokens(tag: string, className: string, value: string): string {
  const leadMatch = value.match(/^\s*/);
  const lead = leadMatch ? leadMatch[0] : '';
  const body = value.slice(lead.length);
  return body ? `${lead}<${tag} class="${className}">${body}</${tag}>` : value;
}

/**
 * Deleted text only: the old version's tags are dropped so nothing unbalances,
 * but the whitespace in front of them is kept — it is what separates words.
 */
function emitRemoved(tokens: string[]): string {
  const text = tokens
    .map((token) => (isTagToken(token) ? (token.match(/^\s*/)?.[0] ?? '') : token))
    .join('');
  return markTokens('del', 'review-word-removed', text);
}

/** Added tokens keep the new version's structure; marks stop at tags they do not own. */
function emitAdded(tokens: string[]): string {
  const loose = findUnpairedTags(tokens);
  let out = '';
  let buffer: string[] = [];
  const flush = () => {
    if (buffer.length) out += markTokens('span', 'review-word-added', buffer.join(''));
    buffer = [];
  };
  tokens.forEach((token, index) => {
    if (isBlockToken(token) || loose.has(index)) {
      flush();
      out += token;
    } else {
      buffer.push(token);
    }
  });
  flush();
  return out;
}

/** Duplicate short unchanged runs into both sides so changes read as phrases. */
function bridgeGroups(groups: InlineGroup[]): InlineGroup[] {
  const out: InlineGroup[] = [];
  for (let i = 0; i < groups.length; i++) {
    const group = groups[i];
    const prev = out[out.length - 1];
    const next = groups[i + 1];
    const short = group.tokens.filter(isWordToken).length <= BRIDGE_WORDS;
    if (
      group.t === 'eq' &&
      short &&
      prev !== undefined &&
      prev.t !== 'eq' &&
      next !== undefined &&
      next.t !== 'eq' &&
      !group.tokens.some(isBlockToken)
    ) {
      out.push({ t: 'del', tokens: group.tokens }, { t: 'add', tokens: group.tokens });
    } else {
      out.push(group);
    }
  }
  return out;
}

/**
 * Mark up `newHtml` with what changed relative to `oldHtml`.
 * Returns the annotated HTML, or null when a word diff would not help.
 */
export function inlineDiff(oldHtml: string, newHtml: string): string | null {
  // Diagrams are one opaque node (or thousands of SVG elements); a word diff
  // of either is meaningless.
  if (oldHtml.length + newHtml.length > MAX_HTML) return null;
  if (/<svg|class="mermaid"/.test(oldHtml) || /<svg|class="mermaid"/.test(newHtml)) return null;

  const before = tokenizeHtml(oldHtml);
  const after = tokenizeHtml(newHtml);
  if (!before.length || !after.length) return null;

  const parts = diffArrays(before, after, {
    comparator: (a, b) => normalizeToken(a) === normalizeToken(b),
  });

  let same = 0;
  let added = 0;
  let removed = 0;
  let groups = 0;
  let inGroup = false;
  for (const part of parts) {
    const wordCount = part.value.filter(isWordToken).length;
    if (part.added) added += wordCount;
    else if (part.removed) removed += wordCount;
    else same += wordCount;

    const changed = Boolean(part.added || part.removed);
    if (changed && !inGroup) groups++;
    inGroup = changed;
  }

  if (!added && !removed) return null; // only tags moved — not worth marking
  if (groups > MAX_GROUPS) return null;
  if (same / (same + Math.max(added, removed)) < MIN_SIMILARITY) return null;
  // A removal that spans structure (a whole list item, a table row) has no
  // valid place to sit inline. Show the two versions instead.
  if (parts.some((part) => part.removed && part.value.some(isBlockToken))) return null;

  const ops = bridgeGroups(
    parts.map((part) => ({
      t: (part.added ? 'add' : part.removed ? 'del' : 'eq') as InlineOp,
      tokens: part.value,
    }))
  );

  let html = '';
  for (let i = 0; i < ops.length; ) {
    if (ops[i].t === 'eq') {
      html += ops[i].tokens.join('');
      i++;
      continue;
    }
    // Collect the whole run of changes, then show old text before new.
    const deleted: string[] = [];
    const inserted: string[] = [];
    for (; i < ops.length && ops[i].t !== 'eq'; i++) {
      if (ops[i].t === 'del') deleted.push(...ops[i].tokens);
      else inserted.push(...ops[i].tokens);
    }
    // Any block tags the addition opens with come first, so the deleted text
    // lands inside the new element rather than in front of it.
    let lead = 0;
    while (lead < inserted.length && isBlockToken(inserted[lead])) lead++;
    html += inserted.slice(0, lead).join('') + emitRemoved(deleted) + emitAdded(inserted.slice(lead));
  }
  return html;
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
      button.textContent = reviewed ? 'Reviewed' : 'Mark reviewed';
      button.title = reviewed ? 'Reviewed' : 'Mark reviewed';
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
      const annotated = inlineDiff(change.baselineEl.innerHTML, blockEl.innerHTML);
      if (annotated === null) {
        this.insertBeforeDisclosure(change, blockEl, change.baselineEl);
      } else {
        blockEl.innerHTML = annotated;
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
    button.textContent = reviewed ? 'Reviewed' : 'Mark reviewed';
    button.title = reviewed ? 'Reviewed' : 'Mark reviewed';
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
