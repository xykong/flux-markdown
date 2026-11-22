import './styles/reading-workflow.css';
const strings = {
    en: ['Document','Diagram','Focus diagram','Fit to Window','100%','Close','Copy PNG','Save PNG','Save SVG','Back','Forward','Copied','Saved','Cancelled','Open in FluxMarkdown to save','Pinch over text to zoom the document; pinch over a diagram to zoom only that diagram. Two-finger double-tap restores local 100%; the document zoom is preserved.','Preparing…'],
    zh: ['文档','图表','专注查看图表','适应窗口','100%','关闭','复制 PNG','保存 PNG','保存 SVG','后退','前进','已复制','已保存','已取消','在 FluxMarkdown 中打开以保存','在正文上双指缩放调整文档；在图上双指缩放只调整该图。双指双击恢复图表局部 100%，保留文档倍率。','正在准备…'],
    de: ['Dokument','Diagramm','Diagramm fokussieren','An Fenster anpassen','100%','Schließen','PNG kopieren','PNG speichern','SVG speichern','Zurück','Vorwärts','Kopiert','Gespeichert','Abgebrochen','Zum Speichern in FluxMarkdown öffnen','Über Text zoomen Sie das Dokument, über einem Diagramm nur das Diagramm. Zweifinger-Doppeltipp setzt lokal auf 100% zurück; der Dokumentzoom bleibt erhalten.','Wird vorbereitet…'],
    fr: ['Document','Diagramme','Isoler le diagramme','Adapter à la fenêtre','100%','Fermer','Copier PNG','Enregistrer PNG','Enregistrer SVG','Précédent','Suivant','Copié','Enregistré','Annulé','Ouvrir dans FluxMarkdown pour enregistrer','Pincez le texte pour zoomer le document, un diagramme pour zoomer seulement celui-ci. Un double toucher à deux doigts rétablit 100% localement sans modifier le zoom du document.','Préparation…'],
    es: ['Documento','Diagrama','Ver diagrama','Ajustar a la ventana','100%','Cerrar','Copiar PNG','Guardar PNG','Guardar SVG','Atrás','Adelante','Copiado','Guardado','Cancelado','Abrir en FluxMarkdown para guardar','Pellizca sobre texto para ampliar el documento; sobre un diagrama, solo ese diagrama. Un doble toque con dos dedos restablece el 100% local y conserva el zoom del documento.','Preparando…'],
    ar: ['المستند','المخطط','عرض المخطط','ملاءمة النافذة','100%','إغلاق','نسخ PNG','حفظ PNG','حفظ SVG','رجوع','تقدم','تم النسخ','تم الحفظ','أُلغي','افتح في FluxMarkdown للحفظ','كبّر النص بإصبعين لتغيير المستند، أو المخطط لتغييره وحده. النقر المزدوج بإصبعين يعيد المخطط إلى 100% مع الحفاظ على تكبير المستند.','جارٍ التحضير…'],
};
export function workflowLabels() {
    const language=(window.__fluxLang || navigator.language || 'en').split('-')[0];
    const s=strings[language as keyof typeof strings] || strings.en;
    return { document:s[0],diagram:s[1],focus:s[2],fit:s[3],actual:s[4],close:s[5],copy:s[6],png:s[7],svg:s[8],back:s[9],forward:s[10],copied:s[11],saved:s[12],cancelled:s[13],openApp:s[14],gestures:s[15],preparing:s[16] };
}
let hide: ReturnType<typeof setTimeout> | undefined;
export function showWorkflowStatus(text: string): void {
    let hud=document.getElementById('zoom-feedback');
    if(!hud) {
        hud=document.createElement('div');hud.id='zoom-feedback';hud.setAttribute('role','status');hud.setAttribute('aria-live','polite');document.body.append(hud);
    }
    hud.textContent=text;hud.hidden=false;
    clearTimeout(hide);hide=setTimeout(()=>{if(hud)hud.hidden=true;},1200);
}
export function showZoomFeedback(level: number, target: 'document' | 'diagram'): void {
    if(Number.isFinite(level))showWorkflowStatus(`${workflowLabels()[target]} ${Math.round(level*100)}%`);
}
export function workflowButton(label: string, action: () => void): HTMLButtonElement {
    const button=document.createElement('button');button.type='button';button.textContent=label;button.title=label;button.setAttribute('aria-label',label);button.addEventListener('click',event=>{event.preventDefault();event.stopPropagation();action();});return button;
}
