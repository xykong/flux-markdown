## [Unreleased]

### Fixed
- **Toolbar button feedback and QuickLook clicks**: Unified the standalone app and QuickLook toolbar controls on shared native circular AppKit buttons, restored reload/reset zoom feedback tips, and fixed QuickLook toolbar clicks that could pass through to the preview web view.
  - Standalone app reload/reset tips now appear in the historical upper-center position with a light rounded card.
  - QuickLook reload/reset actions now reuse the native toast feedback path.
  - Offset QuickLook toolbar buttons now convert hit-test coordinates correctly before dispatching actions.
- **Development install QuickLook registration**: Fixed local `make install` / `make install-debug` re-signing stripping the QuickLook extension sandbox entitlement, which caused PluginKit to reject `MarkdownPreview.appex` with “plug-ins must be sandboxed”. Development installs now sign nested code explicitly with the correct entitlements and release DMGs verify the QuickLook sandbox entitlement after packaging.
- **App window restore stability**: Improved standalone app window size restoration by validating restored frames against visible screens, ignoring transient accessory windows during startup, and using saved document dimensions before SwiftUI applies fallback sizing.

### Added
- **Development display version marker**: Local development installs now show an `-dev-<timestamp>` display version in both the standalone app and QuickLook preview, making it easier to distinguish installed development builds from released builds.

## [1.32.427] - 2026-05-13

