/**
 * Pre-processes Mermaid diagram source code before handing it to mermaid.render().
 *
 * Mermaid v11 does NOT convert `\n` to `<br>` for unquoted node labels —
 * the `\n` passes through `marked` as literal text and is never line-broken.
 * Only double-quoted STR labels (`A["text\nline2"]`) get a `<br>` because they
 * go through a different internal path. Everything else needs pre-processing.
 *
 * Cases handled here:
 *   1. `participant/actor X as "label"` — quotes are preserved verbatim by
 *      Mermaid's parser; we strip them and convert any \n inside.
 *   2. Double-quoted labels `A["...\n..."]` — STR path; we convert \n.
 *   3. Unquoted bracket labels `A[...\n...]`, `A{...\n...}`, `A(...\n...)` —
 *      Mermaid passes \n as literal text; we convert to <br/>.
 *
 * The bracket passes use a character-class exclusion pattern so they never
 * touch content that starts with `"` (already handled by pass 2) and never
 * cross bracket boundaries.
 */
export function preprocessMermaidNewlines(code: string): string {
    // 1. Strip quotes from `participant/actor X as "label"` and convert \n.
    let result = code.replace(
        /((?:participant|actor)\s+\S+\s+as\s+)"((?:[^"\\]|\\.)*)"/g,
        (_match, prefix: string, inner: string) => prefix + inner.replace(/\\n/g, '<br/>')
    );

    // 2. Convert \n inside double-quoted node labels.
    result = result.replace(/"((?:[^"\\]|\\.)*)"/g, (_match, inner: string) => {
        return '"' + inner.replace(/\\n/g, '<br/>') + '"';
    });

    // 3a. Unquoted square-bracket labels: A[text\ntext]
    result = result.replace(/\[([^\]"]*?\\n[^\]"]*?)\]/g, (_match, inner: string) => {
        return '[' + inner.replace(/\\n/g, '<br/>') + ']';
    });

    // 3b. Unquoted round-bracket labels: A(text\ntext)
    result = result.replace(/\(([^)"]*?\\n[^)"]*?)\)/g, (_match, inner: string) => {
        return '(' + inner.replace(/\\n/g, '<br/>') + ')';
    });

    // 3c. Unquoted curly-bracket labels (diamond/hexagon nodes): A{text\ntext}
    result = result.replace(/\{([^}"]*?\\n[^}"]*?)\}/g, (_match, inner: string) => {
        return '{' + inner.replace(/\\n/g, '<br/>') + '}';
    });

    return result;
}

function escapeHtml(text: string): string {
    const map: Record<string, string> = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;'
    };
    return text.replace(/[&<>"']/g, (char) => map[char]);
}

function logToSwift(message: string) {
    try {
        // @ts-ignore
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.logger) {
            // @ts-ignore
            window.webkit.messageHandlers.logger.postMessage(message);
        } else {
            console.log("Swift logger not found: " + message);
        }
    } catch (e) {
        console.log("Failed to log to Swift:", e);
    }
}

window.onerror = function(message, source, lineno, _colno, _error) {
    logToSwift(`JS Error: ${message} at ${source}:${lineno}`);
};

logToSwift("JS: index.ts loaded, starting execution...");

import 'github-markdown-css/github-markdown.css';
import './styles/highlight-adaptive.css';
import 'katex/dist/katex.min.css';
import './styles/table-of-contents.css';
import './styles/image-fallback.css';
import './styles/search.css';
import './styles/source-view.css';
import './styles/callouts.css';
import './styles/print.css';
import './styles/help-overlay.css';

import MarkdownIt from 'markdown-it';
import hljs from 'highlight.js/lib/core';
import * as jsyaml from 'js-yaml';

import langJavascript from 'highlight.js/lib/languages/javascript';
import langTypescript from 'highlight.js/lib/languages/typescript';
import langPython from 'highlight.js/lib/languages/python';
import langBash from 'highlight.js/lib/languages/bash';
import langShell from 'highlight.js/lib/languages/shell';
import langSql from 'highlight.js/lib/languages/sql';
import langJson from 'highlight.js/lib/languages/json';
import langYaml from 'highlight.js/lib/languages/yaml';
import langMarkdown from 'highlight.js/lib/languages/markdown';
import langCss from 'highlight.js/lib/languages/css';
import langXml from 'highlight.js/lib/languages/xml';
import langGo from 'highlight.js/lib/languages/go';
import langRust from 'highlight.js/lib/languages/rust';
import langJava from 'highlight.js/lib/languages/java';
import langC from 'highlight.js/lib/languages/c';
import langCpp from 'highlight.js/lib/languages/cpp';
import langSwift from 'highlight.js/lib/languages/swift';
import langKotlin from 'highlight.js/lib/languages/kotlin';
import langRuby from 'highlight.js/lib/languages/ruby';
import langPhp from 'highlight.js/lib/languages/php';
import langCsharp from 'highlight.js/lib/languages/csharp';
import langDiff from 'highlight.js/lib/languages/diff';
import langDockerfile from 'highlight.js/lib/languages/dockerfile';
import langNginx from 'highlight.js/lib/languages/nginx';
import langScala from 'highlight.js/lib/languages/scala';
import langPerl from 'highlight.js/lib/languages/perl';
import langR from 'highlight.js/lib/languages/r';
import langDart from 'highlight.js/lib/languages/dart';
import langLua from 'highlight.js/lib/languages/lua';
import langHaskell from 'highlight.js/lib/languages/haskell';
import langElixir from 'highlight.js/lib/languages/elixir';
import langGroovy from 'highlight.js/lib/languages/groovy';
import langVerilog from 'highlight.js/lib/languages/verilog';
import langVhdl from 'highlight.js/lib/languages/vhdl';
import langMakefile from 'highlight.js/lib/languages/makefile';
import langToml from 'highlight.js/lib/languages/ini';
import langProtobuf from 'highlight.js/lib/languages/protobuf';
import langGraphql from 'highlight.js/lib/languages/graphql';
import langPlaintext from 'highlight.js/lib/languages/plaintext';
import langPowershell from 'highlight.js/lib/languages/powershell';
import langObjectivec from 'highlight.js/lib/languages/objectivec';

