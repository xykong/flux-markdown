# Change: 支持 TSV 文件快速预览

## Why
用户反馈无法在 Finder 中直接查看 TSV 表格，只能打开编辑器。当前项目既未注册 TSV 文件类型，也没有 Tab 分隔表格解析路径。目标是在 QuickLook 和主应用中提供只读、清晰、安全的表格查看体验。

## What Changes
- 注册系统 TSV 内容类型，打通 Finder QuickLook、主应用打开/拖入及相关打开入口。
- 增加独立 TSV 渲染分支，复用 WebView、主题、缩放和表格样式；不将 TSV 转成 Markdown。
- 首行默认是数据，以生成的列编号提供表头；保留空字段、空白、行列顺序和不等长记录。
- UTF-8（含 BOM）和 LF/CRLF/CR 换行；本版采用字面 TSV：Tab 和换行始终为分隔符，引号不作为转义语法。
- 提供水平滚动、原文查看、文本选择复制；长内容采用明确的有界预览提示。
- 复用 ErrorIncident / ErrorFeedback 实现读取或渲染失败时的恢复与上下文反馈。
- 本版不包含 CSV、编辑、公式执行、排序筛选或首行表头切换。

## Impact
- Affected specs: 新增 tsv-preview；与 add-file-format-support 共同维护文件类型声明，与 add-error-feedback 复用反馈机制。
- Affected code: Sources/Markdown/Info.plist、Sources/MarkdownPreview/Info.plist、主应用文件打开/内容加载、PreviewViewController、Shared/BoundedFileReader、渲染选项与 web-renderer/src/index.ts、新 TSV 模块和样式、对应 Swift/Jest/WebKit 测试。
- 技术设计与验收边界见 docs/design/TSV_PREVIEW.md。
- 当前状态：实现已完成，本地测试/构建、真实 WebKit 和主应用查看验证通过；本地签名安装后的 Finder 空格预览、主应用交接与搜索验收也已通过。
