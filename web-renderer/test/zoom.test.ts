jest.mock('mermaid', () => ({
  initialize: jest.fn(),
  render: jest.fn().mockResolvedValue({ svg: '<svg>mocked</svg>' }),
}));

import '../src/index';

beforeAll(() => {
  document.elementFromPoint = jest.fn(() => document.getElementById('markdown-preview'));
  window.scrollBy = jest.fn();
});

describe('window.setZoomLevel', () => {
  beforeEach(() => {
    document.body.innerHTML = `
      <div id="markdown-preview">
        <p>Some text content</p>
      </div>
    `;
  });

  test('zoom level 1.0 does not apply transform scale (no layout distortion)', () => {
    window.setZoomLevel(1.0);
    const outputDiv = document.getElementById('markdown-preview');
    expect(outputDiv?.style.transform).toBeFalsy();
  });

  test('zoom level 2.0 does not set transform: scale(2)', () => {
    window.setZoomLevel(2.0);
    const outputDiv = document.getElementById('markdown-preview');
    expect(outputDiv?.style.transform).not.toContain('scale(2)');
  });

  test('setZoomLevel clamps to maximum 3.0 — no crash', () => {
    expect(() => window.setZoomLevel(5.0)).not.toThrow();
  });

  test('setZoomLevel clamps to minimum 0.5 — no crash', () => {
    expect(() => window.setZoomLevel(0.1)).not.toThrow();
  });

  test('setZoomLevel(1.0) resets to default state — no transform', () => {
    window.setZoomLevel(2.0);
    window.setZoomLevel(1.0);
    const outputDiv = document.getElementById('markdown-preview');
    expect(outputDiv?.style.transform).toBeFalsy();
  });
});

describe('zoom does not break DOM content', () => {
  beforeEach(() => {
    document.body.innerHTML = '<div id="markdown-preview"></div>';
  });

  test('renderMarkdown content is preserved after setZoomLevel', async () => {
    await window.renderMarkdown('# Hello Zoom\n\nContent paragraph.');
    window.setZoomLevel(1.5);
    const h1 = document.querySelector('h1');
    expect(h1?.textContent).toBe('Hello Zoom');
  });

  test('multiple zoom changes do not lose content', async () => {
    await window.renderMarkdown('# Stable');
    window.setZoomLevel(2.0);
    window.setZoomLevel(0.8);
    window.setZoomLevel(1.0);
    expect(document.querySelector('h1')?.textContent).toBe('Stable');
  });
});

describe('zoom edge cases', () => {
  beforeEach(() => {
    document.body.innerHTML = '<div id="markdown-preview"></div>';
    document.documentElement.style.removeProperty('--zoom-scale');
  });

  test('setZoomLevel(1.0) removes --zoom-scale CSS variable', () => {
    window.setZoomLevel(2.0);
    window.setZoomLevel(1.0);
    const val = document.documentElement.style.getPropertyValue('--zoom-scale');
    expect(val).toBeFalsy();
  });

  test('setZoomLevel(2.0) sets --zoom-scale to "2"', () => {
    window.setZoomLevel(2.0);
    const val = document.documentElement.style.getPropertyValue('--zoom-scale');
    expect(val).toBe('2');
  });

  test('setZoomLevel(0.8) sets --zoom-scale to "0.8"', () => {
    window.setZoomLevel(0.8);
    const val = document.documentElement.style.getPropertyValue('--zoom-scale');
    expect(val).toBe('0.8');
  });

  test('extreme zoom 100x is clamped — --zoom-scale is "3"', () => {
    window.setZoomLevel(100);
    const val = document.documentElement.style.getPropertyValue('--zoom-scale');
    expect(val).toBe('3');
  });

  test('extreme zoom 0.001x is clamped — --zoom-scale is "0.5"', () => {
    window.setZoomLevel(0.001);
    const val = document.documentElement.style.getPropertyValue('--zoom-scale');
    expect(val).toBe('0.5');
  });

  test('zoom does not affect data-theme attribute', () => {
    document.documentElement.setAttribute('data-theme', 'dark');
    window.setZoomLevel(2.0);
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark');
  });
});
