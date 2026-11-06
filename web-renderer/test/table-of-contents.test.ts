import { TableOfContents } from '../src/table-of-contents';
import type { HeadingNode } from '../src/outline';

const mockIntersectionObserver = jest.fn();
mockIntersectionObserver.mockReturnValue({
    observe: jest.fn(),
    unobserve: jest.fn(),
    disconnect: jest.fn()
});

(window as any).IntersectionObserver = mockIntersectionObserver;

describe('TableOfContents', () => {
    let container: HTMLElement;
    let toc: TableOfContents;

    beforeEach(() => {
        jest.clearAllMocks();
        Object.defineProperty(window, 'innerWidth', {configurable:true,value:700});
        document.body.innerHTML = '<div id="toc-container"></div>';
        container = document.getElementById('toc-container')!;
        toc = new TableOfContents('toc-container');
    });

    afterEach(() => toc.dispose());

    test('heading direction follows its own text independently of interface language', () => {
        for (const direction of ['ltr', 'rtl']) {
            document.documentElement.dir = direction;
            toc.render([
                {level: 1, text: '1. مقدمة', id: 'arabic', children: []},
                {level: 2, text: 'שלום עולם', id: 'hebrew', children: []},
                {level: 2, text: 'English title', id: 'english', children: []},
            ]);
            const links = Array.from(container.querySelectorAll<HTMLAnchorElement>('.toc-link'));
            expect(links.map(link => link.dir)).toEqual(['auto', 'auto', 'auto']);
            expect(links.map(link => link.textContent)).toEqual(['1. مقدمة', 'שלום עולם', 'English title']);
            expect(container.querySelector('.toc-header')?.getAttribute('dir')).toBeNull();
        }
        document.documentElement.removeAttribute('dir');
    });

    test('should initialize with toggle button', () => {
        const button = container.querySelector('.toc-toggle');
        expect(button).toBeTruthy();
    });

    test('should throw error if container not found', () => {
        expect(() => {
            new TableOfContents('non-existent-id');
        }).toThrow('TOC container element not found');
    });

    test('should hide container when no headings', () => {
        toc.render([]);
        expect(container.style.display).toBe('none');
    });

    test('should show container when headings exist', () => {
        const headings: HeadingNode[] = [
            { level: 1, text: 'Title', id: 'title', children: [] }
        ];
        toc.render(headings);
        expect(container.style.display).toBe('block');
    });

    test('should render flat heading list', () => {
        const headings: HeadingNode[] = [
            { level: 1, text: 'H1', id: 'h1', children: [] },
            { level: 1, text: 'H2', id: 'h2', children: [] }
        ];
        toc.render(headings);

        const links = container.querySelectorAll('.toc-link');
        expect(links).toHaveLength(2);
        expect(links[0].textContent).toBe('H1');
        expect(links[0].getAttribute('href')).toBe('#h1');
        expect(links[1].textContent).toBe('H2');
    });

    test('should render hierarchical heading tree', () => {
        const headings: HeadingNode[] = [
            {
                level: 1,
                text: 'Parent',
                id: 'parent',
                children: [
                    { level: 2, text: 'Child 1', id: 'child1', children: [] },
                    { level: 2, text: 'Child 2', id: 'child2', children: [] }
                ]
            }
        ];
        toc.render(headings);

        const allLinks = container.querySelectorAll('.toc-link');
        expect(allLinks).toHaveLength(3);
        
        const nestedLists = container.querySelectorAll('.toc-list .toc-list');
        expect(nestedLists.length).toBeGreaterThan(0);
    });

    test('should set correct data-level attributes', () => {
        const headings: HeadingNode[] = [
            {
                level: 1,
                text: 'H1',
                id: 'h1',
                children: [
                    {
                        level: 2,
                        text: 'H2',
                        id: 'h2',
                        children: [
                            { level: 3, text: 'H3', id: 'h3', children: [] }
                        ]
                    }
                ]
            }
        ];
        toc.render(headings);

        const h1Link = container.querySelector('[href="#h1"]');
        const h2Link = container.querySelector('[href="#h2"]');
        const h3Link = container.querySelector('[href="#h3"]');

        expect(h1Link?.getAttribute('data-level')).toBe('1');
        expect(h2Link?.getAttribute('data-level')).toBe('2');
        expect(h3Link?.getAttribute('data-level')).toBe('3');
    });

    test('should toggle visibility', () => {
        const headings: HeadingNode[] = [
            { level: 1, text: 'H1', id: 'h1', children: [] }
        ];
        toc.render(headings);

        const nav = container.querySelector('.toc-nav') as HTMLElement;
        expect(nav.classList.contains('visible')).toBe(false);

        toc.toggle();
        expect(nav.classList.contains('visible')).toBe(true);

        toc.toggle();
        expect(nav.classList.contains('visible')).toBe(false);
    });

    test('should show/hide programmatically', () => {
        const headings: HeadingNode[] = [
            { level: 1, text: 'H1', id: 'h1', children: [] }
        ];
        toc.render(headings);

        const nav = container.querySelector('.toc-nav') as HTMLElement;

        toc.show();
        expect(nav.classList.contains('visible')).toBe(true);

        toc.hide();
        expect(nav.classList.contains('visible')).toBe(false);
    });

    test('should handle click on link and prevent default', () => {
        document.body.innerHTML = `
            <div id="toc-container"></div>
            <h1 id="target">Target Heading</h1>
        `;
        
        const targetHeading = document.getElementById('target')!;
        targetHeading.scrollIntoView = jest.fn();
        
        toc.dispose();
        const newContainer = document.getElementById('toc-container')!;
        const newToc = new TableOfContents('toc-container');
        const headings: HeadingNode[] = [
            { level: 1, text: 'Target', id: 'target', children: [] }
        ];
        newToc.render(headings);

        const link = newContainer.querySelector('.toc-link') as HTMLAnchorElement;
        expect(link).not.toBeNull();
        
        const clickEvent = new MouseEvent('click', { bubbles: true, cancelable: true });
        const preventDefaultSpy = jest.spyOn(clickEvent, 'preventDefault');
        link.dispatchEvent(clickEvent);

        expect(preventDefaultSpy).toHaveBeenCalled();
        expect(targetHeading.scrollIntoView).toHaveBeenCalledWith({ behavior: 'smooth', block: 'start' });
        newToc.dispose();
    });
});
