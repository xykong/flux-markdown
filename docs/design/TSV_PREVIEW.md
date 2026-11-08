# TSV 快速预览设计

## 用户目标与现状
在 Finder 按空格或用 FluxMarkdown 打开 .tsv，以只读表格查看内容。现有注册仅包含 Markdown 变体，renderMarkdown 使用 Markdown 解析器。PreviewFileReader 已按 500 KiB 截断并保护 UTF-8 字符边界；主应用另有 32 MiB 文件预算。新增能力须避免回归已有 Markdown 流程。

## 数据与展示约定
- 根据大小写不敏感的 .tsv 扩展名明确选择格式，由原生端向 renderer 传递格式和截断状态；不猜测 Markdown 内的 Tab 内容。
- 使用独立 TSV 模块，输出安全 DOM/转义后的 HTML；不经过 Markdown、数学、图表、图片收集和远程资源加载流程。列中的 HTML、公式、链接和 Markdown 均为文字。
- UTF-8（含开头 BOM）；支持 LF、CRLF、CR。其他编码走现有可操作错误反馈，不静默乱码。
- Tab 分列、换行分记录；引号和反斜线原样保留。本版不宣称兼容带引号的多行字段方言。
- 不 trim 单元格；连续 Tab、末尾 Tab 保留空字段。中间空行保留为空记录，文件末尾一个换行只作为记录结束符。空文件展示本地化空状态。
- 首行与其他行等价；生成列编号表头，短行补空单元格，保留原始字段数据。最大列宽配合换行/滚动避免超长字段撑破界面。
- 使用语义化 table / th / td，滚动区域可键盘访问；跟随主题和字体设置，允许选择复制文字。首版不额外承诺选区复制为完整 TSV。

## 资源预算
- QuickLook、主应用重新加载和 CLI 导出读取最多 500 KiB + 1 字节探测截断。主应用首次打开使用 SwiftUI FileDocument：系统先提供完整 FileWrapper，应用只解码前 500 KiB，并保留原始 Data 以防系统保存时覆盖成截断数据；首次打开的系统级分配不受此预算约束，这是当前架构的明确限制。格式相关处理不改变 Markdown 预算。
- 最多展示 1,000 行、100 列、20,000 个单元格（包含补齐格）。按最终展示宽度限制行数，解析过程也必须有界，不能先 split 整个无限输入再截断。
- 字节截断时仅显示完整记录；无完整记录时显示“首条记录超过预览限制”等明确说明。EOF 时允许最后一行没有换行。截断落在 CRLF 中间须正确识别记录边界。
- 不把截断后的部分字段伪装成完整数据。明确提示已显示的范围及限制原因，不声称已知全文件行数。
- 源码视图和导出同样标明数据仅为预览范围；导出 HTML/PDF 如沿用当前入口，必须保留截断提示；不能悄悄导出残缺“完整文件”。
- 截断不是解析失败，使用非模态说明。失败使用共享 ErrorIncident / ErrorFeedback，诊断不包含单元格内容或私有路径。

## 集成路线
1. 补 Swift 文件识别/读取和 Jest 解析/安全/预算失败测试，记录红灯结果。
2. 实现共享格式识别、系统 TSV 类型注册和各原生打开入口（含 QuickLook 到主应用交接）的一致支持。不改变默认编辑器归属。
3. 实现有界 TSV 读取/解析/渲染及本地化提示，保留当前 renderMarkdown 桥接入口但在内部显式分流。
4. 检查源码切换、主题切换、搜索、缩放、重新加载、导出、TOC 与进程复用；TSV 不产生伪目录，切回 Markdown 清理 TSV 状态。
5. 更新用户文档及 docs/debug/DEBUG_ERROR_FEEDBACK.md 的覆盖清单。

## 验收
- Fixture 覆盖普通表、无表头、空文件、仅 BOM、Unicode、各种换行、空字段/空行、不齐列、HTML/script/Markdown/公式、字面引号、超长单字段和各预算边界。
- Swift 测试覆盖类型注册、入口、UTF-8/截断与源文件不变；Jest 覆盖解析结果和安全 DOM，渲染集成覆盖 TSV 与 Markdown 往返及主题/源码切换。
- npm test、npm run build；相关 XCTest、应用构建；使用真实 WebKit 及 Finder/主应用检查布局、水平滚动、键盘、错误反馈与截断提示。
- 20,000 格 fixture 在测试机暖渲染目标 1 秒内完成，记录机器、耗时和实际节点数；超限输入不增加预算外节点。测试目标未达到则降低预算或优化后复测。
- 手动界面验证不可用时明确记录缺口，不以单元测试冒充系统 QuickLook 验证。