hljs.registerLanguage('javascript', langJavascript);
hljs.registerLanguage('typescript', langTypescript);
hljs.registerLanguage('python', langPython);
hljs.registerLanguage('bash', langBash);
hljs.registerLanguage('shell', langShell);
hljs.registerLanguage('sql', langSql);
hljs.registerLanguage('json', langJson);
hljs.registerLanguage('yaml', langYaml);
hljs.registerLanguage('markdown', langMarkdown);
hljs.registerLanguage('css', langCss);
hljs.registerLanguage('xml', langXml);
hljs.registerLanguage('html', langXml);
hljs.registerLanguage('go', langGo);
hljs.registerLanguage('rust', langRust);
hljs.registerLanguage('java', langJava);
hljs.registerLanguage('c', langC);
hljs.registerLanguage('cpp', langCpp);
hljs.registerLanguage('swift', langSwift);
hljs.registerLanguage('kotlin', langKotlin);
hljs.registerLanguage('ruby', langRuby);
hljs.registerLanguage('php', langPhp);
hljs.registerLanguage('csharp', langCsharp);
hljs.registerLanguage('diff', langDiff);
hljs.registerLanguage('dockerfile', langDockerfile);
hljs.registerLanguage('nginx', langNginx);
hljs.registerLanguage('scala', langScala);
hljs.registerLanguage('perl', langPerl);
hljs.registerLanguage('r', langR);
hljs.registerLanguage('dart', langDart);
hljs.registerLanguage('lua', langLua);
hljs.registerLanguage('haskell', langHaskell);
hljs.registerLanguage('elixir', langElixir);
hljs.registerLanguage('groovy', langGroovy);
hljs.registerLanguage('verilog', langVerilog);
hljs.registerLanguage('vhdl', langVhdl);
hljs.registerLanguage('makefile', langMakefile);
hljs.registerLanguage('toml', langToml);
hljs.registerLanguage('ini', langToml);
hljs.registerLanguage('protobuf', langProtobuf);
hljs.registerLanguage('graphql', langGraphql);
hljs.registerLanguage('plaintext', langPlaintext);
hljs.registerLanguage('powershell', langPowershell);
hljs.registerLanguage('objectivec', langObjectivec);

const LANG_ALIASES: Record<string, string> = {
    'js': 'javascript',
    'ts': 'typescript',
    'py': 'python',
    'sh': 'bash',
    'rb': 'ruby',
    'kt': 'kotlin',
    'cs': 'csharp',
    'c++': 'cpp',
    'objc': 'objectivec',
    'ps1': 'powershell',
    'proto': 'protobuf',
    'gql': 'graphql',
    'mk': 'makefile',
    'text': 'plaintext',
    'hs': 'haskell',
    'ex': 'elixir',
    'exs': 'elixir',
};

function resolveLanguage(lang: string): string {
    const lower = lang.toLowerCase();
    return LANG_ALIASES[lower] ?? lower;
}

// @ts-ignore
import emoji from 'markdown-it-emoji';
// @ts-ignore
import footnote from 'markdown-it-footnote';
// @ts-ignore
import taskLists from 'markdown-it-task-lists';
// @ts-ignore
import mark from 'markdown-it-mark';
// @ts-ignore
import sub from 'markdown-it-sub';
// @ts-ignore
import sup from 'markdown-it-sup';
// @ts-ignore
import anchor from 'markdown-it-anchor';
import githubAlerts from 'markdown-it-github-alerts';

import { extractOutline } from './outline';
import { TableOfContents } from './table-of-contents';
import { SearchEngine } from './search';
import { SearchUI } from './search-ui';
import { HelpOverlay } from './help-overlay';

function extractFrontMatter(text: string): { yaml: string | null; body: string } {
    if (!text.startsWith('---')) {
        return { yaml: null, body: text };
    }
    const endIndex = text.indexOf('\n---', 3);
    if (endIndex === -1) {
        return { yaml: null, body: text };
    }
    const yaml = text.slice(3, endIndex).trim();
    const body = text.slice(endIndex + 4).trimStart();
    return { yaml, body };
}

