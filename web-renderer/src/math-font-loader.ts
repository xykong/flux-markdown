import { mathjax } from '@mathjax/src/js/mathjax.js';

declare global {
    interface ImportMeta {
        glob(pattern: string): Record<string, () => Promise<unknown>>;
    }
}

const modules = import.meta.glob('../node_modules/@mathjax/mathjax-newcm-font/mjs/svg/dynamic/*.js');

export function installMathFontLoader(): void {
    mathjax.asyncLoad = (name: string) => {
        const match = /^@mathjax\/mathjax-newcm-font\/js\/svg\/dynamic\/([\w-]+)\.js$/.exec(name);
        const load = match && modules[`../node_modules/@mathjax/mathjax-newcm-font/mjs/svg/dynamic/${match[1]}.js`];
        if (!load) return Promise.reject(new Error('Unbundled mathematical resource'));
        return load();
    };
}
