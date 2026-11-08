type ErrorKind = 'renderer' | 'source' | 'mermaid' | 'typst' | 'graphviz' | 'vega' | 'math' | 'search' | 'images' | 'copy';
let generation = '';
export function feedbackGeneration(): string { return generation; }
let nextID = 0;
const groupIDs = new Map<string, string>();
export function setFeedbackGeneration(value: string): void {
    if (value !== generation) groupIDs.clear();
    generation = value;
}
const translations: Record<string, [string, string, string, string, string]> = {
    en: ['Report This Problem', 'Review Feedback…', 'Check the source in your editor, or try reloading the document.', 'Opens GitHub with this error and system information. You confirm publication there.', 'Open FluxMarkdown and choose Help → Report an Issue.'],
    zh: ['反馈此问题', '查看反馈内容…', '可以在编辑器中检查源内容，或尝试重新载入文档。', '将打开 GitHub，附带本次错误和系统信息，由你确认发布。', '请打开 FluxMarkdown，选择“帮助 → 报告问题”。'],
    de: ['Dieses Problem melden', 'Feedback prüfen…', 'Prüfe die Quelle im Editor oder lade das Dokument erneut.', 'Öffnet GitHub mit diesem Fehler und Systeminformationen. Du bestätigst die Veröffentlichung dort.', 'Öffne FluxMarkdown und wähle Hilfe → Problem melden.'],
    fr: ['Signaler ce problème', 'Vérifier le rapport…', 'Vérifiez la source dans votre éditeur ou rechargez le document.', 'Ouvre GitHub avec cette erreur et les informations système. Vous y confirmez la publication.', 'Ouvrez FluxMarkdown, puis Aide → Signaler un problème.'],
    es: ['Reportar este problema', 'Revisar informe…', 'Revisa el contenido en tu editor o vuelve a cargar el documento.', 'Abre GitHub con este error y la información del sistema. Allí confirmas la publicación.', 'Abre FluxMarkdown y elige Ayuda → Reportar un Problema.'],
    ar: ['الإبلاغ عن هذه المشكلة', 'مراجعة الملاحظات…', 'تحقق من المصدر في محررك، أو جرّب إعادة تحميل المستند.', 'يفتح GitHub مع هذا الخطأ ومعلومات النظام. أنت تؤكد النشر هناك.', 'افتح FluxMarkdown واختر «مساعدة» ثم «الإبلاغ عن مشكلة».'],
};
const selectors: Array<[string, ErrorKind]> = [
    ['.block-copy-error', 'copy'], ['.mermaid-error', 'mermaid'], ['.typst-error', 'typst'], ['.graphviz-error', 'graphviz'], ['.vega-error', 'vega'],
    ['.math-error', 'math'], ['.katex-error', 'math'], ['.search-error', 'search'], ['.render-error', 'renderer'], ['.source-render-error', 'source'], ['img.image-load-failed', 'images'],
];

