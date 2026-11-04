// Disposable bundle missing double-struck glyphs. Capture the bridge seam only:
// no report is opened/sent and no native recovery is executed by this probe.
const assert = (ok, message) => { if (!ok) throw new Error(message); };
for (let i = 0; i < 150 && typeof window.renderMarkdown !== 'function'; i++) {
    await new Promise(resolve => setTimeout(resolve, 20));
}
const raw = '$\\mathbb{abcdefghijklmnopqrstuvwxyz}$';
const root = document.getElementById('markdown-preview');
const messages = window.__issue64FeedbackMessages = [];
let barrier = null;
messages.push = (...items) => {
    for (const item of items) {
        if (item.action === 'barrier') { const done = barrier; barrier = null; done?.(); }
        else Array.prototype.push.call(messages, item);
    }
    return messages.length;
};
const settle = () => new Promise(resolve => {
    barrier = resolve;
    window.webkit.messageHandlers.errorFeedback.postMessage({action:'barrier',kind:'math',generation:'probe',id:'probe',reason:'moduleUnavailable'});
});
const cases = [];
const labels = {
    en: ['Reload', 'Open in FluxMarkdown', 'Report This Problem'],
    'zh-Hans': ['重新载入', '用 FluxMarkdown 打开', '反馈此问题'],
    de: ['Neu laden', 'In FluxMarkdown öffnen', 'Dieses Problem melden'],
    fr: ['Recharger', 'Ouvrir dans FluxMarkdown', 'Signaler ce problème'],
    es: ['Volver a cargar', 'Abrir en FluxMarkdown', 'Reportar este problema'],
    ar: ['إعادة التحميل', 'فتح في FluxMarkdown', 'الإبلاغ عن هذه المشكلة'],
};
    for (const context of ['app', 'quicklook', 'finder']) {
        for (const uiLanguage of ['en', 'zh-Hans', 'de', 'fr', 'es', 'ar']) {
            const generation = `resource-fault-${context}-${uiLanguage}`;
            window.webkit.messageHandlers.trace.postMessage(generation);
            window.setFeedbackGeneration(generation);
            await window.renderMarkdown('# Before\n\n' + raw + '\n\n# After', {context, uiLanguage, showCopyButtons:true});
            window.webkit.messageHandlers.trace.postMessage(generation + ':rendered');
            assert(root.querySelectorAll('.math-error').length === 1, 'Missing glyph was not marked as an error');
            assert(root.textContent.includes(raw), 'Original formula source was not preserved');
            assert(root.textContent.includes('After'), 'Following document content lost');
            assert(!document.querySelector('[data-math-measurement]'), 'Measurement root leaked');
            const controls = root.querySelector('.error-feedback-controls');
            assert(controls, 'Contextual feedback missing');
            assert(controls.querySelector('[data-feedback-action="recover"]').textContent === labels[uiLanguage][context === 'app' ? 0 : 1], 'Wrong localized recovery action');
            assert(controls.querySelector('[data-feedback-action="report"]').textContent === labels[uiLanguage][2], 'Wrong localized report action');
            window.webkit.messageHandlers.trace.postMessage(generation + ':controls');
            for (const action of ['recover', 'report', 'inspect']) {
                const button = controls.querySelector(`[data-feedback-action="${action}"]`);
                assert(button && button.textContent.trim(), `Unnamed/missing ${action} action`);
                await settle();
                const before = messages.length;
                button.click();
                await settle();
                assert(messages.length === before + 1 && messages[before].action === action, `Missing ${action} bridge message`);
            }
            window.webkit.messageHandlers.trace.postMessage(generation + ':actions');
            const incident = messages.filter(message => message.generation === generation);
            assert(incident.some(message => message.action === 'record'), 'Incident was not captured');
            assert(new Set(incident.map(message => message.id)).size === 1, 'Feedback lost incident identity');
            for (const message of incident) {
                assert(Object.keys(message).sort().join(',') === 'action,generation,id,kind,reason', 'Unexpected diagnostic data');
                assert(message.kind === 'math' && message.reason === 'moduleUnavailable', 'Wrong resource incident classification');
            }
            let rejected = false;
            try { await window.waitForExportReady(); } catch { rejected = true; }
            assert(rejected, 'Broken mathematics allowed export');
            const oldReport = controls.querySelector('[data-feedback-action="report"]');
            window.setFeedbackGeneration(generation + '-recovered');
            await window.renderMarkdown('$x^2+y^2=z^2$', {context, uiLanguage});
            await window.waitForExportReady();
            assert(!root.querySelector('.math-error,.error-feedback-controls') && root.querySelector('mjx-container svg path'), 'Valid document failed to recover');
            await settle();
            const before = messages.filter(message => message.action === 'report').length;
            oldReport.click();
            await settle();
            assert(messages.filter(message => message.action === 'report').length === before, 'Detached feedback reported a stale incident');
            cases.push({context, uiLanguage, sourcePreserved:true, exportRejected:true, recovered:true, feedbackSeamValidated:true});
        }
    }
return {cases, privateContentExcluded:true, staleFeedbackRejected:true, actualNativeRecoveryOrReporting:false};
