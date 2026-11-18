import { ReadingStatus, headingPath, scrollProgress } from '../src/reading-status';

test('hierarchy respects skipped levels and sibling boundaries', () => {
    document.body.innerHTML = '<h1>A</h1><h3>B</h3><h4>C</h4><h2>D</h2>';
    const headings = Array.from(document.querySelectorAll<HTMLElement>('h1,h2,h3,h4'));
    expect(headingPath(headings, headings[2])).toEqual(['A', 'B', 'C']);
    expect(headingPath(headings, headings[3])).toEqual(['A', 'D']);
});
test('position hides short documents and clamps overscroll', () => {
    expect(scrollProgress(0, 500, 500)).toBeNull();
    expect(scrollProgress(-20, 1500, 500)).toBe(0);
    expect(scrollProgress(420, 1500, 500)).toBe(42);
    expect(scrollProgress(1200, 1500, 500)).toBe(100);
});
test('status uses safe text, tracks heading and clears source mode and timers', () => {
    jest.useFakeTimers();
    document.documentElement.dataset.context = 'app';
    document.body.innerHTML = '<div id="reading-status"></div><div id="markdown-preview"><h1 id="a">Root</h1><h2 id="b">Child</h2></div>';
    const status = new ReadingStatus(document.getElementById('reading-status')!);
    status.render('text', undefined, 'old');
    document.dispatchEvent(new CustomEvent('reading-heading', { detail: 'b' }));
    expect(document.querySelector('.reading-current')?.textContent).toBe('Child');
    expect(document.querySelector('.reading-path')?.getAttribute('title')).toBe('Root › Child');
    expect(document.querySelector('.reading-updated')?.textContent).toBe('Document updated');
    jest.advanceTimersByTime(4000);
    expect((document.querySelector('.reading-updated') as HTMLElement).hidden).toBe(true);
    document.getElementById('markdown-preview')!.classList.add('source-mode');
    status.render('source');
    expect(document.getElementById('reading-status')!.hidden).toBe(true);
    status.dispose(); jest.useRealTimers();
});

test('theme rerenders do not replay an old update notice; filename stays text-only', () => {
    jest.useFakeTimers();
    document.documentElement.dataset.context = 'quicklook';
    document.body.innerHTML = '<div id="reading-status"></div><div id="markdown-preview"></div>';
    const status = new ReadingStatus(document.getElementById('reading-status')!);
    status.render('new', '<img src=x>.md', 'old');
    expect(document.querySelector('.reading-filename')?.textContent).toBe('<img src=x>.md');
    expect(document.querySelector('img')).toBeNull();
    jest.advanceTimersByTime(4000);
    status.render('new', '<img src=x>.md', 'old');
    expect((document.querySelector('.reading-updated') as HTMLElement).hidden).toBe(true);
    status.dispose(); jest.useRealTimers();
});
test('a paused Follow keeps showing that the document changed until it updates again', () => {
    jest.useFakeTimers();
    document.documentElement.dataset.context = 'quicklook';
    document.body.innerHTML = '<div id="reading-status"></div><div id="markdown-preview"><h1 id="a">Root</h1></div>';
    const status = new ReadingStatus(document.getElementById('reading-status')!);
    status.render('text', 'notes.md');
    const updated = document.querySelector('.reading-updated') as HTMLElement;
    expect(updated.hidden).toBe(true);
    status.waiting(true);
    expect(updated.hidden).toBe(false);
    expect(updated.textContent).toBe('Document updated');
    expect(updated.dataset.waiting).toBe('');
    expect((document.querySelector('.reading-progress') as HTMLElement).hidden).toBe(true);
    jest.advanceTimersByTime(10000);
    expect(updated.hidden).toBe(false);
    status.render('text\nmore', 'notes.md');
    expect(updated.hidden).toBe(true);
    expect(updated.dataset.waiting).toBeUndefined();
    status.waiting(true); status.waiting(false);
    expect(updated.hidden).toBe(true);
    status.dispose(); jest.useRealTimers();
});