export function installErrorFeedback(root: HTMLElement): () => void {
    const attached = new WeakMap<Element, string>();
    const externalControls = new Map<HTMLElement, HTMLElement>();
    function scan(): void {
        for (const [element, controls] of externalControls) {
            if (!root.contains(element) || (element.tagName === 'IMG' && !element.classList.contains('image-load-failed'))) {
                controls.remove(); externalControls.delete(element); attached.delete(element);
            }
        }
        for (const [selector, kind] of selectors) {
            root.querySelectorAll<HTMLElement>(selector).forEach(element => {
                if (!generation || element.style.display === 'none') return;
                if (attached.get(element) === generation && (element.querySelector('.error-feedback-controls') || externalControls.get(element)?.isConnected)) return;
                attached.set(element, generation);
                const eventGeneration = generation;
                // Equivalent module failures in one document share a bounded incident.
                const reason = element.classList.contains('module-load-error') ? 'moduleUnavailable' : kind === 'images' || element.classList.contains('math-resource-unsupported') ? 'resourceUnavailable' : kind === 'search' ? 'invalidInput' : 'operationFailed';
                const group = kind + ':' + reason;
                const id = groupIDs.get(group) || String(++nextID);
                groupIDs.set(group, id);
                const labels = translations[(window.__fluxLang || navigator.language).split('-')[0]] || translations.en;
                const controls = document.createElement('div'); controls.className = 'error-feedback-controls';
                controls.style.cssText = 'display:flex;flex-wrap:wrap;gap:8px;margin:10px 0;font:13px system-ui;';
                const hint = document.createElement('span'); hint.textContent = labels[2]; hint.style.width = '100%';
                if (element.classList.contains('math-input-limit')) {
                    const limitHints: Record<string, string> = {
                        en: 'This formula exceeds the preview limit. Open the document in your editor to simplify it or split the document. The original source is preserved.',
                        zh: '公式超出预览限制。可在编辑器中简化公式或拆分文档；原始源码已保留。',
                        de: 'Diese Formel überschreitet das Vorschaulimit. Öffne das Dokument im Editor, um sie zu vereinfachen oder das Dokument aufzuteilen. Der Quelltext bleibt erhalten.',
                        fr: 'Cette formule dépasse la limite de prévisualisation. Ouvrez le document dans votre éditeur pour la simplifier ou diviser le document. La source est conservée.',
                        es: 'Esta fórmula supera el límite de vista previa. Abre el documento en tu editor para simplificarla o dividir el documento. Se conserva el código original.',
                        ar: 'تتجاوز هذه الصيغة حد المعاينة. افتح المستند في المحرر لتبسيطها أو تقسيم المستند. تم الاحتفاظ بالمصدر الأصلي.',
                    };
                    hint.textContent = limitHints[(window.__fluxLang || navigator.language).split('-')[0]] || limitHints.en;
                }
                if (element.classList.contains('math-resource-unsupported')) {
                    const hints: Record<string, string> = {
                        en: 'This formula contains an image resource that mathematical previews do not support. Open the document in your editor to use a text formula or a separate image. The original source is preserved.',
                        zh: '该公式包含数学预览暂不支持的图片资源。请在编辑器中改用文字公式，或将图片单独插入文档。原始源码已保留。',
                        de: 'Diese Formel enthält eine Bildressource, die die mathematische Vorschau nicht unterstützt. Öffne das Dokument im Editor und verwende eine Textformel oder ein separates Bild. Der Quelltext bleibt erhalten.',
                        fr: 'Cette formule contient une image non prise en charge par l’aperçu mathématique. Ouvrez le document dans votre éditeur pour utiliser une formule textuelle ou une image séparée. La source est conservée.',
                        es: 'Esta fórmula contiene una imagen que la vista previa matemática no admite. Abre el documento en tu editor para usar una fórmula de texto o una imagen independiente. Se conserva el código original.',
                        ar: 'تحتوي هذه الصيغة على صورة لا تدعمها المعاينة الرياضية. افتح المستند في المحرر لاستخدام صيغة نصية أو صورة منفصلة. تم الاحتفاظ بالمصدر الأصلي.',
                    };
                    hint.textContent = hints[(window.__fluxLang || navigator.language).split('-')[0]] || hints.en;
                }
                if (kind === 'search') {
                    const searchHints: Record<string, string> = { en: 'Check the search expression, or turn off regular expression search.', zh: '请检查搜索表达式，或关闭正则表达式搜索。', de: 'Prüfe den Suchausdruck oder deaktiviere die Regex-Suche.', fr: 'Vérifiez l’expression ou désactivez la recherche par expression régulière.', es: 'Revisa la expresión o desactiva la búsqueda con expresiones regulares.', ar: 'تحقق من تعبير البحث، أو أوقف البحث بالتعبيرات النمطية.' };
                    hint.textContent = searchHints[(window.__fluxLang || navigator.language).split('-')[0]] || searchHints.en;
                }
                if (reason === 'moduleUnavailable') {
                    const reloadHints: Record<string, string> = { en: 'Reload the document. If this continues, download and reinstall FluxMarkdown.', zh: '请重载文档；如果仍然失败，可以下载并重新安装 FluxMarkdown。', de: 'Lade das Dokument erneut. Falls das Problem bleibt, lade FluxMarkdown herunter und installiere es erneut.', fr: 'Rechargez le document. Si le problème persiste, téléchargez et réinstallez FluxMarkdown.', es: 'Vuelve a cargar el documento. Si el problema persiste, descarga y reinstala FluxMarkdown.', ar: 'أعد تحميل المستند. إذا استمر ذلك، نزّل FluxMarkdown وأعد تثبيته.' };
                    hint.textContent = reloadHints[(window.__fluxLang || navigator.language).split('-')[0]] || reloadHints.en;
                }
                if (kind !== 'copy') controls.appendChild(hint);
                const post = (action: 'record' | 'report' | 'inspect' | 'recover'): void => {
                    if (generation !== eventGeneration || !root.contains(element)) return;
                    const bridge = window.webkit?.messageHandlers.errorFeedback;
                    if (bridge) bridge.postMessage({ action, kind, generation: eventGeneration, id, reason });
                    else if (action !== 'record') { hint.textContent = labels[4]; if (!hint.isConnected) controls.prepend(hint); }
                };
                const recoveryLabels: Record<string, [string, string, string]> = {
                    en: ['Open in Editor', 'Reload', 'Edit Search'], zh: ['在编辑器中打开', '重新载入', '修改搜索'],
                    de: ['Im Editor öffnen', 'Neu laden', 'Suche bearbeiten'], fr: ['Ouvrir dans l’éditeur', 'Recharger', 'Modifier la recherche'],
                    es: ['Abrir en el editor', 'Volver a cargar', 'Editar búsqueda'],
                    ar: ['فتح في المحرر', 'إعادة التحميل', 'تعديل البحث'],
                };
                const recoveryText = recoveryLabels[(window.__fluxLang || navigator.language).split('-')[0]] || recoveryLabels.en;
                const recovery = document.createElement('button'); recovery.type = 'button'; recovery.dataset.feedbackAction = 'recover';
                recovery.textContent = kind === 'search' ? recoveryText[2] : reason === 'moduleUnavailable' || kind === 'renderer' || kind === 'source' ? recoveryText[1] : recoveryText[0];
                if (kind !== 'search' && document.documentElement.getAttribute('data-context') !== 'app') {
                    const openLabels: Record<string, string> = { en: 'Open in FluxMarkdown', zh: '用 FluxMarkdown 打开', de: 'In FluxMarkdown öffnen', fr: 'Ouvrir dans FluxMarkdown', es: 'Abrir en FluxMarkdown', ar: 'فتح في FluxMarkdown' };
                    recovery.textContent = openLabels[(window.__fluxLang || navigator.language).split('-')[0]] || openLabels.en;
                }
                recovery.addEventListener('click', event => {
                    event.preventDefault(); event.stopPropagation();
                    if (kind === 'search') root.querySelector<HTMLInputElement>('.search-input')?.focus();
                    else post('recover');
                });
                controls.appendChild(recovery);
                for (const [action, label] of [['report', labels[0]], ['inspect', labels[1]]] as const) {
                    const button = document.createElement('button'); button.type = 'button'; button.textContent = label;
                    button.dataset.feedbackAction = action;
                    button.addEventListener('click', event => { event.preventDefault(); event.stopPropagation(); post(action); });
                    controls.appendChild(button);
                }
                const disclosure = document.createElement('small'); disclosure.textContent = labels[3]; disclosure.style.width = '100%'; controls.appendChild(disclosure);
                // Native syntax errors may be inline spans or images; do not put block UI inside them.
                if (element.tagName === 'IMG' || element.classList.contains('katex-error') || element.classList.contains('math-error')) { element.insertAdjacentElement('afterend', controls); externalControls.set(element, controls); }
                else {
                    if (kind !== 'search' && kind !== 'copy') {
                        const details = document.createElement('details');
                        details.className = 'error-technical-details';
                        const summary = document.createElement('summary');
                        const titles: Record<string, string> = { en: 'Technical details', zh: '技术详情', de: 'Technische Details', fr: 'Détails techniques', es: 'Detalles técnicos', ar: 'التفاصيل التقنية' };
                        summary.textContent = titles[(window.__fluxLang || navigator.language).split('-')[0]] || titles.en;
                        while (element.firstChild) details.appendChild(element.firstChild);
                        details.prepend(summary); element.appendChild(details);
                    }
                    element.prepend(controls);
                }
                post('record');
            });
        }
    }
    const observer = new MutationObserver(scan);
    observer.observe(root, { childList: true, subtree: true, attributes: true, attributeFilter: ['class', 'style'] });
    scan();
    return () => observer.disconnect();
}
