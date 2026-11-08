# Project Context

## Purpose

FluxMarkdown 是一个 macOS QuickLook 扩展，让用户在 Finder 中按 Space 即可即时预览 Markdown 文件。支持 Mermaid 图表、KaTeX 数学公式、GFM、代码高亮、TOC、缩放、滚动记忆和主题切换。

## Tech Stack

- **Swift / AppKit**: QuickLook Extension (`MarkdownPreview`) + Host App (`Markdown`)
- **WKWebView**: 嵌入在 Extension 中的 WebView，负责展示渲染结果
- **TypeScript / Vite**: Web 渲染引擎 (`web-renderer/`)，编译为本地 HTML、JS/CSS、字体与 WASM 资源
- **markdown-it**: Markdown 解析器，配合多个插件（KaTeX、emoji、footnote 等）
- **highlight.js**: 代码语法高亮（core + 显式语言注册）
- **mermaid**: 图表渲染（按需动态 import，仅主题变化时 initialize）
- **KaTeX**: 数学公式渲染
- **XcodeGen**: 从 `project.yml` 生成 `.xcodeproj`（`.xcodeproj` 不提交）

## Project Conventions

### Code Style
- Swift: 遵循 Swift API Design Guidelines，使用 `os_log` 记录日志（不用 `print`）
- TypeScript: noImplicitAny + 独立 typecheck 门禁，使用 `logToSwift()` 而非 `console.log` 记录调试信息
- 不允许 `@ts-ignore`、`as any`、空 catch 块

### Architecture Patterns
- **JS Bridge**: Swift 通过 `evaluateJavaScript` 调用 `window.renderMarkdown(text, options)`；JS 通过 `window.webkit.messageHandlers.logger.postMessage()` 回传日志
- **握手协议**: JS 加载完成后发送 `"rendererReady"` 消息，Swift 收到后才调用 `renderMarkdown`
- **共享进程池**: `WKProcessPool` 单例，避免多 WebView 实例时进程爆炸

### Testing Strategy
- Swift 单元测试: `Tests/MarkdownTests/`（XCTest，直接包含源码，不 import 模块）
- JS 测试: `web-renderer/test/`（Jest）
- 性能基线: `benchmark/` 三层测试框架（Playwright / XCTest / qlmanage）
- 新功能必须有对应测试；性能优化必须跑 benchmark 对比

### Git Workflow
- 自有开发（包括 Agent 实现的修复/功能）: feature 分支 → 验证 → 本地直接合并 master → push；除非用户明确要求，否则不创建 PR。PR 流程仅用于外部贡献或明确要求的 PR。
- Commit 规范: Conventional Commits（`feat:`, `fix:`, `perf:`, `docs:`, `chore:` 等）
- `.xcodeproj` 不提交（XcodeGen 生成）；`dist/` 不提交（Vite 构建产物）
- 发布、恢复和已发布文案纠错统一遵循 `docs/release/RELEASE_PROCESS.md` 与
  `docs/release/RELEASE_RUNBOOK.md`，包括默认 minor、条目内署名、三处同步和实际验收。
  自有文档及 OpenSpec 归档同样直接提交，不另建 PR；历史记录不覆盖当前发布规则。

## Domain Context

- **沙箱限制**: QuickLook Extension 必须在 App Sandbox 下运行，只有 `user-selected.read-only` 权限
- **进程复用**: QuickLook framework 会复用 extension 进程，`viewWillDisappear` + `viewDidLoad` 会多次调用
- **共享 ProcessPool**: 使用 `PreviewViewController.sharedProcessPool` 让所有 WebView 实例共用 Web Content 进程
- **文件监控**: `DispatchSourceFileSystemObject` 监控文件变化，自动重新渲染
- **图片处理**: 本地图片通过 `collectImageData()` 读取并 base64 编码后传给 JS；`LocalSchemeHandler.swift` 已注册，仅允许预算内明确引用的图片

## Important Constraints

- macOS 部署目标: **11.0+**
- QuickLook Extension 必须 `SKIP_INSTALL: YES`，通过 Host App 嵌入分发
- 版本号由 `.version` 文件管理，build 命令为 `make`，不手动修改 `MARKETING_VERSION`
- 性能目标: Layer 3 冷启动 p50 ≤ 100 ms（当前基线 ~205 ms）

## External Dependencies

- **Sparkle**: 自动更新框架（`exactVersion: 2.8.1`）
- **XcodeGen**: 从 `project.yml` 生成项目文件（`make generate`）
- **Vite**: 资源分包，通过 flux-renderer scheme 加载；Typst WASM 与字体离线打包。

## Build compatibility and audit remediation

See `docs/dev/BUILD_COMPATIBILITY.md` and `docs/debug/DEBUG_AUDIT_FIXES_2026-10-10.md`. Release deployment remains macOS 11 with Xcode 16.4; local Xcode 27 diagnostics explicitly override the target without changing product configuration.
