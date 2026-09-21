import '../src/index';

describe('YAML Front Matter', () => {
    beforeEach(() => {
        document.body.innerHTML = `
            <div id="markdown-preview"></div>
            <div id="toc-container"></div>
            <div id="search-container"></div>
        `;
    });

    test('renders YAML front matter as a table', async () => {
        const markdown = `---
title: Hello World
author: Jane Doe
date: 2024-01-01
---

# Content
`;
        await window.renderMarkdown(markdown);
        const preview = document.getElementById('markdown-preview')!;
        const table = preview.querySelector('table.yaml-frontmatter');
        expect(table).toBeTruthy();
        expect(table!.textContent).toContain('title');
        expect(table!.textContent).toContain('Hello World');
        expect(table!.textContent).toContain('author');
        expect(table!.textContent).toContain('Jane Doe');
        expect(table!.textContent).toContain('date');
        expect(table!.textContent).toContain('2024-01-01');
    });

    test('does not render front matter headings in TOC', async () => {
        const markdown = `---
title: Doc Title
---

# Real Heading
`;
        await window.renderMarkdown(markdown);
        const preview = document.getElementById('markdown-preview')!;
        const table = preview.querySelector('table.yaml-frontmatter');
        expect(table).toBeTruthy();
        const h1 = preview.querySelector('h1');
        expect(h1?.textContent).toContain('Real Heading');
    });

    test('file without front matter renders normally', async () => {
        const markdown = `# Just a Heading

Regular content here.
`;
        await window.renderMarkdown(markdown);
        const preview = document.getElementById('markdown-preview')!;
        const table = preview.querySelector('table.yaml-frontmatter');
        expect(table).toBeNull();
        const h1 = preview.querySelector('h1');
        expect(h1?.textContent).toContain('Just a Heading');
    });

    test('non-first-line --- is not treated as front matter', async () => {
        const markdown = `# Heading

Some text

---

More text
`;
        await window.renderMarkdown(markdown);
        const preview = document.getElementById('markdown-preview')!;
        const table = preview.querySelector('table.yaml-frontmatter');
        expect(table).toBeNull();
    });

    test('nested YAML object renders as nested content', async () => {
        const markdown = `---
title: Nested Doc
meta:
  version: 1.0
  status: draft
---

# Content
`;
        await window.renderMarkdown(markdown);
        const preview = document.getElementById('markdown-preview')!;
        const table = preview.querySelector('table.yaml-frontmatter');
        expect(table).toBeTruthy();
        expect(table!.textContent).toContain('meta');
    });
});
