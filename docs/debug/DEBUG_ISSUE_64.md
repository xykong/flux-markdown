# Issue #64：Markdown 全要素测试集兼容性调查

## 调查范围与初始状态

- 日期：2026-11-04。
- Issue：https://github.com/xykong/flux-markdown/issues/64 。当前为 Open，标签为 enhancement、feature-request、renderer。
- 本地版本：1.42.645；调查起点：`1782a35`；初始工作区干净。
- 用户请求：查看线上 issue，调查现象、支持范围及优先级；本次不修改渲染行为、不发布或回复 issue。
- 报告人提供 `markdown.zip`，其中主文档为 `markdown-preview-test.md`，并附本地 SVG 和文本资源。文档同时包含 CommonMark/GFM、各工具专用扩展和故意无效语法。
- 唯一评论补充：数学部分可在 https://kerzol.github.io/markdown-mathjax/editor.html 打开；未提供 FluxMarkdown 版本、截图或具体失败条目。

## 复现与验收方法

1. 下载 issue 附件，读取原始 Markdown；不执行其中示例代码。
2. 对照当前生产渲染入口、插件、HTML 清理策略和既有测试。
3. 用附件中的最小原文样例执行当前渲染器，区分实际输出与代码推断。
4. 记录已有支持、确认缺口、设计边界及建议优先级；明确尚未验证的原生/WebKit 行为。

## 调查结果

### 结论

这是兼容性增强请求，包含多个独立能力，不宜按“全部 Markdown 语法”整体承诺。
当前可确认的首要缺口集中在公式输入识别与跨公式引用；并非基础公式排版全部失效。