function yamlValueToHtml(value: unknown): string {
    if (value === null || value === undefined) return '';
    if (Array.isArray(value)) {
        return '<ul>' + value.map(v => `<li>${escapeHtml(String(v))}</li>`).join('') + '</ul>';
    }
    if (typeof value === 'object') {
        return yamlObjectToTable(value as Record<string, unknown>);
    }
    return escapeHtml(String(value));
}

function yamlObjectToTable(obj: Record<string, unknown>): string {
    const rows = Object.entries(obj).map(([k, v]) => {
        const isComplex = v !== null && typeof v === 'object';
        return `<tr><th>${escapeHtml(k)}</th><td>${isComplex ? yamlValueToHtml(v) : escapeHtml(String(v ?? ''))}</td></tr>`;
    }).join('');
    return `<table class="yaml-frontmatter"><tbody>${rows}</tbody></table>`;
}

function renderFrontMatterHtml(yamlStr: string): string {
    try {
        const parsed = jsyaml.load(yamlStr);
        if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
            return `<pre class="hljs"><code class="language-yaml">${escapeHtml(yamlStr)}</code></pre>`;
        }
        return yamlObjectToTable(parsed as Record<string, unknown>);
    } catch {
        return `<pre class="hljs"><code class="language-yaml">${escapeHtml(yamlStr)}</code></pre>`;
    }
}

function buildMd(): MarkdownIt {
    const instance = new MarkdownIt({
        html: true,
        breaks: true,
        linkify: false,
        typographer: true,
        highlight: function (str: string, lang: string): string {
            const resolvedLang = resolveLanguage(lang);
            if (resolvedLang && hljs.getLanguage(resolvedLang)) {
                try {
                    return '<pre class="hljs"><code>' +
                        hljs.highlight(str, { language: resolvedLang, ignoreIllegals: true }).value +
                        '</code></pre>';
                } catch (__) { }
            }
            const codeClass = lang ? 'language-' + lang : '';
            return '<pre class="hljs"><code class="' + codeClass + '">' + instance.utils.escapeHtml(str) + '</code></pre>';
        }
    });

    const originalValidateLink = instance.validateLink.bind(instance);
    instance.validateLink = function(url: string): boolean {
        if (url.startsWith('data:') || url.startsWith('local-md://')) {
            return true;
        }
        return originalValidateLink(url);
    };

    instance.use(footnote);
    instance.use(taskLists);
    instance.use(mark);
    instance.use(sub);
    instance.use(sup);
    instance.use(anchor, {
        permalink: false,
        slugify: (s: string) => s.toLowerCase().replace(/[^\w\u4e00-\u9fa5]+/g, '-').replace(/^-+|-+$/g, '')
    });
    instance.use(githubAlerts);

    const defaultImageRender = instance.renderer.rules.image || function(tokens: any, idx: any, options: any, env: any, self: any) {
        return self.renderToken(tokens, idx, options);
    };

    instance.renderer.rules.image = function (tokens: any, idx: any, options: any, env: any, self: any) {
        const token = tokens[idx];
        const srcIndex = token.attrIndex('src');
        if (srcIndex >= 0) {
            const originalSrc = token.attrs[srcIndex][1];
            const isNetworkUrl = /^(http:\/\/|https:\/\/)/.test(originalSrc);
            const isEmbeddedBase64Image = originalSrc.startsWith('data:');
            const isLocalFile = !isNetworkUrl && !isEmbeddedBase64Image && !originalSrc.startsWith('local-md://');

            if (isLocalFile && env?.baseUrl) {
                const basePath = env.baseUrl.replace(/\/$/, '');
                const cleanSrc = originalSrc.startsWith('./') ? originalSrc.slice(2) : originalSrc;
                const absolutePath = cleanSrc.startsWith('/')
                    ? cleanSrc
                    : `${basePath}/${cleanSrc}`;
                token.attrs[srcIndex][1] = `local-md://${absolutePath}`;
            }
        }
        return defaultImageRender(tokens, idx, options, env, self);
    };

    return instance;
}

let md: MarkdownIt = buildMd();

function rebuildMd(): void {
    md = buildMd();
}

let toc: TableOfContents | null = null;
let searchEngine: SearchEngine | null = null;
let searchUI: SearchUI | null = null;
let helpOverlay: HelpOverlay | null = null;
let mermaidInstance: typeof import('mermaid')['default'] | null = null;
let mermaidCurrentTheme: string | null = null;
let katexPlugin: ((md: MarkdownIt) => void) | null = null;
let katexEnabled = false;
let emojiEnabled = false;
let graphvizInstance: { dot: (src: string) => string } | null = null;

interface RenderOptions {
    baseUrl?: string;
    theme?: string;
    imageData?: Record<string, string>;
    fontSize?: number;
    codeHighlightTheme?: string;
    enableMermaid?: boolean;
    enableKatex?: boolean;
    enableEmoji?: boolean;
    context?: 'quicklook' | 'app';
    uiLanguage?: string;
}

let currentContext: 'quicklook' | 'app' = 'app';