### Added
- **Typst math rendering** (#36, thanks [@Killer545537](https://github.com/Killer545537)): Added support for `typst` and `typst-math` fenced code blocks in Markdown previews.
  - QuickLook and Finder previews use lightweight `tex2typst` transpilation through the existing KaTeX renderer.
  - The standalone app can use the lazy-loaded `typst.ts` WASM renderer for higher-fidelity SVG output, with transpilation fallback.
  - Added an `enableTypst` preference, Settings toggle, renderer styles, WASM bundling configuration, and regression tests for fence detection and source encoding.

### Fixed
- **App toolbar button hit areas**: Fixed floating toolbar controls only responding when clicking directly on the icon/character. The toolbar now uses AppKit-backed 30×30 controls with bounds-based hit testing so clicks anywhere inside the circular button trigger the action.

## [1.31.416] - 2026-05-12

### Added
- **Two-Finger Pinch Zoom (Visual Scale)**: Double-finger pinch/spread on trackpad now performs smooth visual magnification (0.25× to 5.0×) via `WKWebView.setMagnification()` — scales entire page content without reflow, similar to photo zoom in Photos.app.
- **Two-Finger Double-Tap Reset**: Two-finger double-tap on trackpad (macOS `smartMagnify` event) instantly resets visual magnification to 100% with smooth 0.25s animation.

### Changed
- **Cmd+Scroll Zoom (Throttled)**: Cmd+scroll now uses smooth, zero-frame-drop text reflow zoom via `pageZoom`. User perceives zero lag during gesture (real-time snap to 0.05 steps) with exact final value committed at gesture end. Range: 0.5× to 3.0×.
  - Previous version: simple `pageZoom += 0.05` per scroll without accumulation or snapping → stuttering UX with drift on momentum scrolls.
  - Fix: Accumulate scroll deltas, snap to 0.05-step grid during gesture, commit exact final zoom only at phase `.ended` with momentum events filtered out.

## [1.31.402] - 2026-04-29

### Added
- **全局 UI 语言切换** (#34, thanks [@timokox](https://github.com/timokox)): 设置中的语言选择器现在控制整个应用界面语言，而不仅限于帮助面板
  - 新增 `LocalizationManager`：通过运行时替换 `Bundle.main` 子类，使所有 `NSLocalizedString` 调用在不重启的情况下即时切换语言
  - `AppearancePreference.uiLanguage` setter 调用 `apply()` 以触发 SwiftUI 视图重新渲染
  - AppKit 原生菜单栏（文件/编辑等）、`Settings` 场景标题、Sparkle 更新窗口等通过 `AppleLanguages` 在下次启动时切换，Settings 页面新增"立即重启"提示
  - 新增 **Deutsch（德语）** 和 **Français（法语）** 语言选项；补全所有 UI 字符串的 `en` / `zh-Hans` / `de` / `fr` 本地化
  - Help overlay（`?` 面板）扩展支持 `de` / `fr`，并包含 `navigator.language` fallback 逻辑

## [1.31.398] - 2026-04-28

### Added
- **German (de) Localization** (#31, thanks @timokox): Added German translations for all UI strings including menu items, search, updater, toast messages, and the new "Open in External Editor" menu item.
- **French (fr) Localization** (#32, thanks @timokox): Added French translations for all UI strings including menu items, search, updater, toast messages, and the new "Open in External Editor" menu item.
- **Open in External Editor** (#33, thanks @timokox): Added "Open in External Editor" menu item (⌥⌘E) under the File menu. Opens the current document in the user's default plain-text editor via `open -t`, allowing quick handoff to TextEdit/IDE/etc. without re-associating the file type.

## [1.30.391] - 2026-04-28

### Added
- **Line Numbers in Rendered Preview** (#30): Display source-file line numbers in a left gutter for all block elements (headings, paragraphs, lists, blockquotes, code blocks) in the rendered Markdown preview. Numbers correspond to the original source file line, making it easy to locate any section. Enabled by default; toggle off in Settings → Rendering → "Line Numbers in Code Blocks".
- **Line Numbers in Source View**: The Source View already displays line numbers via the built-in diff gutter; the gutter is hidden when line numbers are disabled in Settings.
- **Settings toggle**: Added "Line Numbers" toggle in Settings → Rendering section.

## [1.29.368] - 2026-04-20

### Added
- **Collapse Blockquotes by Default (Settings)**: Added "Collapse Blockquotes by Default" toggle in Settings → Rendering, allowing users to auto-collapse all blockquote/alert sections when opening a document
- **Blockquote placeholder bar**: When blockquotes are collapsed, each is replaced by a compact placeholder bar (with `▶` arrow) instead of a gradient-truncated preview; clicking any placeholder individually expands that block without affecting others

### Fixed
- **Source↔Preview toggle not restoring rendered content (App)**: Fixed clicking "Show Preview" after "Show Source" leaving the window stuck on source code view
  - Root cause: `onlyThemeChanged` fast-path in `MarkdownWebView.executeRender` incorrectly fired when content was unchanged and mode was `.preview`, skipping the `renderMarkdown` call entirely
  - Fix: added `viewMode == lastViewMode` guard so that any mode transition always triggers a full render; moved `lastViewMode` tracking into `executeRender` so the previous mode is available at comparison time
- **QuickLook source↔preview race condition**: Fixed `renderSource` overwriting a pending async `renderMarkdown` result in the QuickLook extension
  - Replaced `evaluateJavaScript` with `callAsyncJavaScript(in: WKContentWorld.page)` to properly await the async Promise before completion
  - Switched `rendererReady` and `providePreview` callbacks from `renderPendingMarkdown` to `renderCurrentMode` so WebView reloads restore the correct view mode

## [1.28.360] - 2026-04-20

### Fixed
- **App Zoom: no reset button in toolbar** (#27): Added "Reset Zoom" button (arrow.uturn.backward) between Zoom Out and Zoom In buttons in the App window toolbar; `Cmd+0` shortcut also triggers reset
- **App Zoom: zoom level persists across files** (#27): Each document now opens at 100% zoom — zoom is session-only, not saved to UserDefaults, WKProcessPool isolated per window to prevent WebKit zoom state inheritance
- **App Zoom: no upper zoom limit** (#27): Zoom In is now capped at 300% (`min(3.0, ...)`)
- **App Zoom: trackpad inertia triggers zoom** (#27): `scrollWheel` handler now ignores `.mayBegin`, `.cancelled` phases and any non-zero `momentumPhase` events
- **App Zoom: content overflow instead of reflow** (#27): Switched from `webView.magnification` (visual-only scale) to `webView.pageZoom` (triggers proper layout reflow)
- **App Zoom: zoom resets when switching files** (#27): `Coordinator.render()` resets `pageZoom = 1.0` on each new document load

## [1.27.349] - 2026-04-20

### Fixed
- **Zoom: reset button hidden behind reload button**: Fixed `resetZoomButton` being invisible due to both `resetZoomButton` and `reloadButton` sharing the same layout constraint (`trailing = zoomOutButton.leading - 8`), causing them to stack on top of each other (#27)
  - `reloadButton` now correctly anchors to `resetZoomButton.leadingAnchor - 8`, making both buttons visible
- **Zoom: session-only zoom not working when QL reuses view controller**: Fixed zoom not resetting to 100% when QuickLook reuses the same `PreviewViewController` for a different file (#27)
  - Added `webView.pageZoom = 1.0` reset at the start of `preparePreviewOfFile` to handle view controller reuse
- **App toolbar buttons invisible in dark mode (Bug3)**: Fixed toolbar buttons in the standalone App window being invisible in dark mode due to hardcoded `Color.black.opacity(0.1)` background (#26, thanks @Ctrl-Alb)
  - Replaced with adaptive `Color(NSColor.windowBackgroundColor).opacity(0.85)` background and `Color(NSColor.labelColor)` foreground
  - All 6 toolbar buttons are now clearly visible in both Light and Dark modes
- **App theme switch causes full re-render (Bug2)**: Fixed theme toggle in the App window triggering a full page re-render, resetting scroll position (#26, thanks @Ctrl-Alb)
  - Added `lastRenderedContent` tracking in `MarkdownWebView.Coordinator`; when only the appearance mode changes (content unchanged, preview mode), calls `window.updateTheme()` instead of `window.renderMarkdown()`
  - Scroll position, TOC state, and DOM state are all preserved on theme switch in the App window
- **Source View GitHub theme poor contrast in dark mode (Bug5)**: Fixed syntax highlighting in Source View having poor readability when using the GitHub theme in dark mode (#26, thanks @Ctrl-Alb)
  - Added `GITHUB_DARK_OVERRIDE` CSS rules in `applyCodeTheme()` that inject `[data-theme="dark"]` scoped high-contrast token colors using the GitHub Dark palette
  - Tokens (keywords, strings, functions, etc.) now use distinct, accessible colors in dark mode

## [1.26.343] - 2026-04-19

### Fixed
- **Theme switching: non-destructive DOM updates**: Fixed theme toggle triggering a full re-render that reset scroll position and document state (#26, thanks @Ctrl-Alb)
  - Implemented `window.updateTheme()` which only updates `data-theme` attribute, preserving entire DOM
  - Scroll position, TOC expansion, open details blocks, and cursor position are all retained on theme switch
- **Theme switching: system appearance sync**: Fixed QuickLook preview not following macOS system appearance (Light/Dark) in Finder (#26, thanks @Ctrl-Alb)
  - Added KVO observer on `view.effectiveAppearance` in Swift to detect OS-level appearance changes
  - Preview now automatically updates when user switches between Light and Dark in System Preferences
- **Theme switching: button visibility**: Fixed theme toggle button invisible/hard to see in certain themes (#26, thanks @Ctrl-Alb)
  - Changed button background from hard-coded `NSColor.black.withAlphaComponent(0.1)` to adaptive `NSColor.systemFill` which responds to both Light and Dark modes
- **Theme switching: Show Source respects theme**: Fixed "Show Source" view not following manual theme switch (#26, thanks @Ctrl-Alb)
  - `toggleTheme()` now calls unified `applyThemeToWebView()` which covers both rendered and source view modes
- **Theme switching: source view dark mode contrast**: Fixed poor readability of source code in dark mode (#26, thanks @Ctrl-Alb)
  - Rewrote `source-view.css` to use CSS variables (`--bg`, `--fg`, `--border`) that adapt to `[data-theme="dark"]`
  - Dark mode now uses proper contrast colors instead of inheriting light-mode values
- **Zoom: reset button**: Fixed missing zoom reset button in the toolbar (#27, thanks @Ctrl-Alb)
  - Added a dedicated "Reset Zoom" button that restores zoom to 100%
  - `Cmd+0` keyboard shortcut also triggers reset
- **Zoom: not persisted across sessions**: Fixed zoom level being saved and restored across different files/sessions (#27, thanks @Ctrl-Alb)
  - Zoom is now session-only; each file opens at 100% zoom
- **Zoom: maximum cap**: Fixed zoom having no upper limit, allowing runaway zoom (#27, thanks @Ctrl-Alb)
  - Zoom is now clamped to a maximum of 300%
- **Zoom: inertia scroll mis-trigger**: Fixed trackpad inertia scroll (after fingers lifted) incorrectly triggering zoom (#27, thanks @Ctrl-Alb)
  - Added `phase` check in `scrollWheel` handler; inertia events (`.mayBegin`, `.cancelled`) are now ignored for zoom
- **Zoom: proper text reflow**: Fixed zoom not causing text to reflow — content overflowed instead of wrapping (#27, thanks @Ctrl-Alb)
  - Replaced `transform: scale()` (visual-only) with CSS variable `--zoom-scale` applied to font-size, which triggers proper text layout reflow

## [1.25.310] - 2026-04-18

### Added
- **RTL 语言自动检测**: 自动识别阿拉伯语、希伯来语等从右至左语言，动态应用 `dir="rtl"` 方向 (#23, thanks @3mrr4dy)
  - 当正文中 RTL 字符占比超过 30% 时自动切换方向
  - 切换回 LTR 内容时自动移除方向属性，不影响中英文等 LTR 语言

### Fixed
- **窗口最小尺寸限制**: 修复窗口无法缩小到 800×600 以下的问题 (#24, thanks @rebelporg)
  - 将最小宽度从 800 降低至 320，最小高度从 600 降低至 200
  - 允许用户灵活布局多窗口工作区（如分屏并排显示）
  - 修复两处硬编码的窗口最小尺寸：SwiftUI `.frame()` 和 `NSWindow.minSize` 设置
- **Dock 图标尺寸异常（macOS Sequoia）**: 修复图标在 Sequoia Dock 中显示比其他应用偏大的问题 (#22, thanks @ramysami)
  - 补全 AppIcon.appiconset 中所有必需尺寸（16×16 至 1024×1024）
  - 将图标内容填充率从 ~84–86% 调整为符合 Apple 指导规范的 ~80%，四边各留约 10% 透明边距
  - 提供完整分辨率集合，避免系统强制缩放单一大尺寸图标
- **Mouseless 等工具滚动变缩放**: 修复使用 Mouseless 等鼠标增强工具时，滚动操作触发页面缩放而非滚动的问题 (#21, thanks @qns7)
  - Mouseless 合成的滚动事件携带 `ctrlKey=true`，被 WKWebView 误识别为双指缩放手势
  - 拦截 `ctrlKey+wheel` 事件并重定向为 `scrollBy()`，正常滚动和真实捏合缩放均不受影响

## [1.24.303] - 2026-04-18

### Fixed
- **CSS 样式丢失（macOS 26 Tahoe）**: 修复在 macOS 26 Tahoe 上预览时样式表完全失效的问题 (#19)
  - 修复 `<base>` 标签插入导致样式表 URL 被重定向至用户文件目录的时序 bug
  - 将样式表预加载从异步 `fetch()` 改为同步读取 `cssRules`，避免 WKWebView 安全策略拦截

## [1.23.297] - 2026-04-17

### Added
- **PDF 导出字体大小选择**: 导出 PDF 时，保存面板内新增字体大小滑动条（8–72px）
  - 默认值自动匹配当前应用的有效视觉字号（基础字号 × 页面缩放比）
  - 使用 Cmd+/- 缩放后，导出滑动条会正确反映当前视觉字号
- **CLI PDF 导出**: 新增命令行 PDF 导出工具，适用于自动化/无头环境

### Fixed
- **实时预览刷新**: 新增文件变更自动检测，保存后立即刷新预览；新增 Reload 按钮和 Cmd+R 快捷键支持手动刷新 (#17, thanks @joergp)
  - 使用 `DispatchSource` 监听文件系统事件，兼容 vim/Emacs 等原子写入方式
  - 支持轮询兜底，确保各类编辑器保存方式均能触发刷新
- **多窗口 PDF 导出**: 修复同时打开多个 Markdown 文件时，Cmd+Shift+P 会弹出多个保存面板的问题（现在只导出当前活跃窗口）(#18, thanks @MxJ24)
- **PDF 导出内容分页**: 使用 NSPrintOperation 替换手动分页方案，PDF 内容不再出现截断或错位 (#18, thanks @MxJ24)
- **PDF 导出字体大小**: 修复导出的 PDF 字体大小与应用预览不一致的问题 (#18, thanks @MxJ24)
  - 修复 `@media print` 中 `.markdown-body` 字体大小覆盖问题，所有 em/rem 间距现按选定字号等比缩放
  - 导出后不再影响应用内预览的字体大小
- **键盘快捷键**: 修复 Cmd+Shift+P / Cmd+Shift+E 等快捷键在非活跃窗口也会触发的问题

## [1.22.275] - 2026-04-09

### Added
- **版本号显示**: 在 App 和 QuickLook 预览窗口右上角显示当前版本号
  - App 端：版本号位于工具栏按钮下方、目录（TOC）按钮左侧
  - QuickLook 端：版本号锚定在缩放按钮下方，与 App 端位置对齐
  - 使用等宽字体（10pt），半透明次要文字色，保持界面整洁

## [1.21.266] - 2026-04-03

### Fixed
- **目录面板底部截断**: 修复 TOC 侧边栏滚动到底部时最后一项显示不全的问题

## [1.20.261] - 2026-04-01

### Added
- **Mermaid 文件支持**: 新增 `.mmd` 扩展名支持，直接预览 Mermaid 图表文件
  - 自动将 `.mmd` 文件内容包装为 Mermaid 代码块进行渲染
  - 支持所有 Mermaid 图表类型：flowchart、sequence、gantt、classDiagram 等
- **更多 Markdown 变种扩展名**: 支持以下新扩展名
  - `.livemd` — Livebook 笔记本（Elixir 生态）
  - `.markdown` `.mdown` `.mkd` `.mkdn` `.mkdown` `.mdwn` — Markdown 变种
- **QuickLook Extension 注册增强**: 改进 macOS Ventura+ 上的 extension 注册
  - 使用 `pluginkit -e use` 显式启用 extension
  - 自动设置 extension 优先级，避免被已卸载的旧 extension 抢占
  - 使用 `UTExportedTypeDeclarations` 导出 UTI，解决 macOS 26 上 `.markdown` 等扩展名不被识别的问题

### Fixed
- **Swift 6 严格并发检查**: 修复编译警告
  - `PreviewViewController.swift`: 在 `Task.detached` 外捕获 `uiLanguage`
  - `WindowAccessor.swift`: 使用 `MainActor.assumeIsolated` 处理通知回调
  - `SharedPreferenceStore.swift`: 显式丢弃 `removeValue` 返回值
  - 测试文件添加 `@MainActor` 修饰

### Tests
- **FileExtensionTests**: 新增 37 个测试用例
  - Fixture 文件存在性验证
  - `.mmd` 包装逻辑测试
  - UTI 声明完整性验证
  - 所有新扩展名的渲染验证

## [1.16.204] - 2026-02-27

### Added
- **PDF 导出分页功能**: 导出 PDF 时自动将长文档分页为标准 A4 页面
  - 使用 CoreGraphics 将单页 PDF 切片为多个 A4 页面
  - 添加 `@media print` CSS 规则优化打印样式（防止代码块、图片跨页截断）
  - 最后一页内容自动对齐到页面顶部
- **欢迎窗口 (Welcome Window)**: 直接启动 App 时显示友好的欢迎界面，引导用户快速上手
  - 大号 "+" 按钮支持点击打开文件或拖拽文件到窗口
  - 简洁的使用提示：QuickLook 空格预览、双击打开、拖拽文件
  - 快捷入口：Open Settings (Cmd+,)、Troubleshooting 帮助文档
  - 显示应用图标，提升品牌识别度
- **用户友好帮助文档**: 新增 `docs/user/HELP.md`，由浅入深引导用户
  - 先体验成功（Space 预览）
  - 常见问题由简到难排查
  - 文末引导到高级排障文档

### Fixed
- **HTML 导出功能重构**: 参考 MPE (Markdown Preview Enhanced) 方案，彻底重构 HTML 导出逻辑
  - 生成纯净的独立 HTML 文件，不再包含臃肿的 JS Bundle（文件体积大幅缩小）
  - 内联所有 CSS 样式，确保离线打开时格式、字体、代码高亮正确显示
  - 自动将本地图片（GIF、PNG、JPG、SVG、WebP）转换为 base64 Data URI，确保图片在任意环境下正常显示
  - 导出的 HTML 可直接分享给他人，无需依赖原始文件路径
- **构建过程警告修复**: 清理 `make install` 过程中的冗余警告信息
  - 抑制 xcodebuild 的 DVTDeviceOperation 内部警告（Xcode 15/16 已知问题）
  - 抑制 Vite 打包的 chunk size 警告（本地应用无需严格限制块大小）
  - 静默 Vite 详细构建日志，提升输出可读性
- **安装脚本兼容性修复**: 修复 macOS 新版本上默认应用设置失败的问题
  - 将废弃的 Python LaunchServices 脚本替换为 Swift 原生实现
  - 修复 macOS 12+ 不再自带 LaunchServices Python 模块的问题

- **应用图标透明通道修复**: 修复 macOS 12.7 和 15.7 上应用图标显示白色方形背景的问题
  - 使用 AI 图像分割 (rembg) 精准移除白色背景，保留图标内部的白色纸张区域
  - 强制对齐图标边缘为数学直线，消除 AI 抠图产生的波浪边缘
  - 完美保留下拉阴影的半透明渐变效果

### Changed
- **Troubleshooting 文档优化**: 在 `docs/user/TROUBLESHOOTING.md` 顶部添加提示，引导普通用户先看 HELP.md

## [1.20.261] - 2026-04-01

### Fixed
- **Mermaid 无引号节点标签 `\n` 换行支持**: 修复 `\n` 在无引号节点标签（如 `A[text\nline2]`、`G{decision\nmore}`）中不换行的问题
  - Mermaid v11 只对双引号标签 `A["text\nline2"]` 转换 `\n` → `<br>`，无引号标签的 `\n` 会原样显示
  - 扩展 `preprocessMermaidNewlines` 函数，增加对 `[...]`、`{...}`、`(...)` 三种无引号括号的预处理
  - 使用字符类排除模式避免重复处理已由双引号 pass 处理的内容
  - 更新 JSDoc 文档记录 Mermaid 内部行为差异，避免后人重走弯路
- **主应用 Cmd+scroll 缩放支持**: 在主应用中按住 Cmd 键滚动鼠标现在可以缩放内容，与 macOS 预览.app 行为一致
  - 在 `ResizableWKWebView` 中添加 `scrollWheel(with:)` 方法拦截 Cmd+scroll 事件
  - 缩放范围限制在 0.5x–3.0x，与 QuickLook 扩展保持一致
  - 缩放级别自动持久化到用户偏好设置

## [1.19.256] - 2026-03-26

### Fixed
- **链接导航支持文件名含空格 (%20 编码)**: 点击链接现在可以正常打开目标文件
  - 新增 `LinkNavigation` 模块封装 URL 解析逻辑，使用 `removingPercentEncoding` 解码 href 中的空格
  - 新增测试用例覆盖 `%20` 编码的各种场景
  - 新增 `docs/debug/DEBUG_PERCENT_ENCODED_LINK_NAVIGATION.md` 记录问题和排查过程
  - 添加测试 fixture 文件用于手工验证

## [1.19.253] - 2026-03-21

### Fixed
- **Mermaid sequenceDiagram participant 标签引号渲染**: 修复 `participant U as "用户（飞书）"` 语法中引号被原样渲染到方块中的问题
  - Mermaid parser 不会自动剥除 `as "..."` 中的引号，导致用户看到 `"用户（飞书）"` 而非 `用户（飞书）`
  - 预处理函数新增 quote stripping 逻辑，在渲染前剥除 participant/actor alias 的引号
  - 同时支持带 `\n` 换行的 alias（如 `participant X as "line1\nline2"`）

## [1.19.250] - 2026-03-21

### Fixed
- **Sparkle 更新提示 Markdown 渲染**: 修复更新提示界面中 `**粗体**` 等 Markdown 语法显示为原始星号的问题
  - `scripts/generate-appcast.sh` 新增 Markdown → HTML 转换逻辑
  - 支持 `### 标题` → `<h3>`、`**粗体**` → `<strong>`、`` `代码` `` → `<code>`、`- 列表` → `<ul><li>`
  - 批量修复 `appcast.xml` 中历史版本的 description 格式
  - 更新 `/publish` 命令文档，明确说明 description 必须是 HTML 格式
- **帮助面板触发逻辑优化** (Issue #12): 修复 Cmd 长按触发功能指南时，在 Cmd+Tab、Cmd+Space、老板键等快捷键组合下误触发的问题
  - 新增修饰键检测：按下非修饰键（如 Tab、Space、字母）时立即取消 Cmd-hold 计时器
  - 仅纯 Cmd 长按（不按其他功能键）才会触发帮助面板

### Added
- **帮助面板偏好设置**: 新增复选框控制 Cmd 长按自动弹出功能
  - 用户可在帮助面板底部勾选/取消"按住 ⌘ 2 秒自动打开此面板"
  - 偏好设置持久化存储，重启后仍然生效
  - 仅 App 模式显示（QuickLook 模式下 Cmd 长按本来就不生效）

### Changed
- **帮助面板 badge 逻辑修正**: App 专属快捷键显示 "App" badge，两平台通用的功能不再显示 badge

## [1.18.246] - 2026-03-21

### Added
- **Mermaid 节点标签换行支持**: AI 生成的 Mermaid 图表常在双引号节点标签中使用 `\n` 表示换行（如 `A["line1\nline2"]`），但 Mermaid 默认将其渲染为字面字符串
  - 新增预处理函数，自动将引号内的 `\n` 转换为 `<br/>` HTML 换行标签
  - 用户无需手动修改 AI 生成的文档即可获得正确的换行效果
  - 支持所有 Mermaid 图类型（flowchart、sequence、class 等）

## [1.17.243] - 2026-03-17

### Fixed
- **App 模式文件实时刷新**: 修复用外部编辑器修改文档后 App 窗口内容不更新的问题
  - 使用 DispatchSource (kqueue) 监听文件变更事件 (.write/.delete/.rename)
  - 检测到变更后自动重新读取文件并触发重渲染
  - 兼容原子写入（先写临时文件再 rename）的场景
  - 通过 size + mtime 去重，避免无意义重渲染

## [1.17.239] - 2026-03-09

### Added
- **功能帮助面板**: 按 `?` 键或点击右上角 `?` 按钮显示完整的快捷键与功能指南
  - 区分 QuickLook 与 App 两种运行环境，显示不同的可用功能
  - QuickLook 环境显示黄色警告横幅，提示键盘事件被系统拦截
  - App 独占功能（导出、设置、检查更新）标记黄色 `App` badge
  - 两端都支持的功能标记蓝色 `QuickLook` + 黄色 `App` badge
  - 支持 `?` 键、按住 `⌘` 2秒、点击 `?` 按钮三种触发方式
  - 首次打开时显示 Toast 提示
- **多语言支持**: 帮助面板支持中英文切换
  - Settings → Appearance → Language 选择 System Default / English / 中文
  - 默认跟随系统语言设置

## [1.16.236] - 2026-03-05

### Added
- **链接状态栏**: 鼠标悬停在链接上时，当显示文字与实际链接不一致，在窗口左下角显示实际链接地址
  - 支持 QuickLook 预览和主应用
  - 自动解码 URL 编码的中文链接（如 `#%E4%B8%AD%E6%96%87` 显示为 `⚓ #中文`）
  - 显示链接类型图标：🔗 外部链接、⚓ 内部锚点、✉️ 邮件链接
  - 裸链接（显示文字即 URL）不显示状态栏，避免冗余

### Fixed
- **Help 菜单修复**: 修复 Help 菜单显示 "Help isn't available for FluxMarkdown" 的问题
  - 添加自定义 Help 菜单，替换默认的 macOS Help 菜单
  - FluxMarkdown Help (Cmd+?) 打开在线帮助文档
  - 添加 README、Report an Issue、Release Notes 快捷链接

## [1.16.231] - 2026-02-28

### Fixed
- **搜索框自动大写修复**: 禁用 macOS 在搜索框中自动将句首字母大写的行为
  - 添加 `autocapitalize="off"` 属性禁用自动大写
  - 添加 `autocorrect="off"` 属性禁用自动纠正
  - 添加 `autocomplete="off"` 属性禁用自动完成
  - 添加 `spellcheck="false"` 属性禁用拼写检查
## [1.16.226] - 2026-02-28

### Added
- **DMG 安装界面设计**: 全新的 DMG 安装界面，提供专业的用户体验
  - 现代化明亮风格背景设计，包含中文安装指引（「拖拽到 Applications 安装」）
  - Retina/HiDPI 支持：使用多分辨率 TIFF 背景图，确保在 Retina 显示屏上文字清晰锐利
  - 新增 `assets/dmg/` 目录存放 DMG 相关资源（SVG 源文件、PNG 背景图、TIFF 多分辨率图）

### Changed
- **DMG 构建工具迁移**: 从已废弃的 `appdmg` 迁移到 `create-dmg`
  - 更可靠的背景图片渲染
  - 原生支持 macOS Finder 布局特性

### Fixed
- **DMG 背景图片显示**: 修复背景图片不显示、只显示在左上角、不铺满窗口等问题
- **DMG Retina 支持**: 修复 Retina 显示屏上背景文字模糊的问题
- **DMG 窗口滚动条**: 修复 DMG 窗口出现横向和纵向滚动条的问题
  - 调整窗口尺寸以适配 macOS 标题栏高度
  - 隐藏文件 `.background` 定位到窗口内，避免触发滚动条
- **Applications 文件夹图标**: 修复 Applications 快捷方式显示为空白方框的问题
  - 使用 `--app-drop-link` 参数确保正确的 Finder 图标渲染

## [1.16.195] - 2026-02-26

### Changed
- **文档结构重组**: 按主题分层重构 `docs/` 目录结构，提升文档可维护性和可发现性
  - 新增 `docs/README.md` 作为文档总索引
  - 按主题分层：`docs/{user,dev,release,design,debug,testing,performance,research,licenses,history}/`
  - 合并图片相关文档到 `docs/features/IMAGES.md`，原始详细文档归档至 `docs/history/images/`
  - 合并性能相关文档到 `docs/performance/PERFORMANCE.md`，原始详细文档归档至 `docs/history/performance/`
  - 统一测试路径引用：`tests/` → `Tests/`
  - 删除根目录竞品 README 副本，仅保留 `docs/research/COMPETITIVE_ANALYSIS.md` 中的分析
  - 清理所有 `.DS_Store` 文件

### Fixed
- **搜索功能导致文件被标记为已编辑**: 修复在 Host App 中使用搜索功能时，Markdown 文件被错误标记为「已编辑」且修改时间戳更新的问题 (#8)
  - Host App: 为 `ResizableWKWebView` 隔离独立的 `UndoManager`，避免搜索输入触发 `DocumentGroup` 的 autosave
  - QuickLook Extension: 修复 security-scoped 资源访问泄漏，添加文件监控的 size/mtime 门禁
  - Web Renderer: 移除搜索框的 100ms 延迟 focus，添加 `stopPropagation()` 防止按键冒泡

### Added
- **脚注支持（Footnotes）**: 使用 `[^1]` 语法添加脚注，脚注内容自动渲染在文档底部
- **上标 / 下标**: 支持 `H~2~O`（下标）和 `x^2^`（上标）语法，适用于化学式和数学表达式
- **`==高亮==` 语法**: 使用 `==文本==` 语法高亮标注重要内容，渲染为 `<mark>` 标签
- **Smart 排版（Typographer）**: 自动转换直引号为弯引号（`"` → `""`），`--` 为连接号（–），`---` 为破折号（—）
- **Raw 源码切换**: 点击预览窗口右上角 `</>` 按钮，可在渲染视图与原始 Markdown 源码（带语法高亮）之间切换

### Added
- **YAML Frontmatter 支持**: 自动解析文档头部的 YAML 元数据，以表格形式美观展示
- **GitHub Alerts 支持**: 渲染 `> [!NOTE]`、`> [!WARNING]` 等 GitHub 风格提示框
- **扩展代码高亮**: 新增 20+ 种语言支持（Scala、Perl、R、Dart、Lua、Haskell、Elixir、Groovy、Verilog、VHDL、Makefile、TOML、Protobuf、GraphQL、PowerShell、Objective-C 等）
- **Vega/Vega-Lite 图表**: 支持 `vega` 和 `vega-lite` 代码块渲染为交互式 SVG 图表
- **Graphviz 图表**: 支持 `dot`/`graphviz` 代码块渲染为 SVG 图
- **导出功能**: 新增「导出为 HTML」和「导出为 PDF」菜单项（Cmd+Shift+E / Cmd+Shift+P）
- **Settings 界面**: 全新设计的偏好设置窗口（Cmd+,），支持：
  - Appearance: Light / Dark / System 主题切换
  - Rendering: Mermaid / KaTeX / Emoji 开关
  - Editor: 字体大小调整、代码高亮主题选择（Default / GitHub / Monokai / Atom One Dark）
- **文件格式支持**: 新增 `.mdx`、`.rmd`、`.qmd`、`.mdoc`、`.mkd`、`.mkdn`、`.mkdown` 扩展名

### Fixed
- **Host App Loading 卡死**: 修复 Host App 打开文档后一直显示 "Loading renderer..." 的问题（添加 `allowUniversalAccessFromFileURLs` 配置）
- **Settings 主题按钮点击失效**: 修复 Appearance 界面 Light/Dark/System 按钮随机无法点击的问题（ZStack 重构 hit-test 层级）
- **字体大小设置不生效**: 修复 Editor 中调整字体大小后文档无变化的问题
- **代码高亮主题不生效**: 修复 Editor 中切换代码主题后文档无变化的问题
- **KaTeX 开关不生效**: 修复 Rendering 中关闭 KaTeX 后公式仍然渲染的问题（动态重建 MarkdownIt 实例）
- **Emoji 开关不生效**: 修复 Rendering 中关闭 Emoji 后 `:name:` 格式仍然转换为图标的问题

## [1.15.165] - 2026-02-22

### Added
- **性能基线测试基础设施**:
  - 新增三层性能测试框架 (JS 引擎层 / Swift-WKWebView 层 / QuickLook 系统层)
  - 新增 7 个标准 Markdown fixture 文件用于可重复性测试
  - 新增 `benchmark/js-bench/` - Playwright 驱动的 JS 渲染基准测试
  - 新增 `benchmark/swift-bench/` - XCTest 驱动的 WKWebView 桥接层测试
  - 新增 `benchmark/ql-bench/` - qlmanage 端到端系统层测试
  - 新增 `benchmark/compare.py` - 优化前后对比脚本
  - 新增 `benchmark/run-all.sh` - 一键运行全部测试
- 新增 `docs/history/performance/BENCHMARK_BASELINE.md` - 完整基线测试报告文档
  - 记录了优化前的性能基线数据，为后续优化提供量化对比基准

### Changed
- **重大性能优化 (7项)**:
  - **P0 Bundle 拆分**: 移除 `vite-plugin-singlefile`，改用标准多文件输出 + `loadFileURL`
    - `index.html` 从 5.5 MB 降至 1.84 KB (-99.97%)
    - Swift 侧从 `loadHTMLString()` 改为 `loadFileURL(_:allowingReadAccessTo:)`
  - **P1-A highlight.js Tree-shaking**: 全量导入改为 `highlight.js/core` + 按需注册 24 种语言
    - hljs 贡献从 ~400 KB 降至 ~80 KB (-80%)
  - **P1-B Mermaid 单例化**: `mermaid.initialize()` 改为仅主题变化时调用
    - mermaid 热渲染从 ~186ms 降至 ~46ms (-75%)
  - **P2-A 图片 I/O 异步化**: `collectImageData()` 移至后台 `Task.detached`
    - 消除主线程图片 I/O 阻塞
  - **P2-B LocalSchemeHandler 启用**: 注册已实现未启用的 `local-md://` scheme handler
    - 删除 ~50 行 base64→Blob 转换代码，图片改为按需加载
  - **KaTeX 懒加载**: 改为按需动态 import，仅含公式文档加载
    - `index.js` 从 554 KB 降至 317 KB (-43%)
  - **Mermaid 预热**: 渲染后空闲时刻预热 mermaid chunk
    - 同会话二次打开 mermaid 文档从 ~380ms 降至 ~20ms

## [1.14.164] - 2026-02-18

### Changed
- **⚠️ LICENSE 变更为双许可证模式（重大变更）**:
  - **开源许可证**: 从 Non-Commercial 改为 **GPL-3.0**
    - ✅ 个人、教育、开源项目可免费使用
    - ✅ 任何修改必须以 GPL-3.0 开源
    - ✅ 满足 Homebrew 官方 cask 提交要求
  - **商业许可证**: 为闭源商业使用提供选项
    - 📧 联系 xy.kong@gmail.com 咨询商业授权
    - 📜 详情见 `LICENSE.COMMERCIAL`
  - **影响**: 
    - ✅ 移除了商业使用的硬性限制
    - ✅ 允许提交到 Homebrew 官方仓库
    - ✅ 允许企业和开源项目自由采用
    - ⚠️ 如需闭源商业化，需购买商业许可证

### Added
- **README 首屏优化**: 改进项目首页的视觉呈现和用户体验
  - 添加演示 GIF (`docs/assets/demo.gif`)，展示 Mermaid、KaTeX、代码高亮、TOC 等核心功能
  - 添加 GitHub badges（Stars、Release、Downloads、License）以增强信任度
  - 添加快速导航链接（中文文档、安装、常见问题）
  - 添加显式 Star CTA（Call-to-Action）以提升 Star 转化率
  - 改进 Troubleshooting 部分使用折叠式 `<details>`，降低视觉噪音
  - 同步更新中英文 README（README.md 和 README_ZH.md）

## [1.13.158] - 2026-02-16
_无待发布的变更_

## [1.13.156] - 2026-02-16
_无待发布的变更_

## [1.13.150] - 2026-02-13

### Added
- **更新后自动恢复文件**: 更新后自动打开上次查看的 Markdown 文件
  - 在主应用打开文件时自动保存文件路径
  - 通过 Sparkle 更新器检测更新安装事件
  - 更新完成后应用重启时自动恢复上次打开的文件
  - 使用 App Groups (group.com.xykong.Markdown) 实现跨进程持久化存储
  - 如果用户之前查看的文件已被删除，会优雅地处理失败情况
  - 只在更新后触发恢复，正常启动不会影响用户体验

## [1.13.149] - 2026-02-13

### Fixed
- **菜单重复问题**: 修复主应用菜单栏中出现两个 "View" 菜单的问题
  - 将 `CommandMenu("View")` 改为 `CommandGroup(after: .windowArrangement)`
  - 菜单项现在正确添加到系统默认的 View 菜单中，而不是创建新的独立菜单
- **国际化支持 (i18n)**: 修复"检查更新"菜单项和 QuickLook 预览中的 Toast 消息在英文系统中显示中文的问题
  - 将硬编码的中文文本替换为 `NSLocalizedString` 调用
  - 在 `en.lproj/Localizable.strings` 和 `zh-Hans.lproj/Localizable.strings` 中添加对应的翻译
  - 修复的字符串包括：
    - "Check for Updates..." (检查更新...)
    - "QuickLook preview does not support link navigation" (QuickLook 预览模式不支持链接跳转)
    - "Double-click .md file to open in main app for full functionality" (请双击 .md 文件用主应用打开以使用完整功能)


### Changed
- **菜单布局优化**: 优化菜单栏结构以符合 Apple Human Interface Guidelines (HIG)
  - **Find 菜单曲目**: 从 Window 菜单移至 Edit 菜单（位置：.textEditing 组）
    - 符合 macOS 标准惯例，快捷键 ⌘+F
  - **Show Source 菜单项**: 从 Window 菜单移至 View 菜单（位置：.toolbar 组）
    - 快捷键 ⌘+⇧+M，更适合视图切换操作
  - **Appearance 子菜单**: 从 Window 菜单移至 View 菜单（位置：.toolbar 组）
    - 主题选择属于视图配置，不符合窗口管理范畴
  - **Window 菜单**: 现在仅保留窗口管理相关功能
## [1.13.141] - 2026-02-13

### Fixed
- **锚点跳转宽容匹配（Anchor Link Tolerant Matching）**: 修复手写目录链接与自动生成的 anchor ID 不匹配的问题。
  - **问题场景**: 用户手写目录时，链接可能使用多个连字符（`---`）或混淆下划线（`_`）与连字符（`-`），导致跳转失败
  - **解决方案**: 实现三层渐进式匹配策略
    - **Level 1（最高优先级）**: 精确匹配，保证准确性
    - **Level 2**: 压缩多个连续连字符（`---` → `-`），解决手写目录多连字符问题
    - **Level 3**: 统一下划线和连字符（`_` ≈ `-`），解决视觉相似字符混淆问题
  - **优先级保证**: 当文档中同时存在相似标题时，优先跳转到精确匹配的标题
  - **技术实现**:
    - 新增 `compressMultipleHyphens()` 函数压缩连字符
    - 新增 `unifyUnderscoreAndHyphen()` 函数统一下划线和连字符
    - 新增 `findElementByAnchor()` 函数实现三层渐进式查找
    - 更新主内容区和目录面板的链接点击处理器
  - **测试覆盖**: 新增 `test/anchor-matching.test.ts`，包含 10 个测试用例，覆盖所有匹配层级和优先级场景
  - **兼容性**: 与主流 Markdown 编辑器（Typora、VSCode）的宽容行为一致，提升用户体验
  - **用户体验**:
    - 手写目录小错误不再影响跳转
    - 不需要精确记住下划线还是连字符
    - 容错设计，减少用户认知负担
