import { updateReadingControlsLayout } from './reading-controls';
import type { SearchEngine, SearchOptions } from "./search";

declare global { interface Window { __fluxLang?: string; } }

const searchLabels = {
	en: { find: 'Find in page', query: 'Search query', previous: 'Previous match', next: 'Next match', close: 'Close', case: 'Match case', word: 'Match whole word', regex: 'Use regular expression', invalidRegex: 'Invalid regular expression' },
	zh: { find: '在页面中查找', query: '搜索内容', previous: '上一个匹配项', next: '下一个匹配项', close: '关闭', case: '区分大小写', word: '匹配整个单词', regex: '使用正则表达式', invalidRegex: '正则表达式无效' },
	de: { find: 'Auf der Seite suchen', query: 'Suchanfrage', previous: 'Vorheriger Treffer', next: 'Nächster Treffer', close: 'Schließen', case: 'Groß-/Kleinschreibung beachten', word: 'Ganzes Wort suchen', regex: 'Regulären Ausdruck verwenden', invalidRegex: 'Ungültiger regulärer Ausdruck' },
	fr: { find: 'Rechercher dans la page', query: 'Requête de recherche', previous: 'Résultat précédent', next: 'Résultat suivant', close: 'Fermer', case: 'Respecter la casse', word: 'Mot entier', regex: 'Utiliser une expression régulière', invalidRegex: 'Expression régulière non valide' },
	es: { find: 'Buscar en la página', query: 'Consulta de búsqueda', previous: 'Coincidencia anterior', next: 'Coincidencia siguiente', close: 'Cerrar', case: 'Distinguir mayúsculas', word: 'Coincidir palabra completa', regex: 'Usar expresión regular', invalidRegex: 'Expresión regular no válida' },
	ar: { find: 'البحث في الصفحة', query: 'نص البحث', previous: 'المطابقة السابقة', next: 'المطابقة التالية', close: 'إغلاق', case: 'مطابقة حالة الأحرف', word: 'مطابقة الكلمة كاملة', regex: 'استخدام تعبير نمطي', invalidRegex: 'تعبير نمطي غير صالح' },
} as const;

function localizedSearchLabels() {
	const language = (window.__fluxLang || navigator.language || 'en').split('-')[0] as keyof typeof searchLabels;
	return searchLabels[language] || searchLabels.en;
}

export class SearchUI {
	private container: HTMLElement;
	private searchEngine: SearchEngine;
	private isVisible: boolean = false;

	private searchInput!: HTMLInputElement;
	private caseSensitiveCheckbox!: HTMLInputElement;
	private wholeWordCheckbox!: HTMLInputElement;
	private regexCheckbox!: HTMLInputElement;
	private matchCounter!: HTMLSpanElement;
	private errorMessage!: HTMLDivElement;
	private prevButton!: HTMLButtonElement;
	private nextButton!: HTMLButtonElement;
	private closeButton!: HTMLButtonElement;

	constructor(containerId: string, searchEngine: SearchEngine) {
		const element = document.getElementById(containerId);
		if (!element) {
			throw new Error(`Search container element not found: ${containerId}`);
		}
		this.container = element;
		this.searchEngine = searchEngine;

		this.createUI();
		this.attachEventListeners();
	}

	private createUI(): void {
		const labels = localizedSearchLabels();
		const toolbar = document.createElement("div");
		toolbar.className = "search-toolbar";
		toolbar.setAttribute("role", "search");
		toolbar.setAttribute("aria-label", labels.find);

		const inputGroup = document.createElement("div");
		inputGroup.className = "search-input-group";

		this.searchInput = document.createElement("input");
		this.searchInput.type = "text";
		this.searchInput.className = "search-input";
		this.searchInput.placeholder = labels.find;
		this.searchInput.setAttribute("aria-label", labels.query);
		// Disable macOS auto-capitalization, auto-correct, and spellcheck
		this.searchInput.setAttribute("autocapitalize", "off");
		this.searchInput.setAttribute("autocomplete", "off");
		this.searchInput.setAttribute("autocorrect", "off");
		this.searchInput.setAttribute("spellcheck", "false");

		this.matchCounter = document.createElement("span");
		this.matchCounter.className = "search-match-counter";
		this.matchCounter.textContent = "";

		inputGroup.appendChild(this.searchInput);
		inputGroup.appendChild(this.matchCounter);

		this.prevButton = this.createButton("prev", "↑", labels.previous);
		this.nextButton = this.createButton("next", "↓", labels.next);

		const optionsGroup = document.createElement("div");
		optionsGroup.className = "search-options";

		this.caseSensitiveCheckbox = this.createCheckbox(
			"case",
			"Aa",
			labels.case,
		);
		this.wholeWordCheckbox = this.createCheckbox(
			"word",
			"ab",
			labels.word,
		);
		this.regexCheckbox = this.createCheckbox(
			"regex",
			".*",
			labels.regex,
		);

		const caseLabel = this.caseSensitiveCheckbox.parentElement;
		const wordLabel = this.wholeWordCheckbox.parentElement;
		const regexLabel = this.regexCheckbox.parentElement;

		if (caseLabel) optionsGroup.appendChild(caseLabel);
		if (wordLabel) optionsGroup.appendChild(wordLabel);
		if (regexLabel) optionsGroup.appendChild(regexLabel);

		this.closeButton = this.createButton("close", "×", labels.close);

		toolbar.appendChild(inputGroup);
		toolbar.appendChild(this.prevButton);
		toolbar.appendChild(this.nextButton);
		toolbar.appendChild(optionsGroup);
		toolbar.appendChild(this.closeButton);

		this.errorMessage = document.createElement("div");
		this.errorMessage.className = "search-error";
		this.errorMessage.setAttribute("role", "alert");
		this.errorMessage.style.display = "none";

		this.container.appendChild(toolbar);
		this.container.appendChild(this.errorMessage);
	}

