import { TextDecoder } from 'util';
Object.assign(globalThis, { TextDecoder });
import { constrainSVGImage, svgImageMetrics } from '../src/svg-image-layout';
const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="100%" style="max-width:586.5px" viewBox="4 4 586.5 1088"><style>svg {font-size:16px}</style><text>Diagram</text></svg>';
const data = (text: string) => 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(text);

test('reads percentage-width SVG drawing geometry without attaching its contents', () => {
    expect(svgImageMetrics(data(svg))).toEqual({width:586.5, textWidthInEm:586.5/16});
    expect(svgImageMetrics('data:image/svg+xml;base64,' + btoa(svg))).toEqual(svgImageMetrics(data(svg)));
    expect(document.querySelector('svg')).toBeNull();
});
test('retains smaller author image sizes and ignores raster images', () => {
    const img = document.createElement('img'); img.width=96;
    constrainSVGImage(img, data(svg));
    expect(img.width).toBe(96);
    expect(img.style.maxWidth).toContain('586.5px');
    expect(img.style.maxWidth).toContain('36.65625em');
    const raster=document.createElement('img');
    constrainSVGImage(raster, 'data:image/png;base64,AAAA');
    expect(raster.getAttribute('style')).toBeNull();
});
test('caps authored large text and absolute native size, accepts icons without viewBox', () => {
    expect(svgImageMetrics(data('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 400" width="300"><text font-size="32">A</text></svg>'))).toEqual({width:300,textWidthInEm:600/32});
    expect(svgImageMetrics(data('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><path d="M0 0"/></svg>'))).toEqual({width:96});
});
test('rejects malformed or unbounded geometry and XML entity declarations', () => {
    for (const source of ['data:image/svg+xml,%xx',data('<svg'),data('<svg viewBox="0 0 -1 0"/>'),data('<!DOCTYPE svg [<!ENTITY x "a">]><svg/>')]) {
        expect(svgImageMetrics(source)).toBeUndefined();
    }
});

test('respects a smaller SVG-root maximum and scales the text cap with body size', () => {
    expect(svgImageMetrics(data('<svg viewBox="0 0 600 400" style="max-width:200px"><text font-size="32">A</text></svg>'))).toEqual({width:200,textWidthInEm:18.75});
    const img=document.createElement('img'); img.style.maxWidth='100px';
    constrainSVGImage(img,data(svg));
    expect(img.style.maxWidth).toContain('100px');
});

test('normalizes the isolated SVG viewport as well as the HTML image box', () => {
    const img=document.createElement('img');
    const result=constrainSVGImage(img,data(svg));
    const decoded=decodeURIComponent(result.slice(result.indexOf(',')+1));
    const root=new DOMParser().parseFromString(decoded,'image/svg+xml').documentElement;
    expect(root.getAttribute('width')).toBe('586.5');
    expect(root.getAttribute('height')).toBe('1088');
    expect(root.getAttribute('viewBox')).toBe('4 4 586.5 1088');
    expect(document.querySelector('svg')).toBeNull();
});

test('centers standalone SVGs including linked diagrams, but preserves inline and authored alignment', () => {
    for (const markup of ['<p> <img> </p>', '<p><a href="https://example.com"><img></a></p>']) {
        document.body.innerHTML=markup;
        const img=document.querySelector('img')!;
        constrainSVGImage(img,data(svg));
        expect(img.classList.contains('svg-standalone')).toBe(true);
    }
    for (const markup of ['<p>Text <img> more</p>', '<p><img><img></p>', '<p align="left"><img></p>', '<div style="text-align:right"><p><img></p></div>', '<p><img style="float:left"></p>']) {
        document.body.innerHTML=markup;
        const img=document.querySelector('img')!;
        constrainSVGImage(img,data(svg));
        expect(img.classList.contains('svg-standalone')).toBe(false);
    }
});
