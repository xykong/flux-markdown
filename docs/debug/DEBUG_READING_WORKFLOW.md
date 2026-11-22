# 阅读工作流完善与验收

日期：2026-11-18。基线：`89c9962`，安装基线 `1.51.834-dev-zoom3`。用户确认原缩放体验后，授权落实五项建议并做端到端验证。范围与预先验收条件见 `openspec/changes/complete-reading-workflow/`，不包含 Issue #73 数学渲染问题或正式发布。

## 实现

1. 文档/图表倍率提示位于文档外，短暂显示；六种界面的帮助说明缩放范围和双指双击含义。
2. 图表专注层移动原 DOM，提供适应窗口、100%、滚动平移、复制/保存、关闭；关闭原位归还图表、恢复局部倍率、焦点和阅读锚点。App 支持 Esc；Quick Look 使用关闭按钮。
3. 目录/脚注跳转和原生本地文档链接进入共享后退/前进历史；工具条及“显示”菜单可操作，快捷键 Cmd+[ / Cmd+]。普通滚动不制造历史条目。
4. 按文件本地保存文档倍率和语义位置：元素 ID、文本哈希、块序号、屏幕偏移及 scrollY 后备。最多100个文件，历史最多100项，不保存正文。刷新前方插入段落仍恢复原段落；显式行号/锚点跳转优先。
5. 图表独立复制 PNG，保存 PNG/SVG。序列化真实图表并内联样式，去除工具栏，原生 WebKit 光栅化。剪贴板/原子文件写入后独立读回才报成功；取消独立反馈。Quick Look 保存转到 App，复制可直接执行。

## 方法与材料

- 先建 OpenSpec 验收条件，再补 renderer 与 native 测试；组合测试覆盖真实长文档、Mermaid、前方插入段落、原 DOM 身份、焦点层开关、文档/图表倍率隔离和整文导出。
- 使用生产 `DiagramExportRequest` / `DiagramExportService` 处理真实 WKScriptMessage，独立读取 PNG/SVG 文件及唯一剪贴板，解码尺寸和红色样本像素，人工查看真实 Mermaid 导出图片。
- 通过实际 NSDocumentController 子类类型映射打开两个临时文件，调用生产历史和恢复桥，再由真实 WKWebView 回读目标位置与文档倍率。类型映射遵循 Apple NSDocumentController 的公开扩展点；不依赖不存在的动态注册 API。
- 测试材料：`Tests/fixtures/reading-workflow/origin.md`、`linked.md`。自动测试使用临时文件及隔离 UserDefaults/剪贴板；不会改写用户文档。
- 桥校验主 frame、renderer origin、当前 generation、请求类型与预算；SVG 拒绝脚本、事件、DTD/实体和自动外部资源，PNG 关闭 JS 并限制尺寸/超时。错误复用 ErrorIncident/ErrorFeedback，提供重新加载、重试或更换保存位置。

## 独立验证证据

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| 全量 renderer Jest | 634项、70套通过 | `/tmp/flux-workflow-jest-final.log` |
| 原生历史/持久化/真实文档打开/WebKit/导出、已有手势/菜单/错误模型 | 38项通过（包括外部资源属性及 CDATA 的安全回归） | `/tmp/flux-workflow-native-final.log` |
| Apple Silicon 真实 WebKit | 阅读工作流3项 + 原缩放/布局6项通过 | `/tmp/flux-workflow-arm-final.log` |
| Intel 真机 x86_64 WebKit | 同9项通过 | `/tmp/flux-workflow-intel-final.log`，远端 `/tmp/flux-reading-zoom.Dxjina` |
| TSV 20,000单元格与恢复后备回归 | 通过 | `/tmp/flux-workflow-tsv.log` |
| 导出制品 | PNG解码、文件字节和剪贴板读回通过；Mermaid PNG视觉检查通过 | `/tmp/flux-workflow-evidence/diagram-{1.png,2.png,3.svg}`；Intel `/tmp/flux-workflow-intel-artifacts` |
| 六种 native 字符串 | 12份文件 plutil通过 | App与Quick Look所有语言 |
| 原菜单 | 安装App回读“打开…”/“打开最近使用”各1项，新增后退/前进有中文 | `/tmp/flux-workflow-installed-menu.txt` |
| 安装 | `1.51.834-dev-reading3`，host/extension 173份 renderer 资源逐项SHA256匹配 | `/tmp/flux-workflow-install.log` |

