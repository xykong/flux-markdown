import { installSVGZoom } from '../src/svg-zoom';

test('SVG controls are independent and restore exact automatic styling and links', () => {
    document.body.innerHTML='<div id="root"><p><a href="https://example.com"><img class="svg-image svg-standalone" style="max-width:300px"></a></p><p><img class="svg-image svg-standalone"></p><p>inline <img class="svg-image"></p></div>';
    const root=document.getElementById('root')!;
    const images=root.querySelectorAll('img');
    for (const img of images) {
        Object.defineProperty(img,'naturalWidth',{value:300});
        img.getBoundingClientRect=()=>({width:300,height:100} as DOMRect);
    }
    const dispose=installSVGZoom(root);
    expect(root.querySelectorAll('.svg-image-tools')).toHaveLength(2);
    const buttons=root.querySelectorAll<HTMLButtonElement>('.svg-image-tools button');
    buttons[2].click();
    expect(images[0].style.width).toBe('375px');
    expect(images[1].style.width).toBe('');
    expect(images[0].closest('a')?.href).toBe('https://example.com/');
    buttons[1].click();
    expect(images[0].style.width).toBe('');
    expect(images[0].style.maxWidth).toBe('300px');
    for(let i=0;i<20;i++)buttons[0].click();
    expect(buttons[0].disabled).toBe(true);
    dispose();
    expect(root.querySelector('.svg-image-diagram')).toBeNull();
    expect(images[0].parentElement?.tagName).toBe('A');
    expect(images[0].style.width).toBe('');
});

test('late image loading enables controls and disposal prevents stale interactions', () => {
    document.body.innerHTML='<div id="root"><p><img class="svg-image"></p></div>';
    const root=document.getElementById('root')!, img=root.querySelector('img')!;
    let naturalWidth=0;
    Object.defineProperty(img,'naturalWidth',{get:()=>naturalWidth});
    img.getBoundingClientRect=()=>({width:300,height:100} as DOMRect);
    const dispose=installSVGZoom(root);
    const zoom=root.querySelectorAll<HTMLButtonElement>('button')[2];
    expect(zoom.disabled).toBe(true);
    naturalWidth=300;img.dispatchEvent(new Event('load'));
    expect(zoom.disabled).toBe(false);
    zoom.click();expect(img.style.width).toBe('375px');
    dispose();zoom.click();img.dispatchEvent(new Event('load'));
    expect(img.style.width).toBe('');
});
