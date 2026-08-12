import fs from 'fs';
import path from 'path';

describe('pinch-to-zoom ownership', () => {
  const rendererSource = fs.readFileSync(path.resolve(__dirname, '../src/index.ts'), 'utf8');

  test('renderer has no non-passive global wheel listener', () => {
    expect(rendererSource).not.toMatch(/addEventListener\(['"]wheel['"][\s\S]*?passive:\s*false/);
  });

  test('renderer does not forward wheel or gesture events to Swift zoom bridges', () => {
    expect(rendererSource).not.toContain('messageHandlers?.pinchZoom');
    expect(rendererSource).not.toContain('messageHandlers?.gestureZoom');
  });

  test('renderer does not register a global wheel listener', () => {
    expect(rendererSource).not.toMatch(/addEventListener\(['"]wheel['"]/);
  });
});
