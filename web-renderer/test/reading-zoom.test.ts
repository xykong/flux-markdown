import { requestReadingZoom, setReadingZoom } from '../src/reading-zoom';

describe('reading zoom scheduling and isolation', () => {
  beforeEach(() => {
    document.body.innerHTML = '<div id="markdown-preview"><p>Text</p></div><aside id="toc-container">Contents</aside>';
    document.documentElement.style.removeProperty('--zoom-scale');
    document.elementFromPoint = jest.fn(() => document.querySelector('p'));
    window.scrollBy = jest.fn();
  });

  test('coalesces a burst into the last requested scale, without changing chrome', () => {
    const frames: FrameRequestCallback[] = [];
    jest.spyOn(window, 'requestAnimationFrame').mockImplementation(callback => { frames.push(callback); return 1; });
    requestReadingZoom(1.2);
    requestReadingZoom(1.5);
    requestReadingZoom(2);
    expect(frames).toHaveLength(1);
    expect(document.documentElement.style.getPropertyValue('--zoom-scale')).toBe('');
    frames[0](0);
    expect(document.documentElement.style.getPropertyValue('--zoom-scale')).toBe('2');
    expect(document.getElementById('toc-container')!.getAttribute('style')).toBeNull();
    expect(window.scrollBy).toHaveBeenCalledTimes(1);
    jest.restoreAllMocks();
  });

  test('rejects nonfinite values and clamps finite values', () => {
    setReadingZoom(2);
    for (const invalid of [NaN, Infinity, -Infinity]) setReadingZoom(invalid);
    const root = document.getElementById('markdown-preview')!;
    expect(document.documentElement.style.getPropertyValue('--zoom-scale')).toBe('2');
    setReadingZoom(10);expect(document.documentElement.style.getPropertyValue('--zoom-scale')).toBe('3');
    setReadingZoom(-1);expect(document.documentElement.style.getPropertyValue('--zoom-scale')).toBe('0.5');
  });
});
