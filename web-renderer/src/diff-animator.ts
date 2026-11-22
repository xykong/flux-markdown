import { LineDiff, computeCharDiff } from './diff-engine';

function escapeHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function renderCharDiffHtml(oldText: string, newText: string): string {
  const parts = computeCharDiff(oldText, newText);
  return parts.map(p => {
    if (p.type === 'equal')   return escapeHtml(p.value);
    if (p.type === 'added')   return `<span class="diff-char-added">${escapeHtml(p.value)}</span>`;
    if (p.type === 'removed') return `<span class="diff-char-removed">${escapeHtml(p.value)}</span>`;
    return escapeHtml(p.value);
  }).join('');
}

function freezeBackgroundOnAnimationEnd(el: HTMLElement, color: string, animationCount: number): void {
  let fired = 0;
  const handler = () => {
    fired++;
    if (fired < animationCount) return;
    el.removeEventListener('animationend', handler);
    el.style.backgroundColor = color;
    el.style.animation = 'none';
  };
  el.addEventListener('animationend', handler);
}

export class DiffAnimator {
  buildSourceHTML(diffs: LineDiff[], theme: string): string {
    const themeClass = theme === 'dark' ? 'source-view-dark' : 'source-view-light';
    let gutterHtml = '';
    let contentHtml = '';
    let staggerIdx = 0;

    for (const diff of diffs) {
      const lineNum = diff.newLineNumber ?? diff.oldLineNumber ?? '';
      let gutterClass = 'source-diff-line-num';
      let contentClass = 'source-diff-line';
      let badge = '';
      let lineContent = '';
      let staggerStyle = '';

      switch (diff.type) {
        case 'added':
          gutterClass += ' diff-added diff-entering';
          contentClass += ' diff-entering';
          badge = `<span class="diff-gutter-badge">+</span>`;
          lineContent = escapeHtml(diff.newContent);
          staggerStyle = `style="animation-delay:${staggerIdx * 25}ms"`;
          staggerIdx++;
          break;

        case 'removed':
          gutterClass += ' diff-removed diff-exiting';
          contentClass += ' diff-exiting';
          badge = `<span class="diff-gutter-badge">\u2212</span>`;
          lineContent = `<span class="diff-char-removed">${escapeHtml(diff.oldContent)}</span>`;
          break;

        case 'modified':
          gutterClass += ' diff-modified diff-entering';
          contentClass += ' diff-entering';
          badge = `<span class="diff-gutter-badge">~</span>`;
          lineContent = renderCharDiffHtml(diff.oldContent, diff.newContent);
          staggerStyle = `style="animation-delay:${staggerIdx * 25}ms"`;
          staggerIdx++;
          break;

        case 'equal':
        default:
          lineContent = escapeHtml(diff.newContent ?? diff.oldContent ?? '');
          break;
      }

      gutterHtml  += `<span class="${gutterClass}" ${staggerStyle}>${lineNum}${badge}</span>`;
      contentHtml += `<span class="${contentClass}" ${diff.newLineNumber ? `data-source-line="${diff.newLineNumber}" data-source-line-end="${diff.newLineNumber}"` : ''} ${staggerStyle}>${lineContent || '\n'}</span>`;
    }

    return `<div class="source-diff-wrap ${themeClass}">` +
             `<div class="source-diff-gutter">${gutterHtml}</div>` +
             `<div class="source-diff-content">${contentHtml}</div>` +
           `</div>`;
  }

  attachSourceMarkListeners(container: HTMLElement): void {
    const addBg  = getComputedStyle(document.documentElement).getPropertyValue('--diff-add-bg').trim();
    const modBg  = getComputedStyle(document.documentElement).getPropertyValue('--diff-mod-bg').trim();
    for (const el of container.querySelectorAll<HTMLElement>('.source-diff-line.diff-entering')) {
      const color = el.classList.contains('diff-modified') ? modBg : addBg;
      // diff-entering fires 2 animations: diff-line-enter + diff-add-pulse
      freezeBackgroundOnAnimationEnd(el, color, 2);
    }
  }

  annotateRenderDOM(container: HTMLElement, diffs: LineDiff[]): void {
    const changedNewLines = new Map<number, 'added' | 'modified'>();

    const oldToNewLine = new Map<number, number>();
    const removedOldLines = new Set<number>();

    for (const d of diffs) {
      if (d.type === 'equal') {
        if (d.oldLineNumber !== null && d.newLineNumber !== null) {
          oldToNewLine.set(d.oldLineNumber, d.newLineNumber);
        }
        continue;
      }
      if (d.newLineNumber !== null) {
        const prev = changedNewLines.get(d.newLineNumber);
        if (!prev || prev === 'modified') {
          changedNewLines.set(d.newLineNumber, d.type === 'removed' ? 'modified' : d.type);
        }
      }
      if (d.type === 'removed' && d.oldLineNumber !== null) {
        removedOldLines.add(d.oldLineNumber);
      }
    }

    const newLinesWithDeletedAbove = new Set<number>();
    for (const oldLn of removedOldLines) {
      for (let probe = oldLn + 1; probe <= oldLn + 200; probe++) {
        const newLn = oldToNewLine.get(probe);
        if (newLn !== undefined) { newLinesWithDeletedAbove.add(newLn); break; }
        if (!removedOldLines.has(probe)) break;
      }
    }

    const rootStyle = getComputedStyle(document.documentElement);
    const addBg = rootStyle.getPropertyValue('--diff-add-bg').trim();
    const modBg = rootStyle.getPropertyValue('--diff-mod-bg').trim();

    const elements = container.querySelectorAll<HTMLElement>('[data-source-line]');
    let staggerIdx = 0;

    for (const el of elements) {
      const startAttr = el.getAttribute('data-source-line');
      if (!startAttr) continue;
      const startLine = parseInt(startAttr, 10);
      if (isNaN(startLine)) continue;

      const endAttr = el.getAttribute('data-source-line-end');
      // token.map[1] is the exclusive end line in markdown-it, stored as data-source-line-end.
      const endLine = endAttr ? parseInt(endAttr, 10) : startLine;

      let hasDeletedAbove = false;
      for (let ln = startLine; ln <= endLine; ln++) {
        if (newLinesWithDeletedAbove.has(ln)) { hasDeletedAbove = true; break; }
      }
      if (hasDeletedAbove) {
        const marker = document.createElement('div');
        marker.className = 'render-diff-deleted-marker';
        el.parentNode?.insertBefore(marker, el);
      }

      let blockType: 'added' | 'modified' | null = null;
      for (let ln = startLine; ln <= endLine; ln++) {
        const t = changedNewLines.get(ln);
        if (t === 'added') { blockType = 'added'; break; }
        if (t === 'modified') blockType = 'modified';
      }

      if (!blockType) continue;

      if (blockType === 'added') {
        el.classList.add('render-diff-block-enter');
        el.style.animationDelay = `${staggerIdx * 30}ms`;
        staggerIdx++;
        // render-diff-block-enter fires 2 animations: diff-line-enter + diff-add-pulse
        freezeBackgroundOnAnimationEnd(el, addBg, 2);
      } else {
        el.classList.add('render-diff-block-modified');
        freezeBackgroundOnAnimationEnd(el, modBg, 1);
      }
    }
  }
}
