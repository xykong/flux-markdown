.PHONY: all build_renderer generate app install install-debug dmg release

all: app

build_renderer:
	cd web-renderer && npm ci --no-audit --no-fund --loglevel=warn && npm run build
	node scripts/collect-licenses.mjs

generate: build_renderer
	@if ! command -v xcodegen >/dev/null; then \
		echo "Error: xcodegen is not installed. Please install it with 'brew install xcodegen'"; \
		exit 1; \
	fi
	@if [ ! -f .version ]; then echo "1.0.0" > .version; fi
	@full_v=$$(cat .version); \
	major=$$(echo $$full_v | cut -d'.' -f1); \
	minor=$$(echo $$full_v | cut -d'.' -f2); \
	build=$$(echo $$full_v | cut -d'.' -f3); \
	echo "Generating Project with Version: $$full_v (Major: $$major, Minor: $$minor, Build: $$build)"; \
	rm -rf FluxMarkdown.xcodeproj; \
	MARKETING_VERSION=$$full_v CURRENT_PROJECT_VERSION=$$build xcodegen generate --quiet

app: generate
	@echo "🔨 Building application in $(or $(CONFIGURATION),Release) configuration..."
	@xcodebuild -project FluxMarkdown.xcodeproj -scheme Markdown -configuration $(or $(CONFIGURATION),Release) -derivedDataPath "$(CURDIR)/build/DerivedData" -destination 'platform=macOS,arch=arm64' ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO clean build -quiet 2> build_error.log || (cat build_error.log; rm -f build_error.log; exit 1)
	@rm -f build_error.log
	@echo "✅ Build completed: $(or $(CONFIGURATION),Release) configuration"

install:
	@echo "🚀 Building and installing Release configuration..."; \
	make app CONFIGURATION=Release && \
	./scripts/install.sh Release true development

install-debug:
	@echo "🚀 Building and installing Debug configuration..."; \
	make app CONFIGURATION=Debug && \
	./scripts/install.sh Debug true development

dmg:
	./scripts/create_dmg.sh

release:
	./scripts/release.sh $(filter-out $@,$(MAKECMDGOALS))

%:
	@:
