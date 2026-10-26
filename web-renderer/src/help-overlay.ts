const FIRST_RUN_KEY = 'fluxmd-help-shown-v1';
const CMD_HOLD_DELAY_MS = 2000;
const CMD_HOLD_ENABLED_KEY = 'fluxmd-cmd-hold-enabled';

declare global {
    interface Window {
        __fluxContext?: string;
        __fluxLang?: string;
    }
}

type Lang = 'zh' | 'en' | 'de' | 'fr' | 'ar';

interface I18n {
    title: string;
    contextBadgeQL: string;
    contextBadgeApp: string;
    badgeApp: string;
    qlBannerText: string;
    footerQL: string;
    footerApp: string;
    toastText: string;
    closeLabel: string;
    cmdHoldCheckboxLabel: string;
    starLabel: string;
    starHint: string;
    groups: {
        searchNav: { title: string; items: string[] };
        zoom: { title: string; items: string[] };
        view: { title: string; items: string[] };
        export: { title: string; items: string[] };
        settings: { title: string; items: string[] };
    };
}

const STRINGS: Record<Lang, I18n> = {
    zh: {
        starLabel: "在 GitHub 点个 Star",
        starHint: "打开 GitHub，点击 Star 支持 FluxMarkdown。",
        title: '⌨️ FluxMarkdown 功能指南',
        contextBadgeQL: 'QuickLook 预览',
        contextBadgeApp: 'FluxMarkdown App',
        badgeApp: 'App',
        qlBannerText: 'QuickLook 系统会拦截键盘事件。仅 <strong>Cmd+滚轮</strong> 和<strong>捏合手势</strong>可用；其余操作请点击右上角按钮，或双击文件用 App 打开。',
        footerQL: '点击遮罩或右上角 <kbd>✕</kbd> 关闭',
        footerApp: '按 <kbd>?</kbd> 或 <kbd>Esc</kbd> 关闭 · 按住 <kbd>⌘</kbd> 2秒再次打开',
        toastText: '💡 按 <kbd>?</kbd> 或点击右上角 <strong>?</strong> 查看所有功能快捷键',
        closeLabel: '关闭',
        cmdHoldCheckboxLabel: '按住 ⌘ 2 秒自动打开此面板',
        groups: {
            searchNav: {
                title: '搜索与导航',
                items: ['打开 / 关闭搜索', '下一个匹配', '上一个匹配', '关闭搜索', '右上角目录按钮打开 TOC'],
            },
            zoom: {
                title: '缩放',
                items: ['放大', '缩小', '重置缩放', '滚动缩放', '触控板缩放'],
            },
            view: {
                title: '视图',
                items: ['切换渲染 / 源码视图', '右上角 </> 按钮切换源码视图', '右上角 ☀/🌙 切换主题'],
            },
            export: {
                title: '导出',
                items: ['导出为 HTML', '导出为 PDF'],
            },
            settings: {
                title: '设置',
                items: ['打开偏好设置', '检查更新', '右上角 ? 按钮显示此帮助', '显示此帮助面板'],
            },
        },
    },
    en: {
        starLabel: "Star on GitHub",
        starHint: "Open GitHub and click Star to support FluxMarkdown.",
        title: '⌨️ FluxMarkdown Feature Guide',
        contextBadgeQL: 'QuickLook Preview',
        contextBadgeApp: 'FluxMarkdown App',
        badgeApp: 'App',
        qlBannerText: 'QuickLook intercepts keyboard events. Only <strong>Cmd+scroll</strong> and <strong>pinch gesture</strong> work; use toolbar buttons or double-click to open in App for full access.',
        footerQL: 'Click backdrop or <kbd>✕</kbd> to close',
        footerApp: 'Press <kbd>?</kbd> or <kbd>Esc</kbd> to close · Hold <kbd>⌘</kbd> 2s to reopen',
        toastText: '💡 Press <kbd>?</kbd> or click <strong>?</strong> in the toolbar to view all shortcuts',
        closeLabel: 'Close',
        cmdHoldCheckboxLabel: 'Auto-open this panel by holding ⌘ for 2s',
        groups: {
            searchNav: {
                title: 'Search & Navigation',
                items: ['Open / close search', 'Next match', 'Previous match', 'Close search', 'TOC button (top-right)'],
            },
            zoom: {
                title: 'Zoom',
                items: ['Zoom in', 'Zoom out', 'Reset zoom', 'Scroll zoom', 'Pinch to zoom'],
            },
            view: {
                title: 'View',
                items: ['Toggle preview / source', 'Source button (top-right </>)', 'Theme toggle (☀/🌙 top-right)'],
            },
            export: {
                title: 'Export',
                items: ['Export as HTML', 'Export as PDF'],
            },
            settings: {
                title: 'Settings',
                items: ['Open preferences', 'Check for updates', 'Help button (? top-right)', 'Show this help panel'],
            },
        },
    },
    de: {
        starLabel: "Stern auf GitHub geben",
        starHint: "GitHub öffnen und FluxMarkdown mit einem Stern unterstützen.",
        title: '⌨️ FluxMarkdown Funktionsübersicht',
        contextBadgeQL: 'QuickLook-Vorschau',
        contextBadgeApp: 'FluxMarkdown-App',
        badgeApp: 'App',
        qlBannerText: 'QuickLook fängt Tastatureingaben ab. Nur <strong>Cmd+Scrollen</strong> und <strong>Pinch-Geste</strong> funktionieren; benutze die Symbolleisten-Buttons oder öffne die Datei per Doppelklick in der App, um auf alle Funktionen zuzugreifen.',
        footerQL: 'Klick auf den Hintergrund oder <kbd>✕</kbd>, um zu schließen',
        footerApp: '<kbd>?</kbd> oder <kbd>Esc</kbd> zum Schließen · <kbd>⌘</kbd> 2 Sek. halten zum erneuten Öffnen',
        toastText: '💡 Drücke <kbd>?</kbd> oder klicke auf <strong>?</strong> in der Symbolleiste, um alle Shortcuts zu sehen',
        closeLabel: 'Schließen',
        cmdHoldCheckboxLabel: 'Dieses Panel automatisch öffnen, wenn ⌘ 2 Sek. gehalten wird',
        groups: {
            searchNav: {
                title: 'Suche & Navigation',
                items: ['Suche öffnen / schließen', 'Nächster Treffer', 'Vorheriger Treffer', 'Suche schließen', 'TOC-Button (oben rechts)'],
            },
            zoom: {
                title: 'Zoom',
                items: ['Vergrößern', 'Verkleinern', 'Zoom zurücksetzen', 'Scroll-Zoom', 'Pinch-to-Zoom'],
            },
            view: {
                title: 'Ansicht',
                items: ['Vorschau / Quelltext umschalten', 'Quelltext-Button (oben rechts </>)', 'Theme umschalten (☀/🌙 oben rechts)'],
            },
            export: {
                title: 'Exportieren',
                items: ['Als HTML exportieren', 'Als PDF exportieren'],
            },
            settings: {
                title: 'Einstellungen',
                items: ['Einstellungen öffnen', 'Nach Updates suchen', 'Hilfe-Button (? oben rechts)', 'Dieses Hilfe-Panel anzeigen'],
            },
        },
    },
    fr: {
        starLabel: "Soutenir sur GitHub",
        starHint: "Ouvrez GitHub et cliquez sur Star pour soutenir FluxMarkdown.",
        title: '⌨️ Guide des fonctionnalités de FluxMarkdown',
        contextBadgeQL: 'Aperçu Coup d’œil',
        contextBadgeApp: 'FluxMarkdown App',
        badgeApp: 'App',
        qlBannerText: 'Coup d’œil intercepte les événements clavier. Seuls <strong>Cmd+défilement</strong> et le <strong>geste de pincement</strong> fonctionnent ; utilisez les boutons de la barre d’outils ou double-cliquez pour ouvrir dans l’app et accéder à toutes les fonctions.',
        footerQL: 'Cliquer sur le fond ou <kbd>✕</kbd> pour fermer',
        footerApp: '<kbd>?</kbd> ou <kbd>Esc</kbd> pour fermer · Maintenir <kbd>⌘</kbd> 2 s pour rouvrir',
        toastText: '💡 Appuyez sur <kbd>?</kbd> ou cliquez sur <strong>?</strong> dans la barre d’outils pour voir tous les raccourcis',
        closeLabel: 'Fermer',
        cmdHoldCheckboxLabel: 'Ouvrir automatiquement ce panneau en maintenant ⌘ pendant 2 s',
        groups: {
            searchNav: {
                title: 'Recherche & Navigation',
                items: ['Ouvrir / fermer la recherche', 'Résultat suivant', 'Résultat précédent', 'Fermer la recherche', 'Bouton TOC (en haut à droite)'],
            },
            zoom: {
                title: 'Zoom',
                items: ['Zoom avant', 'Zoom arrière', 'Réinitialiser le zoom', 'Zoom par défilement', 'Zoom par pincement'],
            },
            view: {
                title: 'Affichage',
                items: ['Basculer aperçu / source', 'Bouton source (en haut à droite </>)', 'Basculer le thème (☀/🌙 en haut à droite)'],
            },
            export: {
                title: 'Exporter',
                items: ['Exporter en HTML', 'Exporter en PDF'],
            },
            settings: {
                title: 'Réglages',
                items: ['Ouvrir les réglages', 'Rechercher les mises à jour', 'Bouton aide (? en haut à droite)', 'Afficher ce panneau d’aide'],
            },
        },
    },
    ar: {
        starLabel: "أضف نجمة على GitHub",
        starHint: "افتح GitHub وانقر Star لدعم FluxMarkdown.",
        title: '⌨️ دليل ميزات FluxMarkdown',
        contextBadgeQL: 'معاينة نظرة سريعة',
        contextBadgeApp: 'تطبيق FluxMarkdown',
        badgeApp: 'تطبيق',
        qlBannerText: 'تعترض «نظرة سريعة» أحداث لوحة المفاتيح. يعمل فقط <strong>Cmd+التمرير</strong> و<strong>إيماءة الضغط</strong>؛ استخدم أزرار شريط الأدوات أو انقر نقرًا مزدوجًا لفتح الملف في التطبيق للوصول الكامل.',
        footerQL: 'انقر على الخلفية أو <kbd>✕</kbd> للإغلاق',
        footerApp: 'اضغط <kbd>?</kbd> أو <kbd>Esc</kbd> للإغلاق · استمر بالضغط على <kbd>⌘</kbd> لثانيتين لإعادة الفتح',
        toastText: '💡 اضغط <kbd>?</kbd> أو انقر على <strong>?</strong> في شريط الأدوات لعرض كل الاختصارات',
        closeLabel: 'إغلاق',
        cmdHoldCheckboxLabel: 'فتح هذه اللوحة تلقائيًا بالضغط على ⌘ لثانيتين',
        groups: {
            searchNav: {
                title: 'البحث والتنقل',
                items: ['فتح / إغلاق البحث', 'المطابقة التالية', 'المطابقة السابقة', 'إغلاق البحث', 'زر المحتويات (أعلى اليمين)'],
            },
            zoom: {
                title: 'التكبير',
                items: ['تكبير', 'تصغير', 'إعادة ضبط التكبير', 'التكبير بالتمرير', 'التكبير بالضغط'],
            },
            view: {
                title: 'العرض',
                items: ['تبديل المعاينة / المصدر', 'زر المصدر (أعلى اليمين </>)', 'تبديل المظهر (☀/🌙 أعلى اليمين)'],
            },
            export: {
                title: 'التصدير',
                items: ['تصدير بصيغة HTML', 'تصدير بصيغة PDF'],
            },
            settings: {
                title: 'الإعدادات',
                items: ['فتح التفضيلات', 'التحقق من التحديثات', 'زر المساعدة (? أعلى اليمين)', 'عرض لوحة المساعدة هذه'],
            },
        },
    },
};

