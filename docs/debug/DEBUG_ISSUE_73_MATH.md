# Issue #73：Quick Look 数学公式显示失败调查

## 初始证据（2026-11-17）

- Issue：https://github.com/xykong/flux-markdown/issues/73
- 报告者：@syutheoria；当前 OPEN，无评论。
- 正式版与当前源码版本：1.51.834；当前 HEAD：517275c。
- 环境：arm64，macOS 26.7.2 (25G325)，Quick Look；KaTeX / Typst 均开启。
- Incident：396BFBCB-3BE8-4BAD-AF2B-B7933B255529；发生时间：2026-11-17T06:33:26Z。
- 操作 math、阶段 failed、分类 operationFailed；Error chain 为空。
- 未提供触发公式、Markdown 样例或截图，目前不能重现报告者的问题，不能确认根因或声明修复。

## 调查目标与验收边界

1. 核对数学渲染及错误反馈路径，确认报告中现有信息能定位到什么范围。
2. 检查现有数学测试及最近改动，尝试自动验证可疑路径。
3. 记录已验证事实、假设和仍需的最小重现材料；本次调查不代表已修复或发布。

## 已核对的代码事实

- `web-renderer/src/index.ts:1067–1090`：TeX/MathML 由 `math-engine`（MathJax SVG）渲染；设置名 `enableKatex` 仍沿用历史命名，不能据此认定是 KaTeX 抛错。
- 数学引擎区分 `syntax`、`output`、`unresolved-reference`、`input-limit` 和 `unsupported-resource`。
- 反馈层只将图片资源失败单列为 `resourceUnavailable`，其余上述失败统一上报 `operationFailed`。模块加载或整次渲染抛异常则为 `moduleUnavailable`。因此本报告更符合单项公式失败路径，尚无法区分语法、输出、引用或限制问题。
- 原生 `RendererErrorRegistry.receive` 创建这类 incident 时未传入 `Error`；反馈 bridge 也不传公式错误细类。因此空 Error chain 是当前报告路径的信息缺口，不能据此认定没有发生错误。
- 同一文档内相同 kind/reason 会合并反馈 incident，不能从一份报告反推只有一个公式失败。
- v1.50.828 到 v1.51.834 的 `math-engine.ts`、`math-syntax.ts`、`math-identity.ts` 无差异。#72 的后续修复集中于样式/复制宿主，不足以证明 #73 与 #72 同根因，也不足以完全排除布局相关问题。

## 验证结果

- 命令：`cd web-renderer && npm test -- --runInBand --testPathPatterns='math|error-feedback'`
- 15 个测试套件、155 项测试全部通过（2026-11-17）。涵盖数学输入、引擎、兼容性、引用、复制、布局与反馈等路径。
- 现有测试确认错误命令、未解析引用和输出失败可进入数学失败路径，并保留后续有效公式。测试通过不代表已复现或解决报告者的 Quick Look 故障。
- 本次未运行报告者环境、未验证其实际公式；未修改产品代码、未发布、未向 GitHub 发消息或改 Issue 状态。

## 结论与下一步

目前只能确认新版报告中的数学渲染失败，根因未定。最有价值的下一份证据是能触发问题的最小 Markdown（保留公式定界符及相关 `\\label` / `\\ref` 定义），以及“单个公式失败还是全部公式失败”。截图可辅助确认可见错误，不必提供完整私人文档。

可独立改进反馈质量：在现有共享 bridge 的严格白名单内携带数学错误细类，保留隐私边界，不上传公式、路径或原始错误文本。这是后续改进建议，不是已实现的修复。
