# Issue #64 数学研究证据

日期：2026-11-04。生产基线 1.42.645 / e3dd17e；研究引擎 MathJax 4.1.3。

## 输入与结果

- `manifest.json`：GitHub 来源、建议页固定提交及附件逐文件 SHA-256。
- `Tests/fixtures/issues/64/`：原文及 3 个配套资源，按 zip 原字节保存（不包含 Apple 资源分叉）。
- `math-cases.json`：13 个数学项的源码、行号、inline/display、有效/故意无效分类。M01–M11 是有效 TeX，M12 是故意无效，M13 是有效 MathML。
- `semantic-results.json`：真实 MathJax 的规范 MathML 输出、错误、前向引用、重复/缺失标签、全新文档重复渲染结果。
- `webkit-results.json`：真实 WKWebView 中的 SVG、几何、中文文本、标签表、链接属性、重复渲染结果。单次用时只是观察值，不是性能基准。

两种执行环境均是隔离的引擎研究，输入数学项已提前提取并转换成确定的数学节点。它们不验证生产 Markdown tokenizer，也不构成独立于 MathJax 的正确性裁判。

关键观察：有效项都产生输出；未知命令、重复标签被识别；缺失引用只是 `(???)` 而不报异常；浏览器 SVG 链接只有 `data-mjx-href`，仍需适配真实链接后再验证鼠标、键盘和导出。`nativeHrefTargetExists` 为 false 记录的是该接入缺口；`mathJaxTargetExists` 检查运行时元数据指向的实际 ID。公式数量按 case 计算，不能按 SVG 数量计算。

## 复现

在 macOS、Xcode Command Line Tools、Node/npm 环境运行：

```sh
scripts/research/issue64-math/run.sh
```

脚本在新的临时目录按研究专用 lockfile 安装依赖，调用 Node 引擎，再编译 Swift WKWebView 探针；使用生产 `RendererBundleSchemeHandler` 加载本地研究页面。结果目录打印到终端，保留供检查。不会安装 App 或修改生产依赖。

本次机器：macOS 27.0.1（26A434），Node v25.9.0，npm 11.12.1。浏览器数据存储为 nonPersistent。研究页面 CSP 禁止远程 script/font/connect；允许本地资产以及引擎生成的 blob Worker/data 字体。初版禁止后二者时排版挂起，CSP 事件分别指向 worker-src 和 font-src；允许后本地排版完成。

手工诊断时通过临时 handler 日志看到本地 `tex-mml-svg.js`、`sre/speech-worker.js`、`base/en/nemeth` 语音数据请求。WebKit 对该自定义 scheme 的 Resource Timing 返回空数组，因此不能用 `resources: []` 宣称没有加载资产；离线证据来自本地文件路径、CSP 与实际完成的排版。生产方案仍须做冷缓存、拒绝外网及最终 bundle 的验收。

用户建议的远程示例页在本次 WKWebView 中有脚本错误/超时，未得到完整可用结果；对它的评价采用固定源码分析，不把超时归因为该项目必然失败。

## 尚待独立验证

LuaLaTeX/amsmath 的编号和布局参照、逐图视觉审查、VoiceOver、真实 QuickLook/Finder、最旧受支持系统、PDF/HTML 导出、生产 sanitizer 和性能基准均未完成。正式验收方法在 `docs/design/ISSUE_64_MATH_RENDERING.md`。
