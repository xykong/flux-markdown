import { SearchEngine, SearchOptions } from './search';

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
        const toolbar = document.createElement('div');
        toolbar.className = 'search-toolbar';
        toolbar.setAttribute('role', 'search');
        toolbar.setAttribute('aria-label', 'Find in page');

        const inputGroup = document.createElement('div');
        inputGroup.className = 'search-input-group';

        this.searchInput = document.createElement('input');
        this.searchInput.type = 'text';
        this.searchInput.className = 'search-input';
        this.searchInput.placeholder = 'Find in page';
        this.searchInput.setAttribute('aria-label', 'Search query');
        this.searchInput.setAttribute('autocorrect', 'off');
        this.searchInput.setAttribute('autocomplete', 'off');
        this.searchInput.setAttribute('autocapitalize', 'off');
        this.searchInput.setAttribute('spellcheck', 'false');
        
        this.matchCounter = document.createElement('span');
        this.matchCounter.className = 'search-match-counter';
        this.matchCounter.textContent = '';

        inputGroup.appendChild(this.searchInput);
        inputGroup.appendChild(this.matchCounter);

        this.prevButton = this.createButton('prev', '↑', 'Previous match');
        this.nextButton = this.createButton('next', '↓', 'Next match');

        const optionsGroup = document.createElement('div');
        optionsGroup.className = 'search-options';

        this.caseSensitiveCheckbox = this.createCheckbox('case', 'Aa', 'Match case');
        this.wholeWordCheckbox = this.createCheckbox('word', 'ab', 'Match whole word');
        this.regexCheckbox = this.createCheckbox('regex', '.*', 'Use regular expression');

        optionsGroup.appendChild(this.caseSensitiveCheckbox.parentElement!);
        optionsGroup.appendChild(this.wholeWordCheckbox.parentElement!);
        optionsGroup.appendChild(this.regexCheckbox.parentElement!);

        this.closeButton = this.createButton('close', '×', 'Close');

        toolbar.appendChild(inputGroup);
        toolbar.appendChild(this.prevButton);
        toolbar.appendChild(this.nextButton);
        toolbar.appendChild(optionsGroup);
        toolbar.appendChild(this.closeButton);

        this.errorMessage = document.createElement('div');
        this.errorMessage.className = 'search-error';
        this.errorMessage.setAttribute('role', 'alert');
        this.errorMessage.style.display = 'none';

        this.container.appendChild(toolbar);
        this.container.appendChild(this.errorMessage);
    }

    private createButton(className: string, text: string, ariaLabel: string): HTMLButtonElement {
        const button = document.createElement('button');
        button.className = `search-button search-button-${className}`;
        button.textContent = text;
        button.setAttribute('aria-label', ariaLabel);
        button.type = 'button';
        return button;
    }

    private createCheckbox(name: string, label: string, ariaLabel: string): HTMLInputElement {
        const wrapper = document.createElement('label');
        wrapper.className = 'search-checkbox-label';
        wrapper.title = ariaLabel;

        const checkbox = document.createElement('input');
        checkbox.type = 'checkbox';
        checkbox.className = 'search-checkbox';
        checkbox.id = `search-${name}`;
        checkbox.setAttribute('aria-label', ariaLabel);

        const labelText = document.createElement('span');
        labelText.textContent = label;

        wrapper.appendChild(checkbox);
        wrapper.appendChild(labelText);

        return checkbox;
    }

    private attachEventListeners(): void {
        this.searchInput.addEventListener('input', () => this.performSearch());
        this.searchInput.addEventListener('keydown', (e) => this.handleInputKeydown(e));

        this.caseSensitiveCheckbox.addEventListener('change', () => this.performSearch());
        this.wholeWordCheckbox.addEventListener('change', () => this.performSearch());
        this.regexCheckbox.addEventListener('change', () => this.performSearch());

        this.prevButton.addEventListener('click', () => this.navigatePrevious());
        this.nextButton.addEventListener('click', () => this.navigateNext());
        this.closeButton.addEventListener('click', () => this.hide());

        document.addEventListener('keydown', (e) => this.handleGlobalKeydown(e));
    }

    private handleInputKeydown(event: KeyboardEvent): void {
        if (event.key === 'Enter') {
            event.preventDefault();
            if (event.shiftKey) {
                this.navigatePrevious();
            } else {
                this.navigateNext();
            }
        } else if (event.key === 'Escape') {
            event.preventDefault();
            this.hide();
        }
    }

    private handleGlobalKeydown(event: KeyboardEvent): void {
        if (!this.isVisible) return;

        if (event.key === 'Escape') {
            event.preventDefault();
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
            useRegex: this.regexCheckbox.checked
        };

        const matchCount = this.searchEngine.search(query, options);

        if (matchCount === -1) {
            this.showError('Invalid regular expression');
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
            this.matchCounter.textContent = '';
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
        this.errorMessage.style.display = 'block';
        this.searchInput.classList.add('search-input-error');
    }

    private hideError(): void {
        this.errorMessage.style.display = 'none';
        this.searchInput.classList.remove('search-input-error');
    }

    public show(): void {
        this.isVisible = true;
        this.container.style.display = 'flex';
        
        setTimeout(() => {
            this.searchInput.focus();
            this.searchInput.select();
        }, 100);
    }

    public hide(): void {
        this.isVisible = false;
        this.container.style.display = 'none';
        this.searchEngine.clear();
        this.searchInput.value = '';
        this.updateMatchCounter(0, 0);
        this.hideError();
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
