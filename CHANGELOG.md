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

## [Unreleased]

### Fixed
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
