import { TeX } from '@mathjax/src/js/input/tex.js';
import { AmsTags } from '@mathjax/src/js/input/tex/ams/AmsConfiguration.js';
import { Configuration } from '@mathjax/src/js/input/tex/Configuration.js';
import TexError from '@mathjax/src/js/input/tex/TexError.js';
import '@mathjax/src/js/input/tex/base/BaseConfiguration.js';
import '@mathjax/src/js/input/tex/newcommand/NewcommandConfiguration.js';
import '@mathjax/src/js/input/tex/textmacros/TextMacrosConfiguration.js';

/** UTF-8 bytes, without lossy whitespace/Unicode normalization. */
function labelHex(label: string): string {
    let encoded: string;
    try { encoded = encodeURIComponent(label); }
    catch { throw new TexError('InvalidLabel', 'Invalid Unicode in equation label'); }
    const hex = encoded.replace(/%([0-9A-F]{2})|([^%])/g, (_match, byte: string | undefined, character: string) =>
        byte ? byte.toLowerCase() : character.charCodeAt(0).toString(16).padStart(2, '0'));
    if (hex.length > 512) throw new TexError('LabelLimit', 'Equation label exceeds 256 UTF-8 bytes');
    return hex;
}

/** Register one class, never a growing tagformat class per rendered document. */
class FluxAmsTags extends AmsTags {
    private equations = new WeakMap<object, number>();
    private nextEquation = 0;
    private equation = 0;
    private row = 0;

    constructor() {
        super();
        this.allLabels = Object.create(null);
        this.allIds = Object.create(null);
        this.labels = Object.create(null);
        this.ids = Object.create(null);
    }

    reset(offset = 0): void {
        super.reset(offset);
        this.allLabels = Object.create(null);
        this.allIds = Object.create(null);
        this.equations = new WeakMap();
        this.nextEquation = 0;
    }

    startEquation(math: Parameters<AmsTags['startEquation']>[0]): void {
        super.startEquation(math);
        this.labels = Object.create(null);
        this.ids = Object.create(null);
        if (!this.equations.has(math)) this.equations.set(math, this.nextEquation++);
        this.equation = this.equations.get(math)!;
        this.row = 0;
    }

    protected formatId(_id: string): string {
        const namespace = String(this.configuration.options.fluxMathNamespace);
        return this.label
            ? `${namespace}-l-${labelHex(this.label)}`
            : `${namespace}-u-${this.equation}-${this.row++}`;
    }
}

Configuration.create('flux-math-identity', {
    tags: { 'flux-ams': FluxAmsTags },
    options: { fluxMathNamespace: 'fxeq' },
});

export function createMathInput(namespace: string): TeX<unknown, unknown, unknown> {
    if (!/^[a-zA-Z][a-zA-Z0-9-]*$/.test(namespace)) throw new Error('Invalid math namespace');
    return new TeX({
        packages: ['base', 'ams', 'newcommand', 'textmacros', 'flux-math-identity'],
        tags: 'flux-ams', fluxMathNamespace: namespace,
        maxBuffer: 64 * 1024, maxMacros: 1000,
        processEnvironments: true, processRefs: true,
    });
}
