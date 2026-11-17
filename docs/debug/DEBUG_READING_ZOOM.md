# 正文缩放与阅读位置稳定性

## 初始状态（2026-11-18）
- 基线：b9b0466；用户报告双指缩放连目录一起放大，任意阅读位置开始手势会跳到左上。
- 原始材料（直接读当前源码，不依赖历史印象）：`NativeMagnifyingWebView.swift`、两个宿主缩放入口、renderer 缩放接口及真实 WebKit 集成测试。
- 原因：双指修改 WKWebView.magnification（0.25–5），菜单/Cmd+滚轮修改 pageZoom（0.5–3），renderer 的 setZoomLevel 仅写无人消费的 CSS 变量。三套状态和几何模型不一致。旧测试只验证算式、源码和 DOM 未丢失，没有布局证据。
- Apple API 参考：https://developer.apple.com/documentation/webkit/wkwebview/setmagnification(_:centeredat:) ；https://developer.apple.com/documentation/webkit/wkwebview/pagezoom 。两者都属于整个 WebView，不提供正文/目录隔离。

## 修复范围与方法
这是现有阅读缩放的缺陷修复：统一双指、菜单、快捷键和 Cmd+滚轮的正文倍率；维持 50%–300%，100% 重置；目录/搜索/工具栏不放大，正文重排而非整页平移截图。
- 宿主共用 readingZoom；WebKit pageZoom/magnification 保持默认值。
- renderer 对正文应用 CSS zoom，按可用列宽重排；优先以指针下文本字符作锚点，空白/图表退化为元素内相对位置；菜单默认锚定阅读区中心。
- 同一次手势冻结同一个字符/元素锚点，结束或取消时释放；DOM 替换时重取锚点，避免连续重排逐帧改选字符而累积漂移。
- 每帧合并更新，避免同一帧多次强制布局；不重渲染 Markdown，不改变选区、主题和局部图表倍率。
- 独立验证使用真实 WebKit 的 getBoundingClientRect、文本 Range、scrollWidth，而非复刻实现算式。

## 预先定义的验收
- 正文 150%/200% 时文字实测尺寸随倍率变化；目录宽度和字体误差 ≤1 px。
- 长文中段缩放和重置：指定文本字符视口纵坐标位移 ≤3 px（文首/文尾滚动边界除外）。不能跳回文首。
- 连续放大缩小、50%/300%、左右目录、App/QuickLook、源码模式、宽表格/图表：正文可读，页面无新增横向溢出，目录仍可使用。
- 原有 renderer 测试、真实 WebKit 集成及 Swift 构建通过。实际触控板与 Intel 设备未做的检查单独记录，不以合成调用冒充硬件验证。

## 验证结果
- renderer：68 个 Jest suite、626 项测试通过；TypeScript + Vite production build 通过。
- 原生：Debug arm64 编译与 31 项缩放相关 XCTest 通过。使用当前 Xcode 的 `MACOSX_DEPLOYMENT_TARGET=12.0` 本地诊断覆盖参数，产品配置的 macOS 11 最低目标未修改。
- Apple Silicon 真实 WebKit：App/QuickLook × 左右**可见的 240 px 目录** × 50%/100%/150%/200%/300%，20 个离散采样通过；目录字号不变，字符高度比例符合预期，无整页横向溢出。
- Intel `he-macpro`（x86_64，macOS 26.7.3）使用相同最终 bundle 与测试源码，3 组真实 WebKit 检查全部通过；包括连续手势固定锚点检查。不是模拟 Intel 或 macOS 11 运行时测试。
- 实测离散采样最大锚点漂移：Apple Silicon 0.797 px，Intel 0.938 px；同步布局耗时分别 5–7 ms、9–14 ms（80 章节测试文档，20 个采样/设备）。原生测试构建产物通过 `codesign --verify --deep --strict`，不代表正式发行签名/公证验收。
- 同一次固定指针手势增加 40 个递增采样，检查最初的同一个字符；另覆盖源码中段、HTML 导出、600 px 窄窗、英文/阿拉伯 UI、公式、宽表格、长代码和 SVG 局部倍率保持。
- 旧实现对照：将 `b9b0466` 的原始 `setZoomLevel` 函数装入同一真实 WebKit 测试，得到预期失败 `body did not scale: 1.5 1`，证明几何验收能够识别只改变量、不改正文的实现。
- 100%/200% WebKit 原始截图已逐张检查：正文重排，目录与顶部工具条尺寸一致。截图：`/tmp/flux-zoom-visual/Reading zoom visual 1.png`、`Reading zoom visual 2.png`。这是渲染产物截图，不是触控板录屏。
- 打印通过 `@media print` 强制正文 zoom=1，字号由既有 print-font-size 控制，避免把阅读倍率再乘一次。HTML 原本只导出克隆的 innerHTML，保留该隔离。
- Cmd+滚轮移至共享宿主：开始阶段即使增量为零仍建立基准；无 phase 的鼠标滚轮从当前倍率递增；屏蔽惯性，结束阶段不会丢掉倍率保存。键盘与智能双击重置走同一状态。

### 原始参考与选择依据
- [Apple magnification](https://developer.apple.com/documentation/webkit/wkwebview/setmagnification(_:centeredat:))：整页视觉放大包含网页里的目录，不能实现正文/控件隔离。
- [Apple pageZoom](https://developer.apple.com/documentation/webkit/wkwebview/pagezoom)：对所有页面内容缩放，因此也不能单独解决目录问题。
- [W3C Reflow](https://www.w3.org/WAI/WCAG22/Understanding/reflow.html)：放大文字后仍在可见宽度重排，降低逐行横向滚动和丢失阅读位置的负担；宽表格/图表保持局部滚动。这里作为设计依据，不是完整合规评估。
- [CSS Viewport zoom 草案](https://drafts.csswg.org/css-viewport/#zoom-property)：区分元素参与布局的 zoom 与视觉 viewport 放大；具体行为仍以目标 WebKit 实测为准。

### 独立验证与边界
- 几何断言直接读取实际文字 Range 与目录 getBoundingClientRect；不复刻 Swift 的缩放算式来证明阅读体验。先断言目录真实可见且宽度 240 px，防止拿隐藏目录的零宽度作比较。
- 跨帧等待后检查位置；性能计时只包围同步缩放/布局调用，不包含测试 setTimeout（后台 WebKit 会节流计时器）。该数据不代表整个触控板到屏幕的端到端延迟或持续帧率。
- 保留 50%–300% 范围；文首/文尾受合法滚动边界限制，不能保证锚点无限固定。
- 未替换 `/Applications` 中的安装版，未生成/发布正式版本，未做真实触控板操作、系统 Finder 手势或安装版业务验收。无 macOS 11 运行时测试；按维护者既定范围不作为本次阻塞。
- 原始测试日志在 `/tmp/flux-zoom-{webkit-final,jest-final,xctest-final,intel}.log`，可用下述命令重跑。

```sh
cd web-renderer
npm test -- --runInBand
npm run build
cd ..
FLUX_WEBKIT_CASE_FILTER='Reading zoom' scripts/test-renderer-webkit.sh
FLUX_WEBKIT_CASE_FILTER='reading layout' scripts/test-renderer-webkit.sh
xcodebuild -project FluxMarkdown.xcodeproj -scheme Markdown -configuration Debug \
  -destination 'platform=macOS,arch=arm64' MACOSX_DEPLOYMENT_TARGET=12.0 \
  ONLY_ACTIVE_ARCH=YES -jobs 2 test \
  -only-testing:MarkdownTests/NativeMagnificationTests -only-testing:MarkdownTests/AppZoomTests
```
