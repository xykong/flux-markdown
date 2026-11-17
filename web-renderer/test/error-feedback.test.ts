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
    it.each([
        ['en','image resource','Open in Editor'],
        ['zh-Hans','图片资源','在编辑器中打开'],
        ['de','Bildressource','Im Editor öffnen'],
        ['fr','image non prise','Ouvrir dans l’éditeur'],
        ['es','imagen que','Abrir en el editor'],
        ['ar','صورة','فتح في المحرر'],
    ])('explains unsupported mathematical images without diagnostics containing source (%s)', (language, hint, recovery) => {
        const postMessage=jest.fn();
        window.webkit={messageHandlers:{logger:{postMessage:jest.fn()},linkClicked:{postMessage:jest.fn()},errorFeedback:{postMessage}}};
        setFeedbackGeneration('unsupported-image-'+language);
        window.__fluxLang=language;
        document.documentElement.setAttribute('data-context','app');
        document.body.innerHTML='<span class="math-error math-resource-unsupported">SENSITIVE-MATH</span>';
        const stop=installErrorFeedback(document.body);
        const controls=document.querySelector('.error-feedback-controls')!;
        expect(controls.textContent).toContain(hint);
        expect(controls.querySelector('[data-feedback-action="recover"]')?.textContent).toBe(recovery);
        expect(postMessage).toHaveBeenCalledWith(expect.objectContaining({kind:'math',reason:'resourceUnavailable',action:'record'}));
        expect(JSON.stringify(postMessage.mock.calls)).not.toContain('SENSITIVE-MATH');
        stop();
    });

});

describe('Issue 73 useful mathematical diagnostics', () => {
    it.each([['syntax','mathSyntax'],['output','mathOutput'],['unresolved-reference','mathReference'],['input-limit','mathLimit']])('reports %s as a fixed code with line bounds, without formula contents', (code, reason) => {
        const postMessage = jest.fn();
        window.webkit = { messageHandlers: { logger: {postMessage: jest.fn()}, linkClicked: {postMessage: jest.fn()}, errorFeedback: { postMessage } } };
        setFeedbackGeneration('issue73-'+code);
        document.body.innerHTML = `<span class="math-error" data-math-failure="${code}" data-math-first="2" data-math-last="4">private formula</span>`;
        const stop = installErrorFeedback(document.body);
        expect(postMessage).toHaveBeenCalledWith(expect.objectContaining({action:'record', kind:'math', reason, lineStart:2, lineEnd:4}));
        document.querySelector<HTMLButtonElement>('[data-feedback-action="materials"]')!.click();
        expect(postMessage).toHaveBeenLastCalledWith(expect.objectContaining({action:'materials'}));
        expect(JSON.stringify(postMessage.mock.calls)).not.toContain('private formula');
        stop();
    });
    it('does not send arbitrary classifications or oversized line ranges', () => {
        const postMessage = jest.fn();
        window.webkit = { messageHandlers: { logger: {postMessage: jest.fn()}, linkClicked: {postMessage: jest.fn()}, errorFeedback: { postMessage } } };
        setFeedbackGeneration('issue73-invalid');
        document.body.innerHTML = '<span class="math-error" data-math-failure="private" data-math-first="-1" data-math-last="99999999999">secret</span>';
        const stop = installErrorFeedback(document.body);
        expect(postMessage.mock.calls[0][0]).toEqual(expect.objectContaining({reason:'operationFailed'}));
        expect(postMessage.mock.calls[0][0].lineStart).toBeUndefined();
        stop();
    });
});

test('different failed formulas do not share a source incident', () => {
    const postMessage = jest.fn();
    window.webkit = {messageHandlers:{logger:{postMessage:jest.fn()},linkClicked:{postMessage:jest.fn()},errorFeedback:{postMessage}}};
    setFeedbackGeneration('separate-formulas');
    document.body.innerHTML = '<span class="math-error" data-math-failure="syntax">A</span><span class="math-error" data-math-failure="syntax">B</span>';
    const stop = installErrorFeedback(document.body);
    const records = postMessage.mock.calls.map(call => call[0]).filter(event => event.action === 'record');
    expect(new Set(records.map(event => event.id)).size).toBe(2);
    stop();
});

test('diagram failures retain independent source ranges without sending diagram text', () => {
    const postMessage = jest.fn();
    window.webkit = {messageHandlers:{logger:{postMessage:jest.fn()},linkClicked:{postMessage:jest.fn()},errorFeedback:{postMessage}}};
    setFeedbackGeneration('diagram-samples');
    document.body.innerHTML = '<div class="mermaid-error" data-source-line="3" data-source-line-end="7">secret diagram A</div><div class="mermaid-error" data-source-line="10" data-source-line-end="12">secret diagram B</div>';
    const stop = installErrorFeedback(document.body);
    const records = postMessage.mock.calls.map(call => call[0]).filter(event => event.action === 'record');
    expect(records.map(event => [event.lineStart,event.lineEnd])).toEqual([[3,7],[10,12]]);
    expect(new Set(records.map(event => event.id)).size).toBe(2);
    expect(JSON.stringify(records)).not.toContain('secret diagram');
    stop();
});

describe('compact feedback entry', () => {
    it('shows only a red feedback entry until activated, and Escape closes it', () => {
        const postMessage = jest.fn();
        window.webkit = {messageHandlers:{logger:{postMessage:jest.fn()},linkClicked:{postMessage:jest.fn()},errorFeedback:{postMessage}}};
        window.__fluxLang = 'zh'; setFeedbackGeneration('compact');
        document.body.innerHTML = '<div class="math-error">bad formula</div>';
        const stop = installErrorFeedback(document.body);
        const trigger = document.querySelector<HTMLButtonElement>('[data-feedback-action="toggle"]')!;
        const panel = document.querySelector<HTMLElement>('.error-feedback-panel')!;
        expect(trigger.textContent).toBe('! 反馈');
        expect(trigger.getAttribute('aria-expanded')).toBe('false');
        expect(panel.hidden).toBe(true);
        trigger.click();
        expect(panel.hidden).toBe(false);
        expect(trigger.getAttribute('aria-expanded')).toBe('true');
        expect(postMessage.mock.calls.map(call => call[0].action)).toEqual(['record']);
        panel.dispatchEvent(new KeyboardEvent('keydown', {key:'Escape', bubbles:true}));
        expect(panel.hidden).toBe(true);
        expect(document.activeElement).toBe(trigger);
        stop();
    });
    it('unwraps recovered images and never repeats nested math error entry', async () => {
        setFeedbackGeneration('compact-cleanup');
        document.body.innerHTML = '<img class="image-load-failed"><div class="math-error"><span class="katex-error">bad</span></div>';
        const stop = installErrorFeedback(document.body);
        expect(document.querySelectorAll('[data-feedback-action="toggle"]')).toHaveLength(2);
        document.querySelector('img')!.classList.remove('image-load-failed');
        await new Promise(resolve => setTimeout(resolve, 0));
        expect(document.querySelectorAll('[data-feedback-action="toggle"]')).toHaveLength(1);
        expect(document.querySelector('img')!.parentElement).toBe(document.body);
        stop();
    });
});
