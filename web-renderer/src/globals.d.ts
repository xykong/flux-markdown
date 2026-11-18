declare module 'markdown-it-emoji/lib/data/full.json' {
    const definitions: Record<string, string>;
    export default definitions;
}

declare module 'markdown-it-emoji/lib/data/shortcuts' {
    const shortcuts: Record<string, string[]>;
    export default shortcuts;
}

declare module 'markdown-it-emoji' {
    import MarkdownIt from 'markdown-it';
    const plugin: (md: MarkdownIt) => void;
    export default plugin;
}

declare module 'vega-lite' {
    export function compile(spec: any, options?: any): { spec: any };
}

declare module '@iktakahiro/markdown-it-katex' {
    import MarkdownIt from 'markdown-it';
    const plugin: (md: MarkdownIt) => void;
    export default plugin;
}

interface WebkitMessageHandlers {
    readingJourney?: { postMessage: (request: Record<string, unknown>) => void };
    diagramAction?: { postMessage: (request: Record<string, unknown>) => void };
    blockCopy?: { postMessage: (request: { id: string; generation: string; text: string }) => void };
    errorFeedback?: { postMessage: (event: { action: string; kind: string; generation: string; id: string; reason?: string; lineStart?: number; lineEnd?: number }) => void };
    readingToolsLayout?: { postMessage: (layout: { rightInset: number }) => void };
    logger: { postMessage: (msg: string) => void };
    linkClicked: { postMessage: (href: string) => void };
}


interface Window {
    setQuickLookFollow: (enabled: boolean) => void;
    quickLookFollowStatus: () => {active:boolean;paused:boolean;selected:boolean;copying?:boolean};
    quickLookFollowWaiting?: (on: boolean) => void;
    webkit?: {
        messageHandlers: WebkitMessageHandlers;
    };
}

declare module '*?url' {
    const url: string;
    export default url;
}


declare module 'markdown-it-deflist' {
    import type { PluginSimple } from 'markdown-it';
    const plugin: PluginSimple;
    export default plugin;
}
declare module 'markdown-it-abbr' {
    import type { PluginSimple } from 'markdown-it';
    const plugin: PluginSimple;
    export default plugin;
}
declare module 'markdown-it-ins' {
    import type { PluginSimple } from 'markdown-it';
    const plugin: PluginSimple;
    export default plugin;
}
