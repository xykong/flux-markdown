module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'jest-environment-jsdom',
  moduleNameMapper: {
    '^#default-font/(.*)$': '<rootDir>/node_modules/@mathjax/mathjax-newcm-font/cjs/$1',
    '^@mathjax/src/mjs/(.*)$': '<rootDir>/node_modules/@mathjax/src/cjs/$1',
    '(?:\\.(?:wasm|otf)|/wasm)\\?url$': '<rootDir>/test/assetMock.js',
    '\\.(css|less|scss|sass)$': '<rootDir>/test/styleMock.js',
    '^markdown-it$': '<rootDir>/node_modules/markdown-it/dist/markdown-it.js',
    '^markdown-it-github-alerts$': '<rootDir>/test/__mocks__/markdown-it-github-alerts.js',
    '^vega$': '<rootDir>/test/__mocks__/vega.js',
    '^vega-lite$': '<rootDir>/test/__mocks__/vega-lite.js',
    '^@hpcc-js/wasm-graphviz$': '<rootDir>/test/__mocks__/@hpcc-js/wasm-graphviz.js'
  },
  transformIgnorePatterns: [
    'node_modules/(?!tex2typst)'
  ],
  transform: {
    '^.+\\.tsx?$': ['ts-jest', {
      tsconfig: { module: 'commonjs', moduleResolution: 'node', baseUrl: '.', paths: {
        '@mathjax/src/js/*': ['node_modules/@mathjax/src/cjs/*'],
        '@mathjax/mathjax-newcm-font/js/*': ['node_modules/@mathjax/mathjax-newcm-font/cjs/*']
      } }
    }],
    'node_modules/tex2typst/.+\\.js$': ['ts-jest', {
      tsconfig: { module: 'commonjs', moduleResolution: 'node' }
    }]
  }
};
