# Third-Party Licenses

This project incorporates code and concepts from the following third-party projects.

## MathJax and New Computer Modern glyph data

The mathematical renderer bundles `@mathjax/src` 4.1.3 and
`@mathjax/mathjax-newcm-font` 4.1.3 from the locked npm packages.
Runtime source attribution is Copyright (c) 2017–2026 The MathJax Consortium,
under Apache-2.0. The glyph package declares Apache-2.0 for its packaging/code;
its font metadata also retains the GUST Font License and the MathJax, Inc. /
Antonis Tsolomitis attribution for the underlying font.

The distributed renderer includes the following source-preserved notices:

- `licenses/MathJax-Apache-2.0.txt`
- `licenses/MathJax-NOTICE.txt`
- `licenses/NewComputerModern.txt`

Sources: the installed runtime's `LICENSE` and `ts/mathjax.ts`, the glyph
package's `package.json`, and the copyright name table of its
`chtml/woff2/mjx-ncm-n.woff2`. MathJax's official font documentation identifies
the default NewCM family: <https://docs.mathjax.org/en/latest/output/fonts.html>.

## markdown-preview-enhanced

This project is inspired by and uses portions of [markdown-preview-enhanced](https://github.com/shd101wyy/markdown-preview-enhanced).

**License: University of Illinois/NCSA Open Source License**

Copyright (c) 2017 Yiyi Wang

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal with the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimers.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimers in the documentation and/or other materials provided with the distribution.

* Neither the names of <Name of Development Group, Name of Institution>, nor the names of its contributors may be used to endorse or promote products derived from this Software without specific prior written permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS WITH THE SOFTWARE.
