/**
 * Outline extraction module
 * Extracts heading structure from markdown-it tokens to build a table of contents
 */

/** Preserve existing nonempty anchors; give non-Latin-only titles a usable fallback. */
export function headingSlug(text: string): string {
    const legacy = text.toLowerCase().replace(/[^\w\u4e00-\u9fa5]+/g, '-').replace(/^-+|-+$/g, '');
    return legacy || text.toLowerCase().replace(/[^\p{L}\p{N}_]+/gu, '-').replace(/^-+|-+$/g, '') || 'section';
}

export interface HeadingNode {
    level: number;        // 1-6 for h1-h6
    text: string;         // Heading text content
    id: string;           // Anchor ID for navigation
    children: HeadingNode[];
}

/**
 * Extract headings from markdown-it tokens
 * @param tokens - Parsed markdown-it tokens
 * @returns Flat array of heading nodes
 */
export function extractHeadings(tokens: any[]): HeadingNode[] {
    const headings: HeadingNode[] = [];
    
    for (let i = 0; i < tokens.length; i++) {
        const token = tokens[i];
        
        if (token.type === 'heading_open') {
            const level = parseInt(token.tag.substring(1)); // h1 -> 1, h2 -> 2, etc.
            
            // Find the inline token that contains the text
            const inlineToken = tokens[i + 1];
            let text = '';
            if (inlineToken && inlineToken.type === 'inline') {
                text = inlineToken.content;
            }
            
            // Find the id attribute set by markdown-it-anchor
            let id = '';
            if (token.attrs) {
                const idAttr = token.attrs.find((attr: [string, string]) => attr[0] === 'id');
                if (idAttr) {
                    id = idAttr[1];
                }
            }
            
            // If no id found, generate one (fallback)
            if (!id) {
                id = headingSlug(text);
            }
            
            headings.push({
                level,
                text,
                id,
                children: []
            });
        }
    }
    
    return headings;
}

/**
 * Build hierarchical tree structure from flat heading list
 * @param headings - Flat array of headings
 * @returns Root-level headings with nested children
 */
export function buildHeadingTree(headings: HeadingNode[]): HeadingNode[] {
    if (headings.length === 0) return [];
    
    const root: HeadingNode[] = [];
    const stack: HeadingNode[] = [];
    
    for (const heading of headings) {
        // Pop from stack until we find a valid parent (lower level number)
        while (stack.length > 0 && stack[stack.length - 1].level >= heading.level) {
            stack.pop();
        }
        
        if (stack.length === 0) {
            // Top-level heading
            root.push(heading);
        } else {
            // Nested heading - add to parent's children
            stack[stack.length - 1].children.push(heading);
        }
        
        stack.push(heading);
    }
    
    return root;
}

/**
 * Extract and build complete outline structure from markdown content
 * @param markdownIt - Configured markdown-it instance
 * @param content - Markdown source text
 * @returns Hierarchical heading tree
 */
export function extractOutline(markdownIt: any, content: string): HeadingNode[] {
    const tokens = markdownIt.parse(content, {});
    const flatHeadings = extractHeadings(tokens);
    return buildHeadingTree(flatHeadings);
}