interface ShortcutGroup {
    icon: string;
    groupKey: keyof I18n['groups'];
    items: Array<{ keys: string[]; labelIdx: number; appOnly?: true; qlDisabled?: true }>;
}

const SHORTCUT_GROUPS: ShortcutGroup[] = [
    {
        icon: '🔍',
        groupKey: 'searchNav',
        items: [
            { keys: ['⌘', 'F'], labelIdx: 0, qlDisabled: true },
            { keys: ['Enter'], labelIdx: 1, qlDisabled: true },
            { keys: ['⇧', 'Enter'], labelIdx: 2, qlDisabled: true },
            { keys: ['Esc'], labelIdx: 3, qlDisabled: true },
            { keys: ['Click'], labelIdx: 4 },
        ],
    },
    {
        icon: '🔎',
        groupKey: 'zoom',
        items: [
            { keys: ['⌘', '+'], labelIdx: 0, qlDisabled: true },
            { keys: ['⌘', '-'], labelIdx: 1, qlDisabled: true },
            { keys: ['⌘', '0'], labelIdx: 2, qlDisabled: true },
            { keys: ['⌘', '⬆scroll'], labelIdx: 3 },
            { keys: ['Pinch'], labelIdx: 4 },
        ],
    },
    {
        icon: '📄',
        groupKey: 'view',
        items: [
            { keys: ['⌘', '⇧', 'M'], labelIdx: 0, qlDisabled: true },
            { keys: ['Click'], labelIdx: 1 },
            { keys: ['Click'], labelIdx: 2 },
        ],
    },
    {
        icon: '📤',
        groupKey: 'export',
        items: [
            { keys: ['⌘', '⇧', 'E'], labelIdx: 0, appOnly: true },
            { keys: ['⌘', '⇧', 'P'], labelIdx: 1, appOnly: true },
        ],
    },
    {
        icon: '⚙️',
        groupKey: 'settings',
        items: [
            { keys: ['⌘', ','], labelIdx: 0, appOnly: true },
            { keys: ['⌘', 'U'], labelIdx: 1, appOnly: true },
            { keys: ['Click'], labelIdx: 2 },
            { keys: ['⌘', 'Hold'], labelIdx: 3, qlDisabled: true },
        ],
    },
];

