import { diffLines, diffChars, Change } from 'diff';

export type DiffType = 'equal' | 'added' | 'removed' | 'modified';

export interface LineDiff {
  type: DiffType;
  oldLineNumber: number | null;  // 1-based, null for pure added
  newLineNumber: number | null;  // 1-based, null for pure removed
  oldContent: string;            // empty string for added lines
  newContent: string;            // empty string for removed lines
}

export interface CharDiff {
  type: 'equal' | 'added' | 'removed';
  value: string;
}

/**
 * Compute line-level diff between old and new Markdown text.
 * When oldText is empty, returns all lines as 'equal' (first render, no animation).
 */
export function computeLineDiff(oldText: string, newText: string, { sourceView = false } = {}): LineDiff[] {
  if (sourceView) {
    // Match WebKit’s line endings before the HTML parser can insert a newline inside a row.
    oldText = oldText.replace(/\r\n?/g, '\n');
    newText = newText.replace(/\r\n?/g, '\n');
  }
  // First render: no animation
  if (!oldText) {
    return newText.split('\n').map((line, i) => ({
      type: 'equal' as DiffType,
      oldLineNumber: i + 1,
      newLineNumber: i + 1,
      oldContent: line,
      newContent: line,
    }));
  }

  // Ensure trailing newlines so diffLines treats each line independently
  const normalizedOld = oldText.endsWith('\n') ? oldText : oldText + '\n';
  const normalizedNew = newText.endsWith('\n') ? newText : newText + '\n';
  const changes: Change[] = diffLines(normalizedOld, normalizedNew);
  const result: LineDiff[] = [];
  let oldLine = 1;
  let newLine = 1;

  for (let i = 0; i < changes.length; i++) {
    const change = changes[i];
    const next = changes[i + 1];

    if (change.removed && next?.added) {
      // Pair removed+added as modified lines
      const oldLines = change.value.replace(/\n$/, '').split('\n');
      const newLines = next.value.replace(/\n$/, '').split('\n');
      const minLen = Math.min(oldLines.length, newLines.length);

      for (let j = 0; j < minLen; j++) {
        result.push({
          type: 'modified',
          oldLineNumber: oldLine++,
          newLineNumber: newLine++,
          oldContent: oldLines[j],
          newContent: newLines[j],
        });
      }
      for (let j = minLen; j < oldLines.length; j++) {
        result.push({
          type: 'removed',
          oldLineNumber: oldLine++,
          newLineNumber: null,
          oldContent: oldLines[j],
          newContent: '',
        });
      }
      for (let j = minLen; j < newLines.length; j++) {
        result.push({
          type: 'added',
          oldLineNumber: null,
          newLineNumber: newLine++,
          oldContent: '',
          newContent: newLines[j],
        });
      }
      i++; // skip next (already consumed)
    } else if (change.removed) {
      const lines = change.value.replace(/\n$/, '').split('\n');
      for (const line of lines) {
        result.push({
          type: 'removed',
          oldLineNumber: oldLine++,
          newLineNumber: null,
          oldContent: line,
          newContent: '',
        });
      }
    } else if (change.added) {
      const lines = change.value.replace(/\n$/, '').split('\n');
      for (const line of lines) {
        result.push({
          type: 'added',
          oldLineNumber: null,
          newLineNumber: newLine++,
          oldContent: '',
          newContent: line,
        });
      }
    } else {
      // equal
      const lines = change.value.replace(/\n$/, '').split('\n');
      for (const line of lines) {
        result.push({
          type: 'equal',
          oldLineNumber: oldLine++,
          newLineNumber: newLine++,
          oldContent: line,
          newContent: line,
        });
      }
    }
  }

  // diffLines treats a final newline as a delimiter. The source view represents
  // the empty row after it, just as its first render does.
  if (sourceView && newText.endsWith('\n')) {
    result.push({
      type: 'equal',
      oldLineNumber: oldText.endsWith('\n') ? oldLine : null,
      newLineNumber: newLine,
      oldContent: '',
      newContent: '',
    });
  }

  return result;
}

/**
 * Character-level diff for a single modified line.
 */
export function computeCharDiff(oldText: string, newText: string): CharDiff[] {
  const changes: Change[] = diffChars(oldText, newText);
  return changes.map(c => ({
    type: c.added ? 'added' : c.removed ? 'removed' : 'equal',
    value: c.value,
  }));
}
