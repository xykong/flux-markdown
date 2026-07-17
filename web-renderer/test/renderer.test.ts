jest.mock('mermaid', () => ({
  initialize: jest.fn(),
  render: jest.fn().mockResolvedValue({ svg: '<svg>mocked diagram</svg>' }),
}));

// We import the index file to trigger the side-effect of setting window.renderMarkdown
import '../src/index';
import mermaid from 'mermaid'; // This will be the mocked version

describe('Markdown Renderer', () => {
  beforeEach(() => {
    // Setup the DOM element that index.ts expects
    document.body.innerHTML = '<div id="markdown-preview"></div>';
    jest.clearAllMocks();
  });

  test('should render mermaid diagram using mermaid.render API', async () => {
    const markdown = `
# Title
\`\`\`mermaid
graph TD;
    A-->B;
\`\`\`
    `;

    await window.renderMarkdown(markdown);

    const preview = document.getElementById('markdown-preview');
    expect(preview).toBeTruthy();
    
    const mermaidDiv = preview?.querySelector('.mermaid');
    expect(mermaidDiv).toBeTruthy();
    expect(mermaidDiv?.innerHTML).toContain('<svg>mocked diagram</svg>');
    
    expect(mermaid.render).toHaveBeenCalled();
  });

  test('should escape Gantt task label colons before rendering', async () => {
    const markdown = `
\`\`\`mermaid
gantt
    dateFormat X
    P3: “嘟嘟” PRD 自动生成器 : 90, 210
\`\`\`
    `;

    await window.renderMarkdown(markdown);

    const renderCall = (mermaid.render as jest.Mock).mock.calls[0];
    expect(renderCall[1]).toContain('P3#colon; “嘟嘟” PRD 自动生成器 : 90, 210');
  });

  test('should display error message when mermaid syntax is invalid', async () => {
    const mermaidMock = require('mermaid');
    mermaidMock.render.mockRejectedValueOnce(new Error('Parse error on line 1'));

    const markdown = `
\`\`\`mermaid
invalid syntax here
\`\`\`
    `;

    await window.renderMarkdown(markdown);

    const preview = document.getElementById('markdown-preview');
    const errorDiv = preview?.querySelector('.mermaid-error');
    expect(errorDiv).toBeTruthy();
    expect(errorDiv?.textContent).toContain('Mermaid Syntax Error');
    expect(errorDiv?.textContent).toContain('Parse error on line 1');
  });

  test('should resolve relative image paths to local-md:// scheme URLs', async () => {
    const markdown = '![img](./pic.png)';

    await window.renderMarkdown(markdown, { baseUrl: '/Users/me/docs' });

    const preview = document.getElementById('markdown-preview');
    const img = preview?.querySelector('img');
    expect(img).toBeTruthy();
    expect(img?.getAttribute('src')).toBe('local-md:///Users/me/docs/pic.png');
  });

  test('should prefer provided imageData data URLs over local-md URLs for relative images', async () => {
    const dataUrl = 'data:image/svg+xml;base64,PHN2Zy8+';
    const markdown = '![img](assets/pic.svg)';

    await window.renderMarkdown(markdown, {
      baseUrl: '/Users/me/docs',
      imageData: { 'assets/pic.svg': dataUrl },
      renderVersion: 42,
    });

    const preview = document.getElementById('markdown-preview');
    const img = preview?.querySelector('img');
    expect(img).toBeTruthy();
    expect(img?.getAttribute('src')).toBe(dataUrl);
  });

  test('should match dot-slash image references against normalized imageData keys', async () => {
    const dataUrl = 'data:image/png;base64,AAAA';
    const markdown = '![img](./assets/pic.png)';

    await window.renderMarkdown(markdown, {
      baseUrl: '/Users/me/docs',
      imageData: { 'assets/pic.png': dataUrl },
      renderVersion: 44,
    });

    const preview = document.getElementById('markdown-preview');
    const img = preview?.querySelector('img');
    expect(img?.getAttribute('src')).toBe(dataUrl);
  });

  test('should only replace image src from imageData and leave matching text unchanged', async () => {
    const dataUrl = 'data:image/png;base64,AAAA';
    const markdown = '![img](assets/pic.png)\n\n`assets/pic.png` stays visible';

    await window.renderMarkdown(markdown, {
      baseUrl: '/Users/me/docs',
      imageData: { 'assets/pic.png': dataUrl },
      renderVersion: 43,
    });

    const preview = document.getElementById('markdown-preview');
    const img = preview?.querySelector('img');
    expect(img?.getAttribute('src')).toBe(dataUrl);
    expect(preview?.querySelector('code')?.textContent).toBe('assets/pic.png');
  });

  test('should preserve embedded base64 images without modification', async () => {
    const base64Data = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    const markdown = `![Red Pixel](${base64Data})`;
    
    await window.renderMarkdown(markdown);

    const preview = document.getElementById('markdown-preview');
    const img = preview?.querySelector('img');
    expect(img).toBeTruthy();
    expect(img?.getAttribute('src')).toBe(base64Data);
    expect(img?.getAttribute('alt')).toBe('Red Pixel');
  });

  test('should preserve network image URLs without modification', async () => {
    const networkUrl = 'https://example.com/image.png';
    const markdown = `![Network Image](${networkUrl})`;
    
    await window.renderMarkdown(markdown);

    const preview = document.getElementById('markdown-preview');
    const img = preview?.querySelector('img');
    expect(img).toBeTruthy();
    expect(img?.getAttribute('src')).toBe(networkUrl);
  });

  test('should handle multiple image types in the same document', async () => {
    const base64Data = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    const networkUrl = 'https://example.com/image.png';

    const markdown = `
![Base64](${base64Data})
![Network](${networkUrl})
![Local](./local.jpg)
    `;

    await window.renderMarkdown(markdown, { baseUrl: '/Users/me/docs' });

    const preview = document.getElementById('markdown-preview');
    const images = preview?.querySelectorAll('img');

    expect(images?.length).toBe(3);
    expect(images?.[0].getAttribute('src')).toBe(base64Data);
    expect(images?.[1].getAttribute('src')).toBe(networkUrl);
    expect(images?.[2].getAttribute('src')).toBe('local-md:///Users/me/docs/local.jpg');
  });

  test('should append renderVersion as cache-busting query param to local-md:// image URLs', async () => {
    const markdown = '![img](./pic.png)';

    await window.renderMarkdown(markdown, { baseUrl: '/Users/me/docs', renderVersion: 42 });

    const preview = document.getElementById('markdown-preview');
    const img = preview?.querySelector('img');
    expect(img).toBeTruthy();
    expect(img?.getAttribute('src')).toBe('local-md:///Users/me/docs/pic.png?v=42');
  });

  test('should not append cache-busting param to network image URLs when renderVersion is set', async () => {
    const networkUrl = 'https://example.com/image.png';
    const markdown = `![Network](${networkUrl})`;

    await window.renderMarkdown(markdown, { renderVersion: 5 });

    const preview = document.getElementById('markdown-preview');
    const img = preview?.querySelector('img');
    expect(img).toBeTruthy();
    expect(img?.getAttribute('src')).toBe(networkUrl);
  });

  test('should not append cache-busting param to base64 images when renderVersion is set', async () => {
    const base64Data = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    const markdown = `![img](${base64Data})`;

    await window.renderMarkdown(markdown, { renderVersion: 5 });

    const preview = document.getElementById('markdown-preview');
    const img = preview?.querySelector('img');
    expect(img).toBeTruthy();
    expect(img?.getAttribute('src')).toBe(base64Data);
  });

  test('should update cache-busting param when renderVersion changes between renders', async () => {
    const markdown = '![img](./pic.png)';

    await window.renderMarkdown(markdown, { baseUrl: '/Users/me/docs', renderVersion: 1 });
    let preview = document.getElementById('markdown-preview');
    let img = preview?.querySelector('img');
    expect(img?.getAttribute('src')).toBe('local-md:///Users/me/docs/pic.png?v=1');

    await window.renderMarkdown(markdown, { baseUrl: '/Users/me/docs', renderVersion: 2 });
    preview = document.getElementById('markdown-preview');
    img = preview?.querySelector('img');
    expect(img?.getAttribute('src')).toBe('local-md:///Users/me/docs/pic.png?v=2');
  });

  test('should not append cache-busting param when renderVersion is not provided', async () => {
    const markdown = '![img](./pic.png)';

    await window.renderMarkdown(markdown, { baseUrl: '/Users/me/docs' });

    const preview = document.getElementById('markdown-preview');
    const img = preview?.querySelector('img');
    expect(img).toBeTruthy();
    // Without renderVersion, no ?v= param should be appended (backward compatible)
    expect(img?.getAttribute('src')).toBe('local-md:///Users/me/docs/pic.png');
  });
});