const HLJS_THEMES: Record<string, string> = {
    'github': `pre code.hljs{display:block;overflow-x:auto;padding:1em}code.hljs{padding:3px 5px}.hljs{color:#24292e;background:#fff}.hljs-doctag,.hljs-keyword,.hljs-meta .hljs-keyword,.hljs-template-tag,.hljs-template-variable,.hljs-type,.hljs-variable.language_{color:#d73a49}.hljs-title,.hljs-title.class_,.hljs-title.class_.inherited__,.hljs-title.function_{color:#6f42c1}.hljs-attr,.hljs-attribute,.hljs-literal,.hljs-meta,.hljs-number,.hljs-operator,.hljs-selector-attr,.hljs-selector-class,.hljs-selector-id,.hljs-variable{color:#005cc5}.hljs-meta .hljs-string,.hljs-regexp,.hljs-string{color:#032f62}.hljs-built_in,.hljs-symbol{color:#e36209}.hljs-code,.hljs-comment,.hljs-formula{color:#6a737d}.hljs-name,.hljs-quote,.hljs-selector-pseudo,.hljs-selector-tag{color:#22863a}.hljs-subst{color:#24292e}.hljs-section{color:#005cc5;font-weight:700}.hljs-bullet{color:#735c0f}.hljs-emphasis{color:#24292e;font-style:italic}.hljs-strong{color:#24292e;font-weight:700}.hljs-addition{color:#22863a;background-color:#f0fff4}.hljs-deletion{color:#b31d28;background-color:#ffeef0}`,
    'monokai': `pre code.hljs{display:block;overflow-x:auto;padding:1em}code.hljs{padding:3px 5px}.hljs{background:#272822;color:#ddd}.hljs-keyword,.hljs-literal,.hljs-name,.hljs-number,.hljs-selector-tag,.hljs-strong,.hljs-tag{color:#f92672}.hljs-code{color:#66d9ef}.hljs-attr,.hljs-attribute,.hljs-link,.hljs-regexp,.hljs-symbol{color:#bf79db}.hljs-addition,.hljs-built_in,.hljs-bullet,.hljs-emphasis,.hljs-section,.hljs-selector-attr,.hljs-selector-pseudo,.hljs-string,.hljs-subst,.hljs-template-tag,.hljs-template-variable,.hljs-title,.hljs-type,.hljs-variable{color:#a6e22e}.hljs-class .hljs-title,.hljs-title.class_{color:#fff}.hljs-comment,.hljs-deletion,.hljs-meta,.hljs-quote{color:#75715e}.hljs-doctag,.hljs-keyword,.hljs-literal,.hljs-section,.hljs-selector-id,.hljs-selector-tag,.hljs-title,.hljs-type{font-weight:700}`,
    'atom-one-dark': `pre code.hljs{display:block;overflow-x:auto;padding:1em}code.hljs{padding:3px 5px}.hljs{color:#abb2bf;background:#282c34}.hljs-comment,.hljs-quote{color:#5c6370;font-style:italic}.hljs-doctag,.hljs-formula,.hljs-keyword{color:#c678dd}.hljs-deletion,.hljs-name,.hljs-section,.hljs-selector-tag,.hljs-subst{color:#e06c75}.hljs-literal{color:#56b6c2}.hljs-addition,.hljs-attribute,.hljs-meta .hljs-string,.hljs-regexp,.hljs-string{color:#98c379}.hljs-attr,.hljs-number,.hljs-selector-attr,.hljs-selector-class,.hljs-selector-pseudo,.hljs-template-variable,.hljs-type,.hljs-variable{color:#d19a66}.hljs-bullet,.hljs-link,.hljs-meta,.hljs-selector-id,.hljs-symbol,.hljs-title{color:#61aeee}.hljs-built_in,.hljs-class .hljs-title,.hljs-title.class_{color:#e6c07b}.hljs-emphasis{font-style:italic}.hljs-strong{font-weight:700}.hljs-link{text-decoration:underline}`,
};

function applyCodeTheme(theme: string): void {
    const styleId = 'hljs-override-theme';
    let styleEl = document.getElementById(styleId) as HTMLStyleElement | null;
    const css = HLJS_THEMES[theme];
    if (css) {
        if (!styleEl) {
            styleEl = document.createElement('style');
            styleEl.id = styleId;
            document.head.appendChild(styleEl);
        }
        styleEl.textContent = css;
    } else {
        styleEl?.remove();
    }
}

declare global {
    interface Window {
        renderMarkdown: (text: string, options?: RenderOptions) => Promise<void>;
        renderSource: (text: string, theme: string) => void;
        exportHTML: () => string;
        setZoomLevel: (level: number) => void;
        showSearch: () => void;
        hideSearch: () => void;
        toggleSearch: () => void;
        showHelp: () => void;
        hideHelp: () => void;
        toggleHelp: () => void;
    }
}

