import MarkdownIt from 'markdown-it';
// @ts-ignore
import anchor from 'markdown-it-anchor';
import { extractHeadings, buildHeadingTree, extractOutline, HeadingNode, headingSlug } from '../src/outline';

describe('Outline Extraction', () => {
    let md: MarkdownIt;

    beforeEach(() => {
        md = new MarkdownIt();
        md.use(anchor, {
            permalink: false,
            slugify: (s: string) => s.toLowerCase().replace(/[^\w\u4e00-\u9fa5]+/g, '-').replace(/^-+|-+$/g, '')
        });
    });

    describe('extractHeadings', () => {
        test('should extract flat list of headings with correct levels', () => {
            const markdown = `
# Heading 1
## Heading 2
### Heading 3
## Another H2
`;
            const tokens = md.parse(markdown, {});
            const headings = extractHeadings(tokens);

            expect(headings).toHaveLength(4);
            expect(headings[0]).toMatchObject({ level: 1, text: 'Heading 1' });
            expect(headings[1]).toMatchObject({ level: 2, text: 'Heading 2' });
            expect(headings[2]).toMatchObject({ level: 3, text: 'Heading 3' });
            expect(headings[3]).toMatchObject({ level: 2, text: 'Another H2' });
        });

        test('should extract anchor IDs from markdown-it-anchor', () => {
            const markdown = `# Hello World`;
            const tokens = md.parse(markdown, {});
            const headings = extractHeadings(tokens);

            expect(headings).toHaveLength(1);
            expect(headings[0].id).toBe('hello-world');
        });

        test('should handle Chinese characters in headings', () => {
            const markdown = `# 中文标题`;
            const tokens = md.parse(markdown, {});
            const headings = extractHeadings(tokens);

            expect(headings).toHaveLength(1);
            expect(headings[0].text).toBe('中文标题');
            expect(headings[0].id).toBeTruthy();
        });

        test('should return empty array when no headings', () => {
            const markdown = `Just some text without headings.`;
            const tokens = md.parse(markdown, {});
            const headings = extractHeadings(tokens);

            expect(headings).toHaveLength(0);
        });
    });

    describe('buildHeadingTree', () => {
        test('should build hierarchical tree from flat headings', () => {
            const flatHeadings: HeadingNode[] = [
                { level: 1, text: 'H1', id: 'h1', children: [] },
                { level: 2, text: 'H2-1', id: 'h2-1', children: [] },
                { level: 3, text: 'H3', id: 'h3', children: [] },
                { level: 2, text: 'H2-2', id: 'h2-2', children: [] }
            ];

            const tree = buildHeadingTree(flatHeadings);

            expect(tree).toHaveLength(1);
            expect(tree[0].text).toBe('H1');
            expect(tree[0].children).toHaveLength(2);
            expect(tree[0].children[0].text).toBe('H2-1');
            expect(tree[0].children[0].children).toHaveLength(1);
            expect(tree[0].children[0].children[0].text).toBe('H3');
            expect(tree[0].children[1].text).toBe('H2-2');
        });

        test('should handle multiple root-level headings', () => {
            const flatHeadings: HeadingNode[] = [
                { level: 1, text: 'H1-A', id: 'h1-a', children: [] },
                { level: 2, text: 'H2', id: 'h2', children: [] },
                { level: 1, text: 'H1-B', id: 'h1-b', children: [] }
            ];

            const tree = buildHeadingTree(flatHeadings);

            expect(tree).toHaveLength(2);
            expect(tree[0].text).toBe('H1-A');
            expect(tree[0].children).toHaveLength(1);
            expect(tree[1].text).toBe('H1-B');
        });

        test('should handle skipped heading levels', () => {
            const flatHeadings: HeadingNode[] = [
                { level: 1, text: 'H1', id: 'h1', children: [] },
                { level: 3, text: 'H3', id: 'h3', children: [] }
            ];

            const tree = buildHeadingTree(flatHeadings);

            expect(tree).toHaveLength(1);
            expect(tree[0].children).toHaveLength(1);
            expect(tree[0].children[0].text).toBe('H3');
        });

        test('should return empty array for empty input', () => {
            const tree = buildHeadingTree([]);
            expect(tree).toHaveLength(0);
        });
    });

    describe('extractOutline', () => {
        test('should extract complete hierarchical outline', () => {
            const markdown = `
# Introduction
## Background
## Motivation
# Implementation
## Architecture
### Frontend
### Backend
## Testing
`;
            const outline = extractOutline(md, markdown);

            expect(outline).toHaveLength(2);
            expect(outline[0].text).toBe('Introduction');
            expect(outline[0].children).toHaveLength(2);
            expect(outline[1].text).toBe('Implementation');
            expect(outline[1].children).toHaveLength(2);
            expect(outline[1].children[0].children).toHaveLength(2);
        });

        test('should handle document with no headings', () => {
            const markdown = `Just regular text content`;
            const outline = extractOutline(md, markdown);

            expect(outline).toHaveLength(0);
        });
    });
});


test('heading fallback preserves existing anchors and supports non-Latin-only titles', () => {
    expect(headingSlug('Hello World')).toBe('hello-world');
    expect(headingSlug('中文标题')).toBe('中文标题');
    expect(headingSlug('API مقدمة')).toBe('api');
    expect(headingSlug('مقدمة')).toBe('مقدمة');
    expect(headingSlug('שלום עולם')).toBe('שלום-עולם');
    expect(headingSlug('🎉')).toBe('section');
});
