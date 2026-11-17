# 反馈附件实际上传

2026-11-17：本地 ef064f6 仅生成 ZIP、打开 Finder 与 GitHub 文字预填页，没有网络上传。用户批准自建服务方案及部署（本次对话），实现前已定义后端验收指标及失败测试。前置 spec：`add-feedback-attachment-upload`。

目标：明确点击后上传 → 服务原子收件 → 客户端完整下载校验 → GitHub 正文保留下载链接；失败保持对话框及本地草稿。独立 `/feedback/` 服务，不改变遥测请求限制或存储语义。

测试证据：后端红灯 `/tmp/flux-feedback-red.log`；客户端红灯 `/tmp/flux-upload-red2.log`（缺少实现）；结果与上线回读待追加。只使用公开 fixture，不发布测试 Issue。

## 已验证结果
- 用户已批准自有附件服务和部署。backend 独立服务已部署，HTTPS `https://t.xykong.cc/feedback/` 可用；服务 binary SHA256 与本地 Linux 制品一致，独立服务、限额和维护定时器已回读。
- 后端 `cargo test --locked`：60 通过（4 附件/HTTP/备份恢复测试、56 现有测试）。客户端最终相关测试67项、64通过、3显式现场测试默认跳过；实际公网原生上传测试另行启用并通过。
- 原生反馈控制器真实上传1025字节公开 ZIP，客户端完整下载校验成功；独立 HTTPS 下载与解压后的原文完全一致。实际已登录 Chrome 的 GitHub Issue 正文和 Preview 均出现附件链接，点击该链接下载的 ZIP 摘要一致。没有创建 Issue 或评论。
- 服务端删除返回204，重复删除仍204，下载变为404。测试创建的浏览器 Issue 草稿标签已关闭。
- 服务端每日备份运行成功；隔离恢复副本 `integrity_check=ok`，含指定公开 fixture。副本已清理。备份是同机七天保留，不声明异地主机灾备。
- Intel `he-macpro`（x86_64，Xcode26.2）直接编译当前真实上传客户端代码，部署目标macOS11；实际公网上传、完整下载摘要、上传键查询、重复删除均通过（172字节公开 ZIP）。这不是macOS11运行时测试。
- 本地 Release 开发验收版已安装至 `/Applications/FluxMarkdown.app`，显示版本 `1.51.834-dev-20261117-222614`，严格嵌套签名校验通过。保留官方旧包和本地回滚制品。
- 实际安装版原生反馈窗口已通过 Orca 可访问性及像素截图检查：内容自动填写、文件默认勾选、明确自有服务目的地与公开范围。上传后删除操作独占一行，避免长语言文字挤压。原生 Continue 实际处理链路在 XCTest 使用真实服务验证，GitHub 实际页面单独检查；未声称通过 GUI 点击已安装版 Continue 完成整条链路。
- 引用资源仍仅包含用户主动选择的文件；打包指纹按确定的条目内容生成。重启恢复直接复用原 ZIP 和上传标识，保留用户主动清空的说明，避免重新压缩导致不同摘要或丢失已选择资源。

## 证据与边界
- `/tmp/flux-upload-final-tests3.log`、`/tmp/flux-upload-live-native.log`、`/tmp/flux-upload-final-app-build.log`、`/tmp/flux-upload-final-install.log`。
- 后端独立记录：`flux-markdown-backend/docs/feedback/ACCEPTANCE.md`；Linux最终制品摘要 `253adbda1cfbb0760f6a618c8ac711ac9b2d543426f862f3ab7f71825e2ef339`。
- 本地浏览器下载证据为公开测试材料；能力凭据只在私有临时结果和私有本地恢复存储，不进入本记录或 Issue。
- 未验证新发布 Issue 的正向长期关联（不为测试发布垃圾 Issue），存储层关联/暂存过期测试已通过，生产独立公开 Issue 核对维护任务已执行。
- 未发布正式版本、没有改 Sparkle/Homebrew、没有宣称 #73 数学根因已修复。