function detectLang(): Lang {
    const stored = window.__fluxLang;
    if (stored === 'zh' || stored === 'en' || stored === 'de' || stored === 'fr' || stored === 'ar') return stored;
    const sys = (navigator.language || '').toLowerCase();
    if (sys.startsWith('zh')) return 'zh';
    if (sys.startsWith('de')) return 'de';
    if (sys.startsWith('fr')) return 'fr';
    if (sys.startsWith('ar')) return 'ar';
    return 'en';
}

export class HelpOverlay {
    private overlayEl: HTMLElement | null = null;
    private toastEl: HTMLElement | null = null;
    private isVisible = false;

    private cmdHoldTimer: ReturnType<typeof setTimeout> | null = null;
    private cmdHoldActive = false;

    private isCmdHoldEnabled(): boolean {
        try {
            const stored = localStorage.getItem(CMD_HOLD_ENABLED_KEY);
            return stored === null ? true : stored === '1';
        } catch {
            return true;
        }
    }

    private setCmdHoldEnabled(enabled: boolean): void {
        try {
            localStorage.setItem(CMD_HOLD_ENABLED_KEY, enabled ? '1' : '0');
        } catch {}
    }

    constructor() {
        this.createOverlay();
        this.registerKeyListeners();
        this.showFirstRunToast();
    }

