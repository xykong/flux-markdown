import { defineConfig } from 'vite';
import path from 'path';

export default defineConfig({
  base: './',
  plugins: [{
    name: 'webkit-bundle-attributes',
    transformIndexHtml: { order: 'post', handler: (html) => html.replace(/\s+crossorigin(?:="[^"]*")?/g, '') },
  }],
  build: {
    manifest: true,
    target: 'safari14',
    outDir: 'dist',
    assetsDir: 'assets',
    sourcemap: false,
    emptyOutDir: true,
    rollupOptions: {
      input: {
        main: path.resolve(__dirname, 'index.html'),
      },
      output: {
        manualChunks: {
          // The preload helper must not pull a renderer dependency ahead of
          // the compatibility bootstrap. Keep this chunk dependency-free.
          'renderer-compat': [path.resolve(__dirname, 'src/math-compat.ts'), '\0vite/preload-helper.js'],
          mermaid: ['mermaid'],
          'typst-wasm': [
            '@myriaddreamin/typst.ts',
            '@myriaddreamin/typst-ts-web-compiler',
            '@myriaddreamin/typst-ts-renderer',
          ],
        },
      },
    },
    chunkSizeWarningLimit: 2000,
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src'),
    },
  },
  assetsInclude: ['**/*.wasm'],
  define: {
    'process.env': {},
  },
});