实际安装验收发现 native history availability 被直接赋给 disabled，导致按钮状态颠倒；新增先失败的回归用例后改为取反。合成 WebKit 测试不替代物理触控板主观验收。

## 安装验收结果与边界

已重新安装含导航按钮修正的最终本地版，深度签名校验通过。后台 AX 回读初始后退/前进均禁用，目录跳转后“后退”可用、“前进”禁用；点击真实本地链接后新增 `linked.md` 原生窗口，验证了安装版链接到文档控制器的链路。日志：`/tmp/flux-workflow-installed-{toc,link}.json`。已备份先前用户验收版本到 `~/Library/Application Support/FluxMarkdown/Install Backups/20261118-022811/FluxMarkdown.app`，保留原编辑器关联。

用户随后明确授权前台操作。已实际完成：

- 打开专注层，Cmd+= 调整局部125%，Cmd+0恢复局部100%，Esc关闭后原段落/倍率及偏移恢复。
- 点击复制 PNG，系统剪贴板实际读回4096×668图像；通过 NSSavePanel 保存 PNG/SVG，PNG与剪贴板 SHA256完全一致，SVG XML可解析且没有工具栏；视觉检查中文、连线和完整图形。
- 再次打开保存并取消，显示“已取消”，没有创建目标文件。
- 点击本地链接打开 linked.md；真实“后退”按钮切回 origin.md，真实“前进”按钮再次切到 linked.md。
- 真正退出/重启App、重新打开文件，恢复同一图表章节与110%文档倍率，屏幕偏移误差0.15625px。专注层关闭前后进度均为71%。
- 31节点超宽图进入专注层自动适应至16%，整图可见；100%显示清晰节点；实际横向滚动后从步骤0移动到步骤4—9；再次点击适应窗口回到16%，Esc关闭。

前台验收另发现并修正两项问题：恢复位置未发生实际滚动时，阅读进度需要显式刷新；启动连续两次渲染时，第二次不得捕获尚未完成的临时页面顶部覆盖持久锚点。后者先由原生临时诊断确认“两次读取均为正确保存位置，最终保存却是顶部”，再新增真实WebKit并发首次渲染用例复现失败，修正后两种架构均通过。临时诊断代码已移除，最终安装包仅含正式实现。

持久证据：[`evidence/reading-workflow/acceptance.json`](evidence/reading-workflow/acceptance.json)、[适应窗口](evidence/reading-workflow/focus-fit.png)、[100%](evidence/reading-workflow/focus-100.png)、[横向平移](evidence/reading-workflow/focus-pan.png)、[实际导出PNG](evidence/reading-workflow/export.png)、[实际导出SVG](evidence/reading-workflow/export.svg)。GUI操作日志位于 `/tmp/flux-workflow-*.json`。导出操作在reading1完成，随后reading3只修正恢复和进度逻辑，原生导出实现不变。
未执行正式发布、签名公证发布门禁或 macOS 11 运行测试；现有最低目标保持不变。本机新 Xcode 的 Debug 构建使用诊断覆盖 `MACOSX_DEPLOYMENT_TARGET=12.0`。Quick Look 文件保存交接的真实 Finder UI 尚待人工验收。

## 重跑

```sh
npm --prefix web-renderer test -- --runInBand
npm --prefix web-renderer run build
FLUX_WEBKIT_CASE_FILTER='Reading ' bash scripts/test-renderer-webkit.sh
FLUX_WEBKIT_CASE_FILTER='TSV safe' bash scripts/test-renderer-webkit.sh
xcodebuild -project FluxMarkdown.xcodeproj -scheme Markdown -configuration Debug \
  -destination 'platform=macOS,arch=arm64' MACOSX_DEPLOYMENT_TARGET=12.0 \
  ONLY_ACTIVE_ARCH=YES -jobs 2 test \
  -only-testing:MarkdownTests/ReadingWorkflowTests \
  -only-testing:MarkdownTests/NativeMagnificationTests \
  -only-testing:MarkdownTests/DocumentMenuPolicyTests \
  -only-testing:MarkdownTests/ErrorIncidentTests
```
