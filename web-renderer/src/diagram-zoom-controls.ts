const labels: Record<string, [string, string, string]> = {
    en: ['Zoom out diagram', 'Reset diagram zoom', 'Zoom in diagram'],
    zh: ['缩小图表', '还原图表缩放', '放大图表'],
    de: ['Diagramm verkleinern', 'Diagrammzoom zurücksetzen', 'Diagramm vergrößern'],
    fr: ['Réduire le diagramme', 'Réinitialiser le zoom du diagramme', 'Agrandir le diagramme'],
    es: ['Alejar diagrama', 'Restablecer zoom del diagrama', 'Acercar diagrama'],
    ar: ['تصغير المخطط', 'إعادة تعيين تكبير المخطط', 'تكبير المخطط'],
};


/** Shared interaction, bounds and labels for rendered and referenced diagrams. */
export function createDiagramZoomControls(className: string, changed: () => void) {
    const strings = labels[(window.__fluxLang || navigator.language).split('-')[0]] || labels.en;
    const element = document.createElement('span'); element.className = `diagram-tools ${className}`;
    let step = 0, ready = true, disposed = false;
    const buttons = strings.map((label, index) => {
        const button = document.createElement('button'); button.type = 'button';
        button.title = label; button.setAttribute('aria-label', label);
        button.textContent = ['−', '100%', '+'][index]; element.append(button); return button;
    });
    function update(): void {
        buttons[0].disabled = !ready || step === -8;
        buttons[1].disabled = !ready;
        buttons[2].disabled = !ready || step === 8;
        buttons[1].textContent = `${Math.round(Math.pow(1.25, step) * 100)}%`;
    }
    const handlers = buttons.map((_button, index) => (event: MouseEvent) => {
        event.preventDefault(); event.stopPropagation();
        if (disposed || !ready) return;
        step = index === 1 ? 0 : Math.max(-8, Math.min(8, step + (index === 0 ? -1 : 1)));
        update(); changed();
    });
    buttons.forEach((button, index) => button.addEventListener('click', handlers[index]));
    return {
        element,
        get factor(): number { return Math.pow(1.25, step); },
        setReady(value: boolean): void { ready = value; update(); },
        dispose(): void {
            disposed = true;
            buttons.forEach((button, index) => button.removeEventListener('click', handlers[index]));
            element.remove();
        },
    };
}
