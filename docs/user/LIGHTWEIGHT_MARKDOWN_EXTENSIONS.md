# Definition lists, abbreviations and inserted text

These additions are currently in development builds, not the public v1.44.761.
They render in the app, full Quick Look and Finder preview, and remain in HTML/PDF
output. Source view retains the original Markdown.

## Definition lists

```markdown
Markdown
: A lightweight markup language.
: Another definition of the same term.

Preview
: A rendered view of a document.

  A second paragraph within the definition.
```

The output uses semantic `dl`, `dt` and `dd` elements. This follows the upstream
[markdown-it-deflist](https://github.com/markdown-it/markdown-it-deflist) dialect;
it is not a promise of identical handling of every Pandoc edge case.

## Abbreviations

```markdown
HTML and CSS are used for web pages.

*[HTML]: HyperText Markup Language
*[CSS]: Cascading Style Sheets
```

Matching words become `abbr` elements with a plain-text title. Hovering can show
the browser's tooltip. Definitions apply only to the current document; they do
not leak into the next document. Definitions are single-line, and code remains
literal. PDF preserves the visible abbreviation; a hover tooltip is not a printed
expansion of the abbreviation.

## Inserted text

```markdown
This is ++inserted text++ and ++**inserted bold text**++.
```

Insertion is represented with `ins`. Inline code and fenced code keep `++` as
literal text. This syntax does not implement keyboard-key notation or the complete
CriticMarkup dialect, even when those dialects use similar delimiters.

This batch addresses three non-math examples from issue #64. Containers, attributes,
body TOC placeholders, Wiki links, bibliography/citation systems and additional
diagram engines remain separate requests.
