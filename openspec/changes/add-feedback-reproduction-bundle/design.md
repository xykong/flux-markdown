## Context
当前报告使用 issues/new 的有界 URL，只携带诊断；Quick Look 通过受控交接进入主 App。完整文档不能塞进诊断字段或 URL。复现包是用户主动选择分享的内容，须与自动安全诊断分开。

## Decisions
- 首版使用 GitHub 原生 ZIP 附件，无新增文件托管服务。GitHub 网页上传会立即传输文件，不应提示为“提交 Issue 后才上传”。官方说明：https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/attaching-files
- 原入口保持快捷报告；可选材料入口提供“不附内容 / 失败片段 / 完整文档”。完整文档未经选择不读取入包，相关图片资源单独选择。
- 快照绑定 incident 和文档 generation；若原失败快照不可用，允许用户选择当前文件，但明确标记为报告时版本，不能冒充发生错误时内容。无保存路径的文档可导出当前内存快照。
- 数学细类使用 syntax/output/unresolved-reference/input-limit/unsupported-resource 等固定枚举，不传原始异常。片段使用独立可选通道，不放进通用 errorFeedback 的任意字符串字段。
- ZIP 使用中性内部名 document.md、sample.md、diagnostics.txt、manifest.json；文件名改写不代表内容已脱敏。必要时重写所选资源引用并保留相对布局，不改变用户原文档。
- 不扫描目录；仅选入明确引用且获准读取的本地资源。不抓取远程资源、不打包越界或符号链接目标；缺失项列在清单，用户可继续分享已有内容。
- 初始预算：最多 100 个文件、源码/资源合计 20 MB、ZIP 小于 25 MB；超限展示具体项，允许取消资源或仅分享片段，不静默截断原文。预算须在读取、压缩和导出时执行。
- 压缩完成后展示可检查/移除的材料与拖动附件；GitHub 页面附上 ZIP 后用户提交。未获得服务回执，App 仅显示“已准备/已打开 GitHub”，不自行宣称附件已上传。
- Quick Look 受限环境采用受控快照临时引用及宿主回读校验，遵守现有权限；不接受 renderer 提供的任意本地路径。大文件不通过现有 16 KiB incident payload 传递。
- 取消、失败与重试保留当前报告；临时包受限本地保存、可主动删除，过期清理不得删除用户主动导出的包或仍在使用的草稿。具体保留期限在实现前固定并测试。

## Risks / Trade-offs
- 网页附件需要用户完成一次拖放/选择；首版不承诺自动上传。
- 全文、图片、文件内容及元数据都可能泄露信息；提示明确分享范围并允许检查，不能声称自动脱敏或替用户判定敏感性。
- 失败依赖整篇上下文时，片段可能不足；完整文档选项和缺失资源清单必须可见。
