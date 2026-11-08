import { ensureMathCompatibility } from '../src/math-compat';
test('provides own-property semantics with Safari 14 API availability',()=>{
    const descriptor=Object.getOwnPropertyDescriptor(Object,'hasOwn');
    try {
        Reflect.deleteProperty(Object,'hasOwn');
        ensureMathCompatibility();
        const hasOwn=(Object as ObjectConstructor & {hasOwn:(object:object,key:PropertyKey)=>boolean}).hasOwn;
        const object=Object.create({inherited:true}); object.own=true;
        expect(hasOwn(object,'own')).toBe(true);
        expect(hasOwn(object,'inherited')).toBe(false);
        expect(hasOwn(Object.create(null),'constructor')).toBe(false);
        const symbol=Symbol();object[symbol]=true;
        expect(hasOwn(object,symbol)).toBe(true);
        expect(Object.keys(Object)).not.toContain('hasOwn');
        ensureMathCompatibility();expect((Object as typeof Object & {hasOwn:unknown}).hasOwn).toBe(hasOwn);
    } finally { if(descriptor)Object.defineProperty(Object,'hasOwn',descriptor);else Reflect.deleteProperty(Object,'hasOwn'); }
});