    private createOverlay(): void {
        const strings = STRINGS[detectLang()];
        const overlay = document.createElement('div');
        overlay.id = 'help-overlay';
        overlay.setAttribute('role', 'dialog');
        overlay.setAttribute('aria-modal', 'true');
        overlay.setAttribute('aria-label', strings.title);

        overlay.innerHTML = this.buildOverlayHTML();
        overlay.addEventListener('click', (e) => {
            if (e.target === overlay) this.hide();
        });
        overlay.querySelector('#help-overlay-close')?.addEventListener('click', () => this.hide());

        document.body.appendChild(overlay);
        this.overlayEl = overlay;
    }

    private buildOverlayHTML(): string {
        const isQuickLook = window.__fluxContext === 'quicklook';
        const lang = detectLang();
        const s = STRINGS[lang];

        const contextBadge = isQuickLook
            ? `<span class="help-context-badge help-context-ql">${s.contextBadgeQL}</span>`
            : `<span class="help-context-badge help-context-app">${s.contextBadgeApp}</span>`;

        const groups = SHORTCUT_GROUPS.map(g => {
            const groupStrings = s.groups[g.groupKey];
            const items = g.items.map(item => {
                const isAppOnlyDimmed = isQuickLook && item.appOnly;
                const isQlDisabled = isQuickLook && item.qlDisabled;

                let className = 'help-item';
                if (isAppOnlyDimmed || isQlDisabled) className += ' help-item-dimmed';

                const badges: string[] = [];
                if (item.appOnly || item.qlDisabled) {
                    badges.push(`<span class="help-badge help-badge-app">${s.badgeApp}</span>`);
                }

                const label = groupStrings.items[item.labelIdx] ?? '';

                return `
                    <li class="${className}">
                        <span class="help-keys">${item.keys.map(k => `<kbd>${k}</kbd>`).join('')}</span>
                        <span class="help-label">${label}${badges.join('')}</span>
                    </li>
                `;
            }).join('');
            return `
                <div class="help-group">
                    <h3 class="help-group-title">${g.icon} ${groupStrings.title}</h3>
                    <ul class="help-items">${items}</ul>
                </div>
            `;
        }).join('');

        const qlBanner = isQuickLook ? `
            <div class="help-ql-banner">
                <span class="help-ql-banner-icon">⚠️</span>
                <span>${s.qlBannerText}</span>
            </div>
        ` : '';

        const footerText = isQuickLook ? `<span>${s.footerQL}</span>` : `<span>${s.footerApp}</span>`;

        const cmdHoldCheckbox = !isQuickLook ? `
            <label class="help-checkbox-label">
                <input type="checkbox" id="help-cmd-hold-checkbox" ${this.isCmdHoldEnabled() ? 'checked' : ''}>
                ${s.cmdHoldCheckboxLabel}
            </label>
        ` : '';

        return `
            <div class="help-dialog">
                <div class="help-header">
                    <span class="help-title">${s.title}</span>
                    ${contextBadge}
                    <button id="help-overlay-close" class="help-close" aria-label="${s.closeLabel}">✕</button>
                </div>
                ${qlBanner}
                <div class="help-body">
                    ${groups}
                </div>
                <div class="help-footer">
                    ${footerText}
                    ${cmdHoldCheckbox}
                    <a class="help-github-star" href="https://github.com/xykong/flux-markdown" title="${s.starHint}">
                        <span aria-hidden="true">☆</span> ${s.starLabel}
                    </a>
                </div>
            </div>
        `;
    }