## 审核与实施状态
方案已于 2026-10-28 获用户批准。默认首行作为数据和字面 TSV 是本版明确边界；后续根据实际样本评估表头切换、其他编码及带引号字段支持。

## 2026-10-28 实现验证

- 标准 UTI 使用本机 SDK 确认的 `public.tab-separated-values-text`，应用声明为 Viewer / Alternate，不导出私有 TSV UTI，不抢占默认编辑器。
- Jest：45 suites / 402 tests 全通过；TypeScript 与生产 Vite 构建通过。
- 真实 WKWebView：23 cases 全通过，包含 TSV 安全表格、截断导出、源码切换、返回 Markdown；Apple M5 Max / arm64，20,000 单元格本次渲染 263 ms（单次测量，非跨设备保证）。
- XCTest：文件类型、预览读取、打开交接共 53 tests 全通过；验证标准 UTI / Alternate、UTF-8 边界、`.TSV` 大写交接。
- Debug 应用与原生测试包构建通过。本机 Xcode 27 不支持部署到 macOS 11，诊断构建仅通过命令行覆盖为 macOS 12，产品 project.yml 部署目标未改。直接 xcodebuild 没传版本脚本参数，存在空 bundle version 的诊断构建警告；该产物不用于发布。
- 主应用实际打开 Tests/fixtures/test.tsv，屏幕与可访问性树均显示 Column 1/2、alpha/beta、one/two；源码按钮切换后保留原始 Tab 文本。
- 首批四个 Jest 用例在最初实现后补入；后续“列截断未提示”和“截断首行误报空文件”的两项回归用例先失败、修复后通过。此记录不把最初实现声称为完整 TDD。
- 全量原生运行进入已有 RenderBenchmarkTests 后出现系统服务噪声且未完成，已停止；本次相关原生测试改为明确选择上述三组运行。真实 WebKit 验证独立完成。
- Finder 签名安装验收已在后续补做通过，详见下节。

## 签名安装与 Finder 实机验收（2026-10-28 补充）

此前将系统级验收自行留到发布阶段是不完整的收尾；用户已授权完成全部内容，本机并无阻塞。现已完成：

- 使用 `make app CONFIGURATION=Release LOCAL_DEPLOYMENT_TARGET=12.0` 生成本地候选包，版本仍由仓库 `.version` / Makefile 提供；仅设置 FMDisplayVersion 为 `1.40.622-tsv-acceptance-3404bbf` 以识别本次候选，不修改发布版本号。
- 使用项目 Release entitlement 配置对 XPC、QuickLook 扩展及主应用逐层 ad-hoc 签名。`verify-release-entitlements.sh` 与严格深度签名验证通过。此为本机签名验收，不代表 Developer ID 公证或 macOS 11 发布兼容性验收。
- 原应用备份至 ignored `build/tsv-acceptance/original.app`；通过保留编辑器设置的 vendor installer 安装候选到 `/Applications/FluxMarkdown.app`。安装前后 Markdown 默认编辑器状态逐字节一致。
- 在真实 Finder 窗口定位 `Tests/fixtures/test.tsv`，按 Space。QuickLook 可访问性树显示 TSV 表格、Column 1/2、alpha/beta、one/two；截图可见候选标识 `v1.40.622-tsv-acceptance-3404bbf`，证明确实调用本次扩展，而非仅注册成功。
- QuickLook 系统“打开”按钮仍显示原 TSV 编辑器 Orca。点击扩展内 `Search in FluxMarkdown` 后，主应用打开相同 `test.tsv`，显示相同候选标识与表格，并展开搜索栏；输入 alpha 得到 `1/1`，验证扩展 → XPC → 主应用交接及搜索。
- 测试后关闭测试文档和 QuickLook 面板，通过 vendor installer 恢复原应用。恢复后严格深度签名验证通过，主程序与备份逐字节一致，Markdown 编辑器状态仍与测试前一致。TSV fixture 未修改。
- 安装/恢复日志和状态文件保存在 ignored `build/tsv-acceptance/`；屏幕与可访问性观察记录在本次会话工具结果中。未发布版本或发送外部反馈。