async function renderVegaDiagrams(container: HTMLElement, theme: string): Promise<void> {
    const vegaBlocks = container.querySelectorAll('pre.hljs code.language-vega, pre.hljs code.language-vega-lite');
    if (vegaBlocks.length === 0) return;

    let vegaModule: typeof import('vega') | null = null;
    let vegaLiteModule: typeof import('vega-lite') | null = null;
    try {
        [vegaModule, vegaLiteModule] = await Promise.all([import('vega'), import('vega-lite')]);
    } catch (err) {
        logToSwift('[Vega] Failed to load modules: ' + err);
        return;
    }

    for (const block of vegaBlocks) {
        const pre = block.parentElement;
        if (!pre) continue;
        const isVegaLite = block.classList.contains('language-vega-lite');
        const src = block.textContent || '';
        try {
            const rawSpec = JSON.parse(src);
            const vegaSpec = isVegaLite ? vegaLiteModule!.compile(rawSpec).spec : rawSpec;
            const isDark = theme === 'dark';
            if (!vegaSpec.config) vegaSpec.config = {};
            vegaSpec.config.background = isDark ? '#0d1117' : '#ffffff';
            const runtime = vegaModule!.parse(vegaSpec);
            const view = new vegaModule!.View(runtime, { renderer: 'svg' });
            const svgStr = await view.toSVG();
            const wrapper = document.createElement('div');
            wrapper.className = 'vega-diagram';
            wrapper.innerHTML = svgStr;
            pre.replaceWith(wrapper);
        } catch (err: unknown) {
            const msg = err instanceof Error ? err.message : String(err);
            logToSwift(`[Vega] Render error: ${msg}`);
            const errDiv = document.createElement('div');
            errDiv.className = 'vega-error';
            errDiv.textContent = `Vega error: ${msg}`;
            pre.insertAdjacentElement('afterend', errDiv);
        }
    }
}

async function renderGraphvizDiagrams(container: HTMLElement): Promise<void> {
    const dotBlocks = container.querySelectorAll('pre.hljs code.language-dot, pre.hljs code.language-graphviz');
    if (dotBlocks.length === 0) return;

    if (!graphvizInstance) {
        try {
            const { Graphviz } = await import('@hpcc-js/wasm-graphviz');
            graphvizInstance = await Graphviz.load() as unknown as { dot: (src: string) => string };
        } catch (err) {
            logToSwift('[Graphviz] Failed to load wasm module: ' + err);
            return;
        }
    }

    for (const block of dotBlocks) {
        const pre = block.parentElement;
        if (!pre) continue;
        const src = (block.textContent || '').trim();

        if (!src) {
            const errDiv = document.createElement('div');
            errDiv.className = 'graphviz-error';
            errDiv.textContent = 'GraphViz error: empty diagram source';
            pre.insertAdjacentElement('afterend', errDiv);
            continue;
        }

        try {
            const svgStr = graphvizInstance!.dot(src);
            const wrapper = document.createElement('div');
            wrapper.className = 'graphviz-diagram';
            wrapper.innerHTML = svgStr;
            pre.replaceWith(wrapper);
        } catch (err: unknown) {
            const msg = err instanceof Error ? err.message : String(err);
            logToSwift(`[Graphviz] Render error: ${msg}`);
            const errDiv = document.createElement('div');
            errDiv.className = 'graphviz-error';
            errDiv.textContent = `GraphViz error: ${msg}`;
            pre.insertAdjacentElement('afterend', errDiv);
        }
    }
}

// Store loaded CSS text so exportHTML can use it synchronously
let cachedCssText = '';

async function preloadStylesheets() {
    cachedCssText = '';
    
    // Grab all <style> tags (like Vite's dev injected styles)
    const styleTags = document.querySelectorAll('style');
    styleTags.forEach(tag => {
        if (tag.innerHTML && !cachedCssText.includes(tag.innerHTML)) {
            cachedCssText += tag.innerHTML + '\n';
        }
    });

    // Fetch external stylesheets
    const links = document.querySelectorAll<HTMLLinkElement>('link[rel="stylesheet"]');
    for (let i = 0; i < links.length; i++) {
        const link = links[i];
        try {
            const response = await fetch(link.href);
            if (response.ok) {
                cachedCssText += await response.text() + '\n';
            }
        } catch (err) {
            logToSwift(`Warning: Could not fetch stylesheet ${link.href}: ${err}`);
        }
    }
}

// Call this early
setTimeout(preloadStylesheets, 500);

