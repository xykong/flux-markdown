import { createDiagramZoomControls, registerDiagramZoom } from '../src/diagram-zoom-controls';
import { applyPinchZoom, requestPinchZoom, resetZoomAt, setReadingZoom } from '../src/reading-zoom';

describe('diagram pinch ownership', () => {
    function setup() {
        document.body.innerHTML = '<div id="markdown-preview"><p>Body</p><div class="mermaid"><div class="mermaid-viewport"><svg></svg></div></div><div class="mermaid"><div class="mermaid-viewport"><svg></svg></div></div></div>';
        window.scrollBy = jest.fn();
        const hosts = [...document.querySelectorAll<HTMLElement>('.mermaid')];
        const controls = hosts.map(host => {
            const controls = createDiagramZoomControls('mermaid-tools', jest.fn());
            host.prepend(controls.element);registerDiagramZoom(host, controls);
            host.querySelector('svg')!.getBoundingClientRect = () => new DOMRect(0,100,100,100);
            return controls;
        });
        document.elementFromPoint = jest.fn(() => hosts[0].querySelector('svg'));
        return {hosts,controls};
    }
    test('continuous pinch shares the button scale and leaves the other diagram and body alone', () => {
        const {controls} = setup();
        controls[0].element.querySelectorAll('button')[2].click();
        expect(applyPinchZoom(2, .2, {x:30,y:130,gesture:1001})).toBeNull();
        expect(controls[0].factor).toBeCloseTo(1.5);
        applyPinchZoom(2, .6, {x:30,y:130,gesture:1001,finished:true});
        expect(controls[0].factor).toBeCloseTo(2);
        controls[0].element.querySelectorAll('button')[2].click();
        expect(controls[0].factor).toBeCloseTo(2.5);
        expect(controls[1].factor).toBe(1);
        expect(document.getElementById('markdown-preview')!.style.getPropertyValue('zoom')).toBe('');
    });
    test('the first hit owns the gesture until it finishes; a new body gesture has its own target', () => {
        const {controls} = setup();
        const point={x:30,y:130,gesture:1002};
        applyPinchZoom(1,0,point);
        document.elementFromPoint = jest.fn(() => document.querySelector('p'));
        expect(applyPinchZoom(1,1,{...point,finished:true})).toBeNull();
        expect(controls[0].factor).toBe(2);
        expect(applyPinchZoom(1,.5,{...point,gesture:1003,finished:true})).toBe(1.5);
        expect(controls[0].factor).toBe(2);
    });
    test('a native sample burst applies only its last cumulative delta', () => {
        const {controls} = setup();
        const frames: FrameRequestCallback[]=[];
        jest.spyOn(window,'requestAnimationFrame').mockImplementation(cb=>{frames.push(cb);return 1;});
        requestPinchZoom(1,0,{x:30,y:130,gesture:1004});
        requestPinchZoom(1,.5,{x:30,y:130,gesture:1004});
        requestPinchZoom(1,1,{x:30,y:130,gesture:1004,finished:true});
        expect(frames).toHaveLength(1);expect(controls[0].factor).toBe(1);
        frames[0](0);expect(controls[0].factor).toBe(2);
        jest.restoreAllMocks();
    });
    test('smart magnify resets only the hit diagram and cancels queued pinch samples', () => {
        const {controls}=setup();
        controls[0].setFactor(2.5);controls[1].setFactor(1.5);
        const root=document.getElementById('markdown-preview')!;
        setReadingZoom(1.5);
        const frames: FrameRequestCallback[]=[];
        jest.spyOn(window,'requestAnimationFrame').mockImplementation(cb=>{frames.push(cb);return 1;});
        requestPinchZoom(1.5,.5,{x:30,y:130,gesture:1005,finished:true});
        expect(resetZoomAt({x:30,y:130})).toBeNull();
        frames[0](0);
        expect(controls[0].factor).toBe(1);
        expect(controls[0].element.querySelectorAll('button')[1].textContent).toBe('100%');
        expect(controls[1].factor).toBe(1.5);
        expect(document.documentElement.style.getPropertyValue('--zoom-scale')).toBe('1.5');
        resetZoomAt({x:30,y:130});expect(controls[0].factor).toBe(1);
        document.elementFromPoint=jest.fn(()=>document.querySelector('p'));
        expect(resetZoomAt({x:30,y:130})).toBe(1);
        expect(document.documentElement.style.getPropertyValue('--zoom-scale')).toBe('');
        jest.restoreAllMocks();
    });

});
