# 反馈复现材料与 Issue 回复提醒

## 背景与范围

- 触发报告：[#73](https://github.com/xykong/flux-markdown/issues/73)，报告者 [@syutheoria](https://github.com/syutheoria)。数学根因仍未确认；本变更完善反馈链路，不声明修复报告者公式。
- OpenSpec：`add-feedback-reproduction-bundle`，用户于本会话明确批准实现，并要求继续。
- 现有诊断快捷反馈保持一键打开 GitHub；附带文档为独立可选路径，公开分享内容需由用户检查并选择。

## 实现

- 数学诊断细分语法、输出、引用和容量限制；不同失败公式使用独立 incident，避免错误绑定复现片段。
- 失败节点只传固定错误分类和有界源码行号；带源码位置的图表也可提取片段。原生从该次渲染输入提取片段；公式定界符保留，可识别的相关 label 定义在 6000 字节内附入。复杂跨公式依赖仍可选全文。
- 复现窗口允许编辑片段、选择全文及单独选择引用资源。ZIP 包含源码、可排除的安全诊断和清单；不扫描目录、不抓远程资源、不跟随符号链接、不修改原文件。
- 最多 100 个包内条目、20 MiB 总输入、ZIP 小于 25 MiB；使用系统 ditto 创建 ZIP 并用 unzip 校验。临时工作目录 0700，操作结束即删除；用户明确保存的 ZIP 不自动删除。异常终止可能留下临时目录，尚无崩溃后清理扫描。
- 主 App 使用渲染输入快照；Quick Look 仅在展示片段且用户点击继续后通过既有受控交接传递该有界片段。全文在宿主中由用户重新选择，标注为报告时版本。不扩大沙箱权限，不传任意本地路径，不用诊断 URL 传全文。
- App 保存 ZIP，用户在 GitHub 页面拖放附件并最终提交。界面区分“本地已准备”和“已上传”，解释 GitHub 选择附件后即上传。没有自建上传服务。
- 自动反馈和普通反馈均带稳定 Incident 标识；诊断排除不删除此关联标识。启动/前台/周期轮询公开 GitHub API，核对真实 Issue 和完整标识，歧义保持待关联，支持核实后手动关联。
- 回复列表分页、有界扫描、ETag 和限流退避；不以搜索索引或打开表单推断提交成功。
- “我的反馈”、帮助菜单未读数量、Dock 数量及可选系统通知；Quick Look 错误入口可打开宿主“我的反馈”。维护者/其他用户回复提醒，报告者本人回复不提醒。
- 未读和同步独立。打开列表、重启、Issue 关闭、关闭系统横幅、复制链接、同步成功均不确认回复。点击某条提醒且浏览器接受具体 `#issuecomment-ID` 后只确认该条；打开失败保留；后续新回复继续未读。
- 同一 Issue 的系统提醒合并，新回复更新提醒；跳转首条未读。应用退出时没有实时推送，运行后补查。客户端不内置维护者 Token。
- App 与 Quick Look 均补齐 en/zh-Hans/de/fr/es/ar 文案；按钮使用原生可访问控件，源码输入提供辅助功能名称。

## 验证（2026-11-17）

- `scripts/test-feedback-follow-up.sh`：arm64 与 Intel he-macpro/x86_64 通过。覆盖稳定 ID、歧义/前缀误匹配、未读持久化、打开失败、逐条确认、系统 unzip、资源范围、符号链接、容量限制、原文件保真。
- 渲染器全量 Jest：67 suites、621 tests 通过。新增分类、无源码诊断、行范围及多公式 incident 测试。
- TypeScript + Vite 生产构建通过。
- Xcode Debug App/Quick Look 扩展编译通过；本机 Xcode 27 使用命令行 `MACOSX_DEPLOYMENT_TARGET=26.0`，未改项目最低 macOS 11 配置。
- 原生 XCTest：ErrorIncidentTests、FeedbackDiagnosticsTests、FeedbackFollowUpTests；50 项全部通过（含明确启用的只读 live 回读），最终结果见本地 `build/issue-feedback/Logs/Test/` 与 `/tmp/flux-feedback-tests.log`。
- 注入 HTTP 的实际控制器测试：真实关联解析、延迟发现、分页、304、429/Retry-After、503 离线、逐条打开与回读持久状态。
- 明确启用只读 live 测试后，用实际 GitHub API 核实 #73 存在、报告者为 syutheoria，并回读临时跟踪文件；未写 GitHub。
- 真实 WKWebView：`FLUX_WEBKIT_CASE_FILTER='contextual feedback bridge' scripts/test-renderer-webkit.sh` 通过 1 case，验证现有安全反馈、旧代次失效和导出排除。
- 原生窗口布局断言通过；窗口像素捕获被系统拒绝，view cache 不完整，不作为视觉验收证据。全量 WebKit 探针包含须前台焦点的用例，按现有窗口策略未执行那些用例，没有绕过策略。

## 尚未验证与后续验收

- 尚未安装新版签名运行包做真实 Finder Quick Look → 主 App 全链路；当前是编译、原生/renderer 测试和只读网络验证。
- 尚未实际上传 GitHub ZIP、最终发布 Issue、接收真实外部回复和系统通知点击；需要专用无敏感测试材料，不能以 fixture 冒充线上证据。
- 真实系统通知授权允许/拒绝、所有语言的实际视觉/键盘走查，以及真实删除评论后的页面行为待验收；已删除评论仍保留原提醒，用户可点击尝试打开，不声称检测到删除。
- Intel 验证覆盖共享打包/未读状态逻辑，未覆盖本次新增窗口/通知全功能。
- 复现资源识别采用保守形式，复杂 Markdown/HTML 引用可能未自动识别，清单保留未选入的可识别引用；用户可提供简化样例。全文选择不等于所有依赖均入包。
- 尚未发布；不为 #73 加 done，不关闭 Issue，也未对外宣称数学问题已修复。
