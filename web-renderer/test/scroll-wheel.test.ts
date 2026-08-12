jest.mock('mermaid', () => ({
  initialize: jest.fn(),
  render: jest.fn().mockResolvedValue({ svg: '<svg>mocked</svg>' }),
}));

import '../src/index';

describe('wheel event handling', () => {
  beforeEach(() => {
    document.body.innerHTML = '<div id="markdown-preview"></div>';
  });

  test('normal wheel event (ctrlKey=false) is NOT intercepted', () => {
    const event = new WheelEvent('wheel', { ctrlKey: false, deltaY: 100, cancelable: true, bubbles: true });
    const preventDefaultSpy = jest.spyOn(event, 'preventDefault');

    document.dispatchEvent(event);

    expect(preventDefaultSpy).not.toHaveBeenCalled();
  });

  test('ctrlKey+wheel is not intercepted by the renderer', () => {
    const scrollBySpy = jest.spyOn(window, 'scrollBy').mockImplementation(() => {});
    const event = new WheelEvent('wheel', {
      ctrlKey: true,
      deltaX: 12,
      deltaY: 100,
      cancelable: true,
      bubbles: true,
    });
    const preventDefaultSpy = jest.spyOn(event, 'preventDefault');

    document.dispatchEvent(event);

    expect(preventDefaultSpy).not.toHaveBeenCalled();
    expect(scrollBySpy).not.toHaveBeenCalled();
    scrollBySpy.mockRestore();
  });

  test('ctrlKey+wheel never enters a synchronous Swift zoom bridge', () => {
    const pinchZoomSpy = jest.fn();
    (window as any).webkit = { messageHandlers: { pinchZoom: { postMessage: pinchZoomSpy } } };

    const event = new WheelEvent('wheel', { ctrlKey: true, deltaY: -100, cancelable: true, bubbles: true });
    document.dispatchEvent(event);

    expect(pinchZoomSpy).not.toHaveBeenCalled();

    delete (window as any).webkit;
  });

});
