/** Bundled renderer dependencies expect Object.hasOwn, absent in Safari 14. */
export function ensureMathCompatibility(): void {
    const constructor = Object as ObjectConstructor & { hasOwn?: (object: object, key: PropertyKey) => boolean };
    if (!constructor.hasOwn) {
        Object.defineProperty(constructor, 'hasOwn', {
            configurable: true, writable: true,
            value: (object: object, key: PropertyKey): boolean => Object.prototype.hasOwnProperty.call(object, key),
        });
    }
}
ensureMathCompatibility();
