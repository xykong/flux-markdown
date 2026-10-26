declare global { interface Window { __fluxLang?: string; } }

export type RendererLabels = {
    typstLoading: string;
    typstRenderError: string;
    mermaidSyntaxError: string;
    showSourceCode: string;
    graphvizError: string;
    emptyGraphvizSource: string;
    renderingError: string;
    sourceRenderingError: string;
};

const labels: Record<string, RendererLabels> = {
    en: { typstLoading: 'Rendering Typst…', typstRenderError: '⚠️ Typst Render Error', mermaidSyntaxError: '⚠️ Mermaid Syntax Error', showSourceCode: 'Show source code', graphvizError: 'GraphViz error', emptyGraphvizSource: 'empty diagram source', renderingError: 'Rendering Error', sourceRenderingError: 'Source Rendering Error' },
    zh: { typstLoading: '正在渲染 Typst…', typstRenderError: '⚠️ Typst 渲染错误', mermaidSyntaxError: '⚠️ Mermaid 语法错误', showSourceCode: '显示源代码', graphvizError: 'GraphViz 错误', emptyGraphvizSource: '图表源为空', renderingError: '渲染错误', sourceRenderingError: '源码渲染错误' },
    de: { typstLoading: 'Typst wird gerendert…', typstRenderError: '⚠️ Typst-Renderfehler', mermaidSyntaxError: '⚠️ Mermaid-Syntaxfehler', showSourceCode: 'Quellcode anzeigen', graphvizError: 'GraphViz-Fehler', emptyGraphvizSource: 'leere Diagrammquelle', renderingError: 'Renderfehler', sourceRenderingError: 'Quellcode-Renderfehler' },
    fr: { typstLoading: 'Rendu Typst…', typstRenderError: '⚠️ Erreur de rendu Typst', mermaidSyntaxError: '⚠️ Erreur de syntaxe Mermaid', showSourceCode: 'Afficher le code source', graphvizError: 'Erreur GraphViz', emptyGraphvizSource: 'source de diagramme vide', renderingError: 'Erreur de rendu', sourceRenderingError: 'Erreur de rendu du code source' },
    es: { typstLoading: 'Renderizando Typst…', typstRenderError: '⚠️ Error de renderizado de Typst', mermaidSyntaxError: '⚠️ Error de sintaxis de Mermaid', showSourceCode: 'Mostrar código fuente', graphvizError: 'Error de GraphViz', emptyGraphvizSource: 'fuente de diagrama vacía', renderingError: 'Error de renderizado', sourceRenderingError: 'Error de renderizado del código fuente' },
    ar: { typstLoading: 'جارٍ عرض Typst…', typstRenderError: '⚠️ خطأ في عرض Typst', mermaidSyntaxError: '⚠️ خطأ في صياغة Mermaid', showSourceCode: 'عرض الشيفرة المصدرية', graphvizError: 'خطأ GraphViz', emptyGraphvizSource: 'مصدر المخطط فارغ', renderingError: 'خطأ في العرض', sourceRenderingError: 'خطأ في عرض الشيفرة المصدرية' },
};

export function rendererLabels(): RendererLabels {
    const language = (window.__fluxLang || navigator.language || 'en').split('-')[0];
    return labels[language] || labels.en;
}
