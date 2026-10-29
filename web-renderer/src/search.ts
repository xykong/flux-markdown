/**
 * Search engine for finding and highlighting text in the rendered markdown content
 */

export interface SearchOptions {
    caseSensitive: boolean;
    wholeWord: boolean;
    useRegex: boolean;
}

export interface SearchMatch {
    element: HTMLElement;
    textNode: Text;
    startOffset: number;
    endOffset: number;
    index: number; // Global match index
}

export class SearchEngine {
    private matches: SearchMatch[] = [];
    private currentIndex: number = -1;
    private searchQuery: string = '';
    private options: SearchOptions = {
        caseSensitive: false,
        wholeWord: false,
        useRegex: false
    };
    private highlightClassName = 'search-highlight';
    private activeHighlightClassName = 'search-highlight-active';

    constructor() {}

    /**
     * Execute search and highlight all matches
     * @param query Search query
     * @param options Search options
     * @returns Number of matches found, or -1 if regex is invalid
     */
    public search(query: string, options: SearchOptions): number {
        // Clear previous search
        this.clear();

        if (!query) {
            return 0;
        }

        this.searchQuery = query;
        this.options = { ...options };

        // Find all matches
        const contentDiv = document.getElementById('markdown-preview');
        if (!contentDiv) {
            return 0;
        }

        try {
            this.matches = this.findMatches(contentDiv, query, options);
            this.highlightMatches();
            
            if (this.matches.length > 0) {
                this.currentIndex = 0;
                this.setActiveMatch(0);
            }

            return this.matches.length;
        } catch (error) {
            // Invalid regex
            if (error instanceof SyntaxError && options.useRegex) {
                return -1; // Signal regex error
            }
            throw error;
        }
    }

    /**
     * Navigate to next match
     */
    public next(): void {
        if (this.matches.length === 0) return;
        
        this.currentIndex = (this.currentIndex + 1) % this.matches.length;
        this.setActiveMatch(this.currentIndex);
    }

    /**
     * Navigate to previous match
     */
    public previous(): void {
        if (this.matches.length === 0) return;
        
        this.currentIndex = (this.currentIndex - 1 + this.matches.length) % this.matches.length;
        this.setActiveMatch(this.currentIndex);
    }

    /**
     * Clear all search highlights
     */
    public clear(): void {
        // Remove all highlight elements
        const highlights = document.querySelectorAll(`.${this.highlightClassName}`);
        highlights.forEach(highlight => {
            const parent = highlight.parentNode;
            if (parent) {
                const textNode = document.createTextNode(highlight.textContent || '');
                parent.replaceChild(textNode, highlight);
                parent.normalize(); // Merge adjacent text nodes
            }
        });

        this.matches = [];
        this.currentIndex = -1;
        this.searchQuery = '';
    }

    /**
     * Get current match index (1-based)
     */
    public getCurrentIndex(): number {
        return this.matches.length > 0 ? this.currentIndex + 1 : 0;
    }

    /**
     * Get total number of matches
     */
    public getMatchCount(): number {
        return this.matches.length;
    }

    /**
     * Find all text matches in the DOM tree
     */
    private findMatches(root: HTMLElement, query: string, options: SearchOptions): SearchMatch[] {
        const matches: SearchMatch[] = [];
        const regex = this.buildRegex(query, options);

        // Use TreeWalker to traverse text nodes
        const walker = document.createTreeWalker(
            root,
            NodeFilter.SHOW_TEXT,
            {
                acceptNode: (node) => {
                    // Skip script, style, and other non-visible elements
                    const parent = node.parentElement;
                    if (!parent || parent.closest('.block-copy-tools')) return NodeFilter.FILTER_REJECT;

                    const tagName = parent.tagName.toLowerCase();
                    if (['script', 'style', 'noscript'].includes(tagName)) {
                        return NodeFilter.FILTER_REJECT;
                    }

                    // Skip empty text nodes
                    if (!node.textContent || node.textContent.trim() === '') {
                        return NodeFilter.FILTER_REJECT;
                    }

                    // Skip nodes that are already highlights
                    if (parent.classList.contains(this.highlightClassName)) {
                        return NodeFilter.FILTER_REJECT;
                    }

                    return NodeFilter.FILTER_ACCEPT;
                }
            }
        );

        let matchIndex = 0;
        let node: Node | null = walker.nextNode();

        while (node) {
            const textNode = node as Text;
            const text = textNode.textContent || '';
            
            let match: RegExpExecArray | null = regex.exec(text);
            while (match) {
                matches.push({
                    element: textNode.parentElement!,
                    textNode: textNode,
                    startOffset: match.index,
                    endOffset: match.index + match[0].length,
                    index: matchIndex++
                });

                // Prevent infinite loop for zero-width matches
                if (match.index === regex.lastIndex) {
                    regex.lastIndex++;
                }
                
                match = regex.exec(text);
            }
            
            node = walker.nextNode();
        }

        return matches;
    }

    /**
     * Build regex based on query and options
     */
    private buildRegex(query: string, options: SearchOptions): RegExp {
        if (options.useRegex) {
            const flags = options.caseSensitive ? 'g' : 'gi';
            return new RegExp(query, flags);
        } else {
            // Escape special regex characters
            let pattern = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            
            if (options.wholeWord) {
                pattern = `\\b${pattern}\\b`;
            }
            
            const flags = options.caseSensitive ? 'g' : 'gi';
            return new RegExp(pattern, flags);
        }
    }

    /**
     * Wrap all matches with highlight spans
     */
    private highlightMatches(): void {
        // Process matches in reverse order to maintain correct offsets
        for (let i = this.matches.length - 1; i >= 0; i--) {
            const match = this.matches[i];
            this.wrapMatch(match);
        }
    }

    /**
     * Wrap a single match with a highlight span
     */
    private wrapMatch(match: SearchMatch): void {
        const textNode = match.textNode;
        const text = textNode.textContent || '';

        // Split the text node into three parts: before, match, after
        const before = text.substring(0, match.startOffset);
        const matchText = text.substring(match.startOffset, match.endOffset);
        const after = text.substring(match.endOffset);

        // Create highlight span
        const span = document.createElement('span');
        span.className = this.highlightClassName;
        span.textContent = matchText;
        span.dataset.matchIndex = match.index.toString();

        // Create document fragment with the three parts
        const fragment = document.createDocumentFragment();
        
        if (before) {
            fragment.appendChild(document.createTextNode(before));
        }
        
        fragment.appendChild(span);
        
        if (after) {
            fragment.appendChild(document.createTextNode(after));
        }

        // Replace the text node with the fragment
        const parent = textNode.parentNode;
        if (parent) {
            parent.replaceChild(fragment, textNode);
            
            // Update the match to point to the new span's text node
            match.textNode = span.firstChild as Text;
            match.element = span;
        }
    }

    /**
     * Set the active match and scroll it into view
     */
    private setActiveMatch(index: number): void {
        if (index < 0 || index >= this.matches.length) return;

        const allHighlights = document.querySelectorAll(`.${this.activeHighlightClassName}`);
        allHighlights.forEach(el => {
            el.classList.remove(this.activeHighlightClassName);
        });

        // Add active class to current match
        const match = this.matches[index];
        const highlightSpan = match.element;
        highlightSpan.classList.add(this.activeHighlightClassName);

        // Scroll into view
        highlightSpan.scrollIntoView({
            behavior: 'smooth',
            block: 'center',
            inline: 'nearest'
        });
    }
}
