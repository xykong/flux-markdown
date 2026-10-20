import { installErrorFeedback, setFeedbackGeneration } from '../src/error-feedback';

describe('contextual error feedback', () => {
    const postMessage = jest.fn();
    beforeEach(() => {
        document.body.innerHTML = '';
        window.webkit = { messageHandlers: { logger: { postMessage: jest.fn() }, linkClicked: { postMessage: jest.fn() }, errorFeedback: { postMessage } } };
        window.__fluxLang = 'en'; postMessage.mockClear();
        setFeedbackGeneration('generation-a');
    });
    it('records only fixed metadata and reports in one click without source text', async () => {
        const stop = installErrorFeedback(document.body);
        document.body.innerHTML = '<div class="mermaid-error">secret /Users/private diagram</div>';
        await new Promise(resolve => setTimeout(resolve, 0));
        const button = document.querySelector<HTMLButtonElement>('button[data-feedback-action="report"]')!;
        expect(button).not.toBeNull(); button.click();
        expect(postMessage.mock.calls.map(call => call[0].action)).toEqual(['record', 'report']);
        expect(JSON.stringify(postMessage.mock.calls)).not.toContain('secret');
        expect(postMessage.mock.calls[1][0].generation).toBe('generation-a');
        stop();
    });
    it('does not reuse old error controls after a document changes', async () => {
        const stop = installErrorFeedback(document.body);
        document.body.innerHTML = '<div class="graphviz-error">invalid</div>';
        await new Promise(resolve => setTimeout(resolve, 0));
        const old = document.querySelector<HTMLButtonElement>('button[data-feedback-action="report"]')!;
        setFeedbackGeneration('generation-b'); old.click();
        expect(postMessage.mock.calls.filter(call => call[0].action === 'report')).toHaveLength(0);
        stop();
    });
    it('uses native inspection for optional diagnostics and avoids duplicate controls', async () => {
        const stop = installErrorFeedback(document.body);
        document.body.innerHTML = '<div class="typst-error">bad source</div>';
        await new Promise(resolve => setTimeout(resolve, 0));
        document.querySelector('.typst-error')!.appendChild(document.createTextNode('more'));
        await new Promise(resolve => setTimeout(resolve, 0));
        expect(document.querySelectorAll('[data-feedback-action="report"]')).toHaveLength(1);
        document.querySelector<HTMLButtonElement>('[data-feedback-action="inspect"]')!.click();
        expect(postMessage.mock.calls[postMessage.mock.calls.length - 1]?.[0].action).toBe('inspect');
        stop();
    });
    it('localizes the feedback controls in Arabic', async () => {
        window.__fluxLang = 'ar';
        const stop = installErrorFeedback(document.body);
        document.body.innerHTML = '<div class="mermaid-error">خطأ</div>';
        await new Promise(resolve => setTimeout(resolve, 0));
        expect(document.querySelector<HTMLButtonElement>('[data-feedback-action="report"]')?.textContent).toBe('الإبلاغ عن هذه المشكلة');
        stop();
    });
});

describe('error surface coverage', () => {
    const classes = ['render-error', 'source-render-error', 'mermaid-error', 'typst-error', 'graphviz-error', 'vega-error', 'katex-error', 'search-error'];
    it.each(classes)('provides feedback for %s', async className => {
        document.body.innerHTML = `<div class="${className}">fixture</div>`;
        setFeedbackGeneration('coverage');
        const stop = installErrorFeedback(document.body);
        expect(document.querySelector('[data-feedback-action="report"]')).not.toBeNull();
        stop();
    });
    it('restores controls after input validation replaces the error message', async () => {
        document.body.innerHTML = '<div class="search-error">first invalid expression</div>';
        setFeedbackGeneration('search-test');
        const stop = installErrorFeedback(document.body);
        document.querySelector('.search-error')!.textContent = 'second invalid expression';
        await new Promise(resolve => setTimeout(resolve, 0));
        expect(document.querySelectorAll('[data-feedback-action="report"]')).toHaveLength(1);
        stop();
    });
    it('removes image failure controls after the image loads successfully', async () => {
        document.body.innerHTML = '<img class="image-load-failed">';
        setFeedbackGeneration('image-test');
        const stop = installErrorFeedback(document.body);
        expect(document.querySelector('[data-feedback-action="report"]')).not.toBeNull();
        document.querySelector('img')!.className = '';
        await new Promise(resolve => setTimeout(resolve, 0));
        expect(document.querySelector('[data-feedback-action="report"]')).toBeNull();
        stop();
    });
});