GitHub 最新发布为 [v1.42.645](https://github.com/xykong/flux-markdown/releases/tag/v1.42.645)（2026-10-29）。本地 `web-renderer/` 相对于该标签无差异，因此以下入口级结果适用于该发布的渲染源码；尚未验证发布 App 的原生运行环境。

### 数学部分：当前生产入口的实际输出

| 附件样例 | 实测结果 | 说明 |
| --- | --- | --- |
| `$E = mc^2$`、根号、中文混排 | 生成 KaTeX | 基础行内公式正常 |
| `$$...$$` 积分 | 生成 KaTeX | 基础块公式正常 |
| `aligned` 对齐、多行分式与中文 | 生成 KaTeX，无解析错误 | 不需要因此更换公式引擎 |
| `bmatrix` 矩阵、`cases` 分段函数 | 生成 KaTeX，无解析错误 | 同上 |
| `\(a^2 + b^2 = c^2\)` | 普通文本，分隔符反斜杠被 Markdown 转义处理 | 未识别此类数学分隔符 |
| `\[...\]` 求和 | 普通文本 | 未识别此类数学分隔符 |
| `math` 围栏代码块 | 普通代码 | 未注册数学围栏处理 |
| `\tag{1}\label{eq:pythagoras}` | 整个公式回退为错误源码 | KaTeX 报 `Undefined control sequence: \label` |
| 单独 `\tag{1}`（用于隔离原因的补充样例） | 生成 KaTeX 和编号 | `\tag` 本身不是失败原因 |
| `$\eqref{eq:pythagoras}$` | 错误源码 | KaTeX 报 `Undefined control sequence: \eqref` |
| `\$5.00`、代码跨度中的 `$HOME` | 保持文字 | 货币与代码保护正常 |
| `\unknownMarkdownPreviewCommand{x}` | 错误源码；后文继续渲染 | 附件明确设计的无效输入，应验证回退而非实现此命令 |

根因对应 `web-renderer/src/index.ts` 的 `buildMd()` 与 KaTeX 懒加载条件，以及已安装的 `@iktakahiro/markdown-it-katex/index.js`：

- 懒加载仅检测美元符号；插件自身也只注册美元分隔的 inline/block 规则。因此仅扩大加载条件不足以支持圆括号/方括号公式。补充实测：同文档加入 `$x$` 触发插件加载后，另外两种分隔符依然不渲染。
- `math` 没有专用围栏分支，按未知语言代码显示。
- 当前没有文档级公式标签表和交叉引用解析，不能通过移除 `\label` 或忽略错误来实现正确的引用。

报告人给出的 [MathJax 示例页](https://kerzol.github.io/markdown-mathjax/editor.html) 源码使用 MathJax 2.7.0，显式配置了美元/圆括号行内分隔符和 AMS 自动编号，并在 Markdown 解析前排版数学。可以作为需求参照；本次没有把附件在该站点完整执行，不能据此确认其支持附件全部条目。

### 其他语法与边界

实测附件可渲染到“文档结束标记”，生成 6 个 `.katex` 和 3 个 `.katex-error`；其中 2 个错误来自标签/引用缺口，1 个是故意无效命令。Front Matter 元数据表与脚注存在。此结果不等于视觉、字体、图片加载和导出全部通过。

| 类别 | 当前证据与判断 |
| --- | --- |
| 定义列表、缩写、`++插入++` | 定义列表/缩写最小样例和附件文本均保留原始标记；插件清单无对应插件 |
| `[TOC]` / `[[toc]]` | 原文保留；应用已有自动目录侧栏，正文占位符兼容是独立增强 |
| `::: info` 容器、图片 `{#id .class width=...}` 属性 | 最小样例保留标记，图片属性未应用 |
| Wiki 链接、Obsidian 专用语法、Pandoc 属性、文献引用 | 附件混合多种方言；不应视为 CommonMark/GFM 必须支持项。文献引用还缺少参考文献数据库 |
| PlantUML、WaveDrom、ABC | 附件输出保留普通代码块；当前未接入对应图表引擎 |
| Mermaid、Graphviz、Vega-Lite | 代码已有专用处理；本次 Jest 使用图表 mock，只确认处理路径，不声称实际图表引擎/视觉验收通过 |
| HTML/SVG/MathML、details、表格 | 清理策略允许展示型 HTML/SVG/MathML，既有相关测试通过；原生布局与交互仍需 WebKit 验证 |
| 表单按钮、脚本、iframe、模板执行 | 清理策略禁止部分主动内容；MDX/Liquid 等在附件里本来就是代码展示，不是执行支持请求 |
| `tel:` 链接 | 实测文字保留、`href` 被清理；`safe-html.ts` 协议规则未放行。应作为单独的协议支持决策，连同原生打开行为验证 |

既有 `docs/dev/renderer/RENDERER_MARKDOWN_IT_PLUGIN_ROADMAP.md` 已讨论定义列表、属性、缩写等，但它是 2026-01 的 Draft，包含过时的换行、资源协议和安全状态，不能直接当作当前实现或已批准方案。

### 建议处理顺序

1. **第一批：数学输入兼容。** 支持 `\(...\)`、`\[...\]` 和 `math` 代码块，沿用 KaTeX；覆盖纯括号公式文档、混合分隔符、代码跨度/围栏、转义、货币、关闭公式开关及错误反馈。避免全局字符串替换破坏代码和普通文本。
2. **第二批：公式编号与引用。** 明确 `\label`、`\eqref`、前向引用、重复/缺失标签、重渲染及导出的语义后实现文档级解析。可以评估现有插件或 MathJax，但当前证据不足以要求整体换引擎。
3. **后续轻量兼容。** 优先评估定义列表、缩写和插入文本；再评估安全受限的图片/标题属性与常用容器。
4. **独立评估。** PlantUML/WaveDrom/ABC、Obsidian 全套、文献体系和模板执行按真实使用需求另立范围；保留可读回退。

新增能力进入实现前按 OpenSpec 流程形成具体方案；本次只有调查记录，没有新增功能或提案审批请求。

## 验证与限制

- 临时诊断套件调用真实 `window.renderMarkdown`，覆盖附件全文及数学/扩展最小样例，共 21 个用例；所有渲染调用完成，按 DOM 记录以上结果。这里的“通过”只表示诊断执行成功，不表示未支持语法满足目标行为。临时文件已删除。
- 相关既有测试：`extended-syntax`、`renderer`、`safe-html`、`yaml-frontmatter`、`github-alerts`，5 个套件、62 个测试通过。
- Jest 的 GitHub alerts 插件及图表模块存在 mock；不据此声称 Obsidian callout 或真实图表兼容。
- 未构建或安装 App，未测真实 QuickLook/Finder/WebKit、网络与本地资源加载、窄屏/深色/打印/PDF；没有修改 GitHub issue、标签或发布状态。

## 后续：完整数学能力设计（2026-11-04）

用户进一步要求全面分析、设计完整数学/标签方案及改写实施任务。新设计见 [完整数学渲染方案](../design/ISSUE_64_MATH_RENDERING.md)、[改写后的任务要求](../design/ISSUE_64_TASK_REQUIREMENTS.md) 和 `openspec/changes/add-complete-math-rendering/`。

该扩大目标下推荐验证文档级 MathJax 4 方案，取代本调查最初“先补 KaTeX 输入、以后再讨论引用”的分阶段建议。已新增固定原始语料、Node 与真实本地 scheme WKWebView 的隔离引擎证据；完整产品实现、独立 LaTeX 裁判及实际 QuickLook/Finder/导出验收仍待进行。以上早期调查结果作为历史基线保留。