    private registerKeyListeners(): void {
        // Modifier-only keys that should NOT cancel the Cmd-hold timer.
        // Any other key pressed while Cmd is held means the user is using a shortcut,
        // so we cancel the timer to avoid false positives (Cmd+Tab, Cmd+Ctrl+X, boss keys, etc.).
        const MODIFIER_KEYS = new Set(['Meta', 'Control', 'Alt', 'Shift', 'CapsLock', 'Fn', 'FnLock', 'Hyper', 'Super', 'Symbol', 'SymbolLock']);

        document.addEventListener('keydown', (e: KeyboardEvent) => {
            if (
                e.key === '?' &&
                !(e.target instanceof HTMLInputElement) &&
                !(e.target instanceof HTMLTextAreaElement) &&
                !e.metaKey && !e.ctrlKey
            ) {
                e.preventDefault();
                this.toggle();
                return;
            }

            if (e.key === 'Escape' && this.isVisible) {
                e.preventDefault();
                this.hide();
                return;
            }

            // If a non-modifier key is pressed while the Cmd-hold timer is running,
            // the user is using a keyboard shortcut (e.g. Cmd+Tab, Cmd+Space, boss key).
            // Cancel the timer immediately so the help overlay does NOT appear.
            if (!MODIFIER_KEYS.has(e.key) && this.cmdHoldTimer) {
                clearTimeout(this.cmdHoldTimer);
                this.cmdHoldTimer = null;
                return;
            }

            if ((e.key === 'Meta' || e.key === 'Control') && !e.repeat && !this.cmdHoldActive && !this.cmdHoldTimer && this.isCmdHoldEnabled()) {
                this.cmdHoldTimer = setTimeout(() => {
                    this.cmdHoldActive = true;
                    this.show();
                }, CMD_HOLD_DELAY_MS);
            }
        });

        document.addEventListener('keyup', (e: KeyboardEvent) => {
            if (e.key === 'Meta' || e.key === 'Control') {
                if (this.cmdHoldTimer) {
                    clearTimeout(this.cmdHoldTimer);
                    this.cmdHoldTimer = null;
                }
                this.cmdHoldActive = false;
            }
        });
    }

    private showFirstRunToast(): void {
        try {
            if (localStorage.getItem(FIRST_RUN_KEY)) return;
            localStorage.setItem(FIRST_RUN_KEY, '1');
        } catch {
            return;
        }
        setTimeout(() => this.mountToast(), 1500);
    }

    private mountToast(): void {
        const lang = detectLang();
        const s = STRINGS[lang];
        const toast = document.createElement('div');
        toast.id = 'help-toast';
        toast.className = 'help-toast';
        toast.innerHTML = `
            <span>${s.toastText}</span>
            <button class="help-toast-close" aria-label="${s.closeLabel}">✕</button>
        `;

        toast.querySelector('.help-toast-close')?.addEventListener('click', () => this.dismissToast());
        document.body.appendChild(toast);
        this.toastEl = toast;

        requestAnimationFrame(() => {
            requestAnimationFrame(() => toast.classList.add('help-toast-visible'));
        });

        setTimeout(() => this.dismissToast(), 6000);
    }

    private dismissToast(): void {
        if (!this.toastEl) return;
        this.toastEl.classList.remove('help-toast-visible');
        setTimeout(() => {
            this.toastEl?.remove();
            this.toastEl = null;
        }, 400);
    }

    public show(): void {
        if (this.isVisible || !this.overlayEl) return;
        this.isVisible = true;
        this.overlayEl.innerHTML = this.buildOverlayHTML();
        this.overlayEl.querySelector('#help-overlay-close')?.addEventListener('click', () => this.hide());

        const checkbox = this.overlayEl.querySelector<HTMLInputElement>('#help-cmd-hold-checkbox');
        checkbox?.addEventListener('change', () => this.setCmdHoldEnabled(checkbox.checked));

        this.overlayEl.classList.add('help-overlay-visible');
        this.dismissToast();
    }

    public hide(): void {
        if (!this.isVisible || !this.overlayEl) return;
        this.isVisible = false;
        this.overlayEl.classList.remove('help-overlay-visible');
    }

    public toggle(): void {
        this.isVisible ? this.hide() : this.show();
    }
}
