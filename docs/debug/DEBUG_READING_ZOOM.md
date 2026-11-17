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

## 验收反馈第二轮（2026-11-18，基线 f24bae3）
用户指出文件菜单重复“打开/打开最近使用”，以及 Mermaid 未放大、只有外围文字和控件变大。
- 已定位：Mermaid 每次按缩小后的 CSS 列宽重新 fit，抵消正文 zoom；图表工具栏继承正文 zoom。原测试没有覆盖 Mermaid 的这组组合行为。
- 先定义验收：图上双指仅改变该图，另一张图/正文字号/目录/按钮屏幕尺寸不变；40 个连续样本中图内锚点偏移 ≤3 px；手势即使移出图也不换目标；反向、结束/取消、新手势、先按钮后手势和手势后按钮均连续；大图可在局部横向滚动。
- 正文 200% 时 Mermaid 实际绘图必须放大，工具按钮尺寸误差 ≤1 px，图本身超宽只在图内滚动。对 Mermaid / SVG 共用控件保持一致。
- 菜单必须在欢迎页和文档窗口真实运行状态各只有一个 Open 和 Open Recent；Cmd+O 和最近文件历史保留，不能只靠源码字符串断言。
- 修改后重跑真实 WebKit、Jest、原生相关检查，再安装明确标识的开发版供用户继续验收。

### 第二轮实现与结果
- 双指开始时命中 Mermaid / 独立 SVG，整个手势锁定该图，按累计增量修改与按钮共用的连续倍率；保存图内归一化坐标并补偿图内水平滚动、页面垂直滚动。正文、另一张图和全局阅读倍率不变。结束/取消后释放目标，新手势重新命中。
- 原生只转发双指样本，renderer 回传全局倍率或 null（图表）。原生忽略过期回调并吸收倍率结果，不再次发起缩放，避免异步回写相互覆盖；取消时使用最后有效增量。
- Mermaid 自动 fit 使用 100% 阅读列基准，连正文 padding/行号栏的变化一起补偿；否则简单乘 zoom 仍会抵消部分放大。工具栏反向抵消正文倍率，实际按钮保持固定尺寸。
- 文件菜单保留 DocumentGroup 自带的 Open / Cmd+O，删除自定义重复 Open；保留持久化 Recent，按原生 clearRecentDocuments 动作识别并移除系统 Recent。监听菜单条目变化进行幂等整理，Recent 放在 Open 后面。实装探测曾发现系统会在 applicationWillUpdate 之后补回 Open，因此没有继续与它争用菜单所有权。
- Apple 参考：[DocumentGroup](https://developer.apple.com/documentation/swiftui/documentgroup)、[CommandGroup](https://developer.apple.com/documentation/swiftui/commandgroup)。本机 SDK/真实 SwiftUI 探针确认新旧命令分组不能只凭 .newItem 的名称推断覆盖范围。
- 69 组 Jest / 629 项通过；9 项原生缩放、菜单、最近历史测试通过。SwiftUI 独立运行探针在欢迎页与新建文档状态均只有一个 Open / Recent；安装后的 App 通过 AX 只读菜单回读，打开文档前后均只有一组且顺序正确。主进程闲置 CPU 0%，未观察到菜单监听重建循环。
- Apple Silicon 与 Intel `he-macpro` 的 4 组真实 WebKit 缩放检查通过；新增宽大 Mermaid 局部双指 40 个样本、图内锚点 ≤3 px、移出图不切目标、按钮后倍率衔接、全局 200% 时真实画布放大、按钮尺寸 ≤1 px 误差。另补 18 节点纵向高图（大于视口高度），连续 40 个样本检查图内垂直锚点与 2 倍实际高度。
- 已安装并后台启动 `/Applications/FluxMarkdown.app`，显示版本 `1.51.834-dev-zoom2`；App/QuickLook 两份 renderer 共 173 文件分别与已验证产物摘要一致，codesign 深度验证通过。保留上一版备份，现有编辑器关联与最近文件历史保留。
- 已打开扩充的 `Tests/fixtures/zoom-test.md`，包含两张独立 Mermaid 及图上/正文手势说明。真实触控板的主观体验由用户继续验收；未发布正式版本。

第二轮复验：
```sh
FLUX_WEBKIT_CASE_FILTER='Mermaid pinch' scripts/test-renderer-webkit.sh
swiftc -parse-as-library Sources/Shared/DocumentMenuPolicy.swift \
  Tests/DocumentMenuIntegration/Probe.swift -o /tmp/flux-menu-probe-test
/tmp/flux-menu-probe-test
```

## 双指双击重置（2026-11-18，基线 5f12e3f）
- 用户确认第二轮缩放体验良好，要求图上双指双击恢复默认。
- 语义：图上 smartMagnify 只还原该图的局部倍率到 100%，保留文档倍率（例如文档 150% 时图恢复为该文档倍率下的默认尺寸）；与百分比按钮一致。正文 smartMagnify 恢复文档 100%。同样适用于独立 SVG。
- 预设验收：图上重置后图形与百分比按钮均回到默认值，其他图、文档倍率和按钮尺寸不变；重复重置幂等；待处理的连续缩放不能覆盖重置；保留可行的图内阅读锚点。原生转发指针位置，回读不重复发起缩放。
- 实现复用图表连续缩放和锚点补偿；重置前清除排队样本与旧手势会话，避免下一帧把重置覆盖。原生 smartMagnify 使用事件位置命中图表，null 回执保留文档倍率，正文回执 1 则同步保存文档倍率；旧回调受样本序号隔离。
- 69 组 Jest / 630 项通过，10 项原生相关 XCTest 通过。Apple Silicon / Intel 的真实 WebKit 检查覆盖高图重置、文档 150% 下局部重置、按钮显示恢复 100%、其他倍率隔离；单元测试另覆盖重复重置与排队样本取消。
- 已安装并后台启动 `1.51.834-dev-zoom3`，App/QuickLook 两份 renderer 的 173 文件各自与最终 bundle 摘要一致，深度签名检查通过；文件菜单仍唯一。已打开更新的手工验收文件，上一版 zoom2 已单独备份。真实触控板继续由用户体验验收。