	private createButton(
		className: string,
		text: string,
		ariaLabel: string,
	): HTMLButtonElement {
		const button = document.createElement("button");
		button.className = `search-button search-button-${className}`;
		button.textContent = text;
		button.setAttribute("aria-label", ariaLabel);
		button.type = "button";
		return button;
	}

	private createCheckbox(
		name: string,
		label: string,
		ariaLabel: string,
	): HTMLInputElement {
		const wrapper = document.createElement("label");
		wrapper.className = "search-checkbox-label";
		wrapper.title = ariaLabel;

		const checkbox = document.createElement("input");
		checkbox.type = "checkbox";
		checkbox.className = "search-checkbox";
		checkbox.id = `search-${name}`;
		checkbox.setAttribute("aria-label", ariaLabel);

		const labelText = document.createElement("span");
		labelText.textContent = label;

		wrapper.appendChild(checkbox);
		wrapper.appendChild(labelText);

		return checkbox;
	}

	private attachEventListeners(): void {
		this.searchInput.addEventListener("input", () => this.performSearch());
		this.searchInput.addEventListener("keydown", (e) =>
			this.handleInputKeydown(e),
		);

		this.caseSensitiveCheckbox.addEventListener("change", () =>
			this.performSearch(),
		);
		this.wholeWordCheckbox.addEventListener("change", () =>
			this.performSearch(),
		);
		this.regexCheckbox.addEventListener("change", () => this.performSearch());

		this.prevButton.addEventListener("click", () => this.navigatePrevious());
		this.nextButton.addEventListener("click", () => this.navigateNext());
		this.closeButton.addEventListener("click", () => this.hide());

		document.addEventListener("keydown", (e) => this.handleGlobalKeydown(e));
	}

	private handleInputKeydown(event: KeyboardEvent): void {
		if (event.key === "Enter") {
			event.preventDefault();
			event.stopPropagation();
			if (event.shiftKey) {
				this.navigatePrevious();
			} else {
				this.navigateNext();
			}
		} else if (event.key === "Escape") {
			event.preventDefault();
			event.stopPropagation();
			this.hide();
		}
	}

	private handleGlobalKeydown(event: KeyboardEvent): void {
		if (!this.isVisible) return;

		if (event.key === "Escape") {
			event.preventDefault();
			event.stopPropagation();
			this.hide();
		}
	}

	private performSearch(): void {
		const query = this.searchInput.value;

		this.hideError();

		if (!query) {
			this.searchEngine.clear();
			this.updateMatchCounter(0, 0);
			this.updateButtonStates(false);
			return;
		}

		const options: SearchOptions = {
			caseSensitive: this.caseSensitiveCheckbox.checked,
			wholeWord: this.wholeWordCheckbox.checked,
			useRegex: this.regexCheckbox.checked,
		};

		const matchCount = this.searchEngine.search(query, options);

		if (matchCount === -1) {
			this.showError(localizedSearchLabels().invalidRegex);
			this.updateMatchCounter(0, 0);
			this.updateButtonStates(false);
			return;
		}

		const currentIndex = this.searchEngine.getCurrentIndex();
		this.updateMatchCounter(currentIndex, matchCount);
		this.updateButtonStates(matchCount > 0);
	}

	private navigateNext(): void {
		this.searchEngine.next();
		const currentIndex = this.searchEngine.getCurrentIndex();
		const matchCount = this.searchEngine.getMatchCount();
		this.updateMatchCounter(currentIndex, matchCount);
	}

	private navigatePrevious(): void {
		this.searchEngine.previous();
		const currentIndex = this.searchEngine.getCurrentIndex();
		const matchCount = this.searchEngine.getMatchCount();
		this.updateMatchCounter(currentIndex, matchCount);
	}

	private updateMatchCounter(current: number, total: number): void {
		if (total === 0) {
			this.matchCounter.textContent = "";
		} else {
			this.matchCounter.textContent = `${current}/${total}`;
		}
	}

	private updateButtonStates(enabled: boolean): void {
		this.prevButton.disabled = !enabled;
		this.nextButton.disabled = !enabled;
	}

	private showError(message: string): void {
		this.errorMessage.textContent = message;
		this.errorMessage.style.display = "block";
		updateReadingControlsLayout();
		this.searchInput.classList.add("search-input-error");
	}

	private hideError(): void {
		this.errorMessage.style.display = "none";
		updateReadingControlsLayout();
		this.searchInput.classList.remove("search-input-error");
	}

	public refresh(): void {
		if (this.isVisible) this.performSearch();
	}

	public show(): void {
		this.isVisible = true;
		this.container.style.display = "flex";
		updateReadingControlsLayout();

		this.searchInput.focus({ preventScroll: true });
		this.searchInput.select();
	}

	public hide(): void {
		this.isVisible = false;
		this.container.style.display = "none";
		this.searchEngine.clear();
		this.searchInput.value = "";
		this.updateMatchCounter(0, 0);
		this.hideError();
		updateReadingControlsLayout();
	}

	public toggle(): void {
		if (this.isVisible) {
			this.hide();
		} else {
			this.show();
		}
	}

	public isSearchVisible(): boolean {
		return this.isVisible;
	}
}
