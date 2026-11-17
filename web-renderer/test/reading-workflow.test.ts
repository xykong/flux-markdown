import { showZoomFeedback, workflowLabels } from '../src/reading-workflow-ui';
import { captureReadingState, restoreReadingState, updateNavigation } from '../src/reading-state';

describe('reading workflow', () => {
    test('zoom feedback is scoped and does not enter document content', () => {
        document.body.innerHTML='<div id="markdown-preview"><p>Read</p></div>';
        window.__fluxLang='zh';showZoomFeedback(1.5,'document');
        expect(document.getElementById('zoom-feedback')?.textContent).toBe('文档 150%');
        expect(document.querySelector('#markdown-preview #zoom-feedback')).toBeNull();
        showZoomFeedback(2,'diagram');expect(document.getElementById('zoom-feedback')?.textContent).toBe('图表 200%');
        for(const language of ['zh','en','de','fr','es','ar']) {
            window.__fluxLang=language;expect(workflowLabels().gestures).toContain('100%');
        }
    });
    test('native history availability enables only usable navigation actions', () => {
        document.body.innerHTML='<span id="reading-navigation"><button>Back</button><button>Forward</button></span>';
        const buttons=document.querySelectorAll<HTMLButtonElement>('#reading-navigation button');
        updateNavigation(true,false);expect(buttons[0].disabled).toBe(false);expect(buttons[1].disabled).toBe(true);
        updateNavigation(false,true);expect(buttons[0].disabled).toBe(true);expect(buttons[1].disabled).toBe(false);
        updateNavigation(false,false);expect(buttons[0].disabled).toBe(true);expect(buttons[1].disabled).toBe(true);
    });
    test('semantic anchors survive insertion and do not persist paragraph text', () => {
        document.body.innerHTML='<div id="markdown-preview"><p>Before</p><p id="target">Private reading paragraph</p><p>After</p></div>';
        document.elementFromPoint=jest.fn(()=>document.getElementById('target'));
        window.scrollBy=jest.fn();window.scrollTo=jest.fn();
        const target=document.getElementById('target')!;
        target.getBoundingClientRect=()=>new DOMRect(0,120,400,100);
        const state=captureReadingState();
        expect(JSON.stringify(state)).not.toContain('Private reading');
        document.getElementById('markdown-preview')!.insertAdjacentHTML('afterbegin','<p>Inserted</p>');
        target.getBoundingClientRect=()=>new DOMRect(0,220,400,100);
        expect(restoreReadingState(state)).toBe(true);
        expect(window.scrollBy).toHaveBeenCalledWith(expect.objectContaining({top:100}));
    });
});