window.exportHTML = function(): string {
    // Collect all CSS rules into a single string
    let cssText = cachedCssText;
    
    // Also try to get any runtime CSS rules just in case
    try {
        const sheets = Array.from(document.styleSheets);
        for (const sheet of sheets) {
            try {
                if (sheet.cssRules) {
                    for (const rule of Array.from(sheet.cssRules)) {
                        if (!cssText.includes(rule.cssText)) {
                            cssText += rule.cssText + '\n';
                        }
                    }
                }
            } catch (e) {
                // Ignore CORS or access errors for cross-origin stylesheets
            }
        }
    } catch (e) {
        logToSwift(`Warning: Could not read stylesheets: ${e}`);
    }

    // Get the core rendered markdown content
    const previewDiv = document.getElementById('markdown-preview');
    // Ensure we clone the content so we don't modify the active DOM
    const clone = previewDiv ? (previewDiv.cloneNode(true) as HTMLElement) : document.createElement('div');
    
    // Force all relative image srcs to be absolute file:// or local-md:// URIs
    // so Swift can easily find and replace them with base64 data URIs
    const images = clone.querySelectorAll('img');
    images.forEach(img => {
        if (img.src && !img.src.startsWith('data:')) {
            img.setAttribute('src', img.src);
        }
    });
    // Build the final HTML document
    const finalHtml = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Exported Markdown</title>
    <style>
        /* Base document styles */
        body {
            margin: 0;
            padding: 20px;
            background-color: #ffffff;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji";
        }
        @media (prefers-color-scheme: dark) {
            body {
                background-color: #0d1117;
                color: #c9d1d9;
            }
        }
        .markdown-body {
            box-sizing: border-box;
            min-width: 200px;
            max-width: none;
            margin: 0 auto;
            padding: 45px;
        }
        @media (max-width: 767px) {
            .markdown-body {
                padding: 15px;
            }
        }
        
        /* Extracted application styles */
${cssText}
    </style>
</head>
<body>
    <div class="markdown-body">
${clone.innerHTML}
    </div>
</body>
</html>`;

    return finalHtml;
};

window.renderMarkdown = async function (text: string, options: RenderOptions = {}) {
    const outputDiv = document.getElementById('markdown-preview');
    const loadingDiv = document.getElementById('loading-status');

    if (loadingDiv) loadingDiv.style.display = 'none';

    if (!outputDiv) {
        logToSwift("JS Error: markdown-preview element not found");
        return;
    }

    if (options.fontSize) {
        outputDiv.style.fontSize = options.fontSize + 'px';
    }

    applyCodeTheme(options.codeHighlightTheme || 'default');

    if (options.baseUrl) {
        let existingBase = document.querySelector('base');
        if (!existingBase) {
            existingBase = document.createElement('base');
            document.head.insertBefore(existingBase, document.head.firstChild);
        }
        const baseHref = options.baseUrl.endsWith('/') ? options.baseUrl : options.baseUrl + '/';
        existingBase.setAttribute('href', 'file://' + baseHref);
    }

    if (options.context) {
        currentContext = options.context;
        (window as any).__fluxContext = currentContext;
    }

    if (options.uiLanguage) {
        (window as any).__fluxLang = options.uiLanguage === 'system' ? undefined : options.uiLanguage;
    }

    let currentTheme = options.theme || 'default';
    if (currentTheme === 'system') {
        currentTheme = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default';
    } else if (currentTheme === 'light') {
        currentTheme = 'default';
    }
    const mermaidTheme = currentTheme === 'dark' ? 'dark' : 'default';

    try {
        if (!toc) {
            try { toc = new TableOfContents('toc-container'); } catch (e) {
                logToSwift("JS Warning: TOC initialization failed: " + e);
            }
        }
        if (!searchEngine || !searchUI) {
            try {
                searchEngine = new SearchEngine();
                searchUI = new SearchUI('search-container', searchEngine);
            } catch (e) {
                logToSwift("JS Warning: Search initialization failed: " + e);
            }
        }
        if (!helpOverlay) {
            try {
                helpOverlay = new HelpOverlay();
            } catch (e) {
                logToSwift("JS Warning: HelpOverlay initialization failed: " + e);
            }
        }

        const { yaml, body } = extractFrontMatter(text);
        const frontMatterHtml = yaml ? renderFrontMatterHtml(yaml) : '';

        const enableEmoji = options.enableEmoji !== false;
        if (enableEmoji && !emojiEnabled) {
            md.use(emoji);
            emojiEnabled = true;
        }
        if (!enableEmoji && emojiEnabled) {
            rebuildMd();
            emojiEnabled = false;
            katexEnabled = false;
        }

        const enableKatex = options.enableKatex !== false;
        if (enableKatex && !katexEnabled && /\$[\s\S]+?\$|\$\$[\s\S]+?\$\$/.test(body)) {
            if (!katexPlugin) {
                const m = await import('@iktakahiro/markdown-it-katex');
                katexPlugin = (m as any).default ?? m;
            }
            md.use(katexPlugin as (md: MarkdownIt) => void);
            katexEnabled = true;
        }

        if (!enableKatex && katexEnabled) {
            rebuildMd();
            katexEnabled = false;
            emojiEnabled = false;
        }

        const renderBody = body;

        const outline = extractOutline(md, renderBody);
        if (toc) toc.render(outline);

        let html = md.render(renderBody, { baseUrl: options.baseUrl });

        if (options.imageData) {
            for (const [originalPath, dataUrl] of Object.entries(options.imageData)) {
                html = html.split(escapeHtml(originalPath)).join(dataUrl);
                html = html.split(originalPath).join(dataUrl);
            }
        }

        const tempDiv = document.createElement('div');
        tempDiv.innerHTML = frontMatterHtml + html;

        const enableMermaid = options.enableMermaid !== false;
        const mermaidBlocks = enableMermaid
            ? tempDiv.querySelectorAll('pre code.language-mermaid')
            : ([] as unknown as NodeListOf<Element>);

        mermaidBlocks.forEach((block, index) => {
            const pre = block.parentElement;
            if (pre) {
                const div = document.createElement('div');
                div.classList.add('mermaid');
                div.textContent = block.textContent || '';
                div.id = `mermaid-${index}`;
                pre.replaceWith(div);
            }
        });

        outputDiv.innerHTML = tempDiv.innerHTML;

        if (mermaidBlocks.length > 0) {
            try {
                if (!mermaidInstance) {
                    const mermaidModule = await import('mermaid');
                    mermaidInstance = mermaidModule.default;
                }
                const mermaid = mermaidInstance;
                if (mermaidCurrentTheme !== mermaidTheme) {
                    mermaid.initialize({ startOnLoad: false, theme: mermaidTheme as any, suppressErrorRendering: true });
                    mermaidCurrentTheme = mermaidTheme;
                }

                const mermaidDivs = outputDiv.querySelectorAll('.mermaid');
                for (const div of mermaidDivs) {
                    const code = div.textContent || '';
                    const processedCode = preprocessMermaidNewlines(code);
                    const id = div.id || `mermaid-${Date.now()}`;
                    try {
                        const { svg } = await mermaid.render(id + '-svg', processedCode);
                        div.innerHTML = svg;
                    } catch (renderErr: any) {
                        const errorMessage = renderErr?.message || String(renderErr);
                        logToSwift(`JS Mermaid render error for ${id}: ${errorMessage}`);
                        div.innerHTML = `<div class="mermaid-error" style="background-color:#fff5f5;border:1px solid #feb2b2;border-radius:6px;padding:16px;">
                            <div style="color:#c53030;font-weight:600;margin-bottom:8px;">⚠️ Mermaid Syntax Error</div>
                            <pre style="background-color:#fed7d7;color:#742a2a;padding:12px;border-radius:4px;overflow-x:auto;font-size:13px;margin:0 0 12px 0;white-space:pre-wrap;">${escapeHtml(errorMessage)}</pre>
                            <details><summary style="cursor:pointer;color:#718096;font-size:12px;">Show source code</summary>
                            <pre style="background-color:#f7fafc;color:#2d3748;padding:12px;border-radius:4px;margin-top:8px;overflow-x:auto;font-size:12px;white-space:pre-wrap;">${escapeHtml(code)}</pre></details>
                        </div>`;
                    }
                }
            } catch (err) {
                logToSwift("JS Error loading/running mermaid: " + err);
            }
        }

        await renderVegaDiagrams(outputDiv, currentTheme);
        await renderGraphvizDiagrams(outputDiv);

        setTimeout(() => {
            if (!mermaidInstance) {
                import('mermaid').then(m => { mermaidInstance = m.default; });
            }
        }, 0);

    } catch (e) {
        logToSwift("JS Error during render: " + e);
        if (outputDiv) {
            outputDiv.innerHTML = `<div style="color:red;padding:20px;border:1px solid red;border-radius:5px;"><h3>Rendering Error</h3><pre>${e}</pre></div>`;
        }
    }
};

window.renderSource = function(text: string, theme: string) {
    const outputDiv = document.getElementById('markdown-preview');
    const loadingDiv = document.getElementById('loading-status');

    if (loadingDiv) loadingDiv.style.display = 'none';

    if (!outputDiv) {
        logToSwift("JS Error: markdown-preview element not found");
        return;
    }

    try {
        const highlighted = hljs.highlight(text, { language: 'markdown', ignoreIllegals: true });
        outputDiv.innerHTML = `<div class="source-view ${theme === 'dark' ? 'source-view-dark' : 'source-view-light'}"><pre class="source-pre"><code class="hljs language-markdown">${highlighted.value}</code></pre></div>`;
        logToSwift(`[Source View] Rendered ${text.length} characters with theme: ${theme}`);
    } catch (e) {
        logToSwift("JS Error during source rendering: " + e);
        if (outputDiv) {
            outputDiv.innerHTML = `<div style="color:red;padding:20px;border:1px solid red;border-radius:5px;"><h3>Source Rendering Error</h3><pre>${e}</pre></div>`;
        }
    }
};

function compressMultipleHyphens(text: string): string {
    return text.replace(/-+/g, '-');
}

function unifyUnderscoreAndHyphen(text: string): string {
    return text.replace(/[_-]/g, '~');
}

function stripHyphens(text: string): string {
    return text.toLowerCase().replace(/-/g, '');
}

function stripHyphensAndUnderscores(text: string): string {
    return text.toLowerCase().replace(/[-_]/g, '');
}

function findElementByAnchor(anchorId: string): HTMLElement | null {
    const allElementsWithId = document.querySelectorAll('[id]');
    const exactMatch = document.getElementById(anchorId);
    if (exactMatch) return exactMatch;

    const level2Target = compressMultipleHyphens(anchorId);
    for (const element of allElementsWithId) {
        const id = element.getAttribute('id');
        if (id && compressMultipleHyphens(id) === level2Target) return element as HTMLElement;
    }

    const level3Target = unifyUnderscoreAndHyphen(compressMultipleHyphens(anchorId));
    for (const element of allElementsWithId) {
        const id = element.getAttribute('id');
        if (id && unifyUnderscoreAndHyphen(compressMultipleHyphens(id)) === level3Target) return element as HTMLElement;
    }

    // Level 4: strip all hyphens, then compare (handles AI-generated anchors that omit
    // hyphens at CJK/ASCII boundaries, e.g. '故障-6镜像' vs actual '故障-6-镜像')
    const level4Target = stripHyphens(anchorId);
    for (const element of allElementsWithId) {
        const id = element.getAttribute('id');
        if (id && stripHyphens(id) === level4Target) return element as HTMLElement;
    }

    // Level 5: strip all hyphens and underscores (most permissive fallback)
    const level5Target = stripHyphensAndUnderscores(anchorId);
    for (const element of allElementsWithId) {
        const id = element.getAttribute('id');
        if (id && stripHyphensAndUnderscores(id) === level5Target) return element as HTMLElement;
    }

    return null;
}

function handleAnchorClick(e: Event) {
    const target = e.target as HTMLElement;
    const anchor = target.closest('a');
    if (!anchor) return;
    const href = anchor.getAttribute('href');
    if (!href) return;

    logToSwift(`[Click] href="${href}"`);

    if (href.startsWith('#')) {
        e.preventDefault();
        e.stopPropagation();
        const targetId = decodeURIComponent(href.substring(1));
        const targetElement = findElementByAnchor(targetId);
        if (targetElement) {
            targetElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
        return;
    }

    e.preventDefault();
    e.stopPropagation();

    try {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.linkClicked) {
            // @ts-ignore
            window.webkit.messageHandlers.linkClicked.postMessage(href);
        }
    } catch (error) {
        logToSwift(`[Click] ERROR: ${error}`);
    }
}

document.addEventListener('click', handleAnchorClick, { capture: true, passive: false });

function getLinkStatusText(anchor: HTMLAnchorElement): string | null {
    const href = anchor.getAttribute('href');
    if (!href || href === '#') return null;

    let decoded = href;
    try { decoded = decodeURIComponent(href); } catch { /* malformed encoding — keep raw */ }

    const displayText = anchor.textContent?.trim() ?? '';
    if (displayText === decoded || displayText === href) return null;

    try {
        const url = new URL(href);
        if (displayText === url.host || displayText === url.hostname) return null;
    } catch {
        // relative href or anchor — not a valid absolute URL, that's fine
    }

    return decoded;
}

function getStatusIcon(href: string): string {
    if (href.startsWith('#')) return '⚓';
    if (href.startsWith('mailto:')) return '✉️';
    return '🔗';
}

let _statusBarEl: HTMLElement | null = null;
function getStatusBar(): HTMLElement | null {
    if (!_statusBarEl) {
        _statusBarEl = document.getElementById('link-status-bar');
    }
    return _statusBarEl;
}

function handleAnchorMouseOver(e: MouseEvent) {
    const target = e.target as HTMLElement;
    const anchor = target.closest('a') as HTMLAnchorElement | null;
    const bar = getStatusBar();
    if (!bar || !anchor) return;

    const linkTarget = getLinkStatusText(anchor);
    if (linkTarget) {
        const icon = getStatusIcon(linkTarget);
        bar.innerHTML = `<span class="status-icon">${icon}</span>${escapeHtml(linkTarget)}`;
        bar.classList.add('visible');
    }
}

function handleAnchorMouseOut(e: MouseEvent) {
    const bar = getStatusBar();
    if (!bar) return;

    const target = e.target as HTMLElement;
    const anchor = target.closest('a');
    if (!anchor) return;

    const relatedTarget = e.relatedTarget as HTMLElement | null;
    if (relatedTarget && anchor.contains(relatedTarget)) return;

    bar.classList.remove('visible');
}

document.addEventListener('mouseover', handleAnchorMouseOver);
document.addEventListener('mouseout', handleAnchorMouseOut);

let currentZoomLevel = 1.0;

window.setZoomLevel = function(level: number) {
    currentZoomLevel = level;
    const outputDiv = document.getElementById('markdown-preview');
    if (outputDiv) {
        outputDiv.style.transform = `scale(${level})`;
        outputDiv.style.transformOrigin = 'top left';
        outputDiv.style.width = `${100 / level}%`;
    }
};

function applyZoomLevel(level: number) {
    currentZoomLevel = Math.max(0.5, Math.min(3.0, level));
    window.setZoomLevel(currentZoomLevel);
}

document.addEventListener('keydown', (e: KeyboardEvent) => {
    if (e.metaKey || e.ctrlKey) {
        if (e.key === 'f') { e.preventDefault(); window.toggleSearch(); }
        else if (e.key === '+' || e.key === '=') { e.preventDefault(); applyZoomLevel(currentZoomLevel + 0.1); }
        else if (e.key === '-' || e.key === '_') { e.preventDefault(); applyZoomLevel(currentZoomLevel - 0.1); }
        else if (e.key === '0') { e.preventDefault(); applyZoomLevel(1.0); }
    }
});

window.showSearch = function() { if (searchUI) searchUI.show(); };
window.hideSearch = function() { if (searchUI) searchUI.hide(); };
window.toggleSearch = function() { if (searchUI) searchUI.toggle(); };

window.showHelp = function() { if (helpOverlay) helpOverlay.show(); };
window.hideHelp = function() { if (helpOverlay) helpOverlay.hide(); };
window.toggleHelp = function() { if (helpOverlay) helpOverlay.toggle(); };

logToSwift("rendererReady");
