import { uniqueMathTargets } from '../src/math-source-store';

test('rejects every ambiguous identity, including three matches, while retaining independent targets', () => {
    const root = document.createElement('div');
    root.innerHTML = '<span data-math-id="duplicate"></span><b data-math-id="valid"></b><i data-math-id="duplicate"></i><em data-math-id="duplicate"></em><div data-math-id="unrequested"></div>';
    const targets = uniqueMathTargets(root, ['duplicate', 'valid', 'missing']);
    expect(targets.get('duplicate')).toBeNull();
    expect(targets.get('missing')).toBeNull();
    expect(targets.get('valid')?.tagName).toBe('B');
    expect(targets.has('unrequested')).toBe(false);
});

test('treats identities as literal data rather than CSS selectors', () => {
    const root = document.createElement('div');
    const node = document.createElement('span');
    const id = 'literal"] , [data-math-id="other';
    node.setAttribute('data-math-id', id); root.append(node);
    expect(uniqueMathTargets(root, [id]).get(id)).toBe(node);
});

test('bounds DOM scans independently of mathematical item count and skips plain documents', () => {
    const root = document.createElement('div');
    root.innerHTML = Array.from({length:1000}, (_, i) => `<span data-math-id="m${i}"><svg><path></path></svg></span>`).join('');
    const query = jest.spyOn(root, 'querySelectorAll');
    expect(uniqueMathTargets(root, []).size).toBe(0);
    expect(query).not.toHaveBeenCalled();
    expect(uniqueMathTargets(root, Array.from({length:1000}, (_, i) => 'm'+i)).size).toBe(1000);
    expect(query).toHaveBeenCalledTimes(1);
});
