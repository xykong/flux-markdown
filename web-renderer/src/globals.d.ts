declare module 'vega-lite' {
    export function compile(spec: any, options?: any): { spec: any };
}

declare module '@iktakahiro/markdown-it-katex' {
    import MarkdownIt from 'markdown-it';
    const plugin: (md: MarkdownIt) => void;
    export default plugin;
}

interface WebkitMessageHandlers {
    blockCopy?: { postMessage: (request: { id: string; generation: string; text: string }) => void };
    errorFeedback?: { postMessage: (event: { action: string; kind: string; generation: string; id: string; reason?: string }) => void };
    readingToolsLayout?: { postMessage: (layout: { rightInset: number }) => void };
    logger: { postMessage: (msg: string) => void };
    linkClicked: { postMessage: (href: string) => void };
}

interface Window {
    webkit?: {
        messageHandlers: WebkitMessageHandlers;
    };
}

declare module '*?url' {
    const url: string;
    export default url;
}
