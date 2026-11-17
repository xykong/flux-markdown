# 私密反馈附件

2026-11-17用户批准：默认只向维护者私密提交，公开下载链接必须额外勾选。当前a651e1a客户端和后端服务所有收件都有公开下载链接，当前流程不满足私密要求。

实施前验收指标：私密回执无URL；客户端不GET私密文件；带id/上传键/删除键的匿名GET及HEAD均不能返回内容；维护者SSH导出精确摘要且有审计；公开模式仍完整下载校验；旧公开记录保留、旧服务读取不到私密行；重复键共享范围冲突；恢复/清空说明/引用资源不回归。私密编号及Incident必须保留在6000字节Issue预算内。真实测试只使用公开fixture，不创建Issue。

状态：已部署独立验证，并安装本地开发验收版。

## 实际结果与证据
- 代码起点：客户端a651e1a。后端私密协议实现c4fc499，Linux制品在本机Docker Linux/amd64离线构建，未在生产机编译。远端安装摘要与本地一致：`02345a65eb74f819547162a93c09942ed110d152675e40d77ed00d31c039ba74`。
- 后端64项通过：8项附件存储/真实HTTP/私密/迁移/备份/导出测试，以及原有56项。临时或内存数据库，不向生产DB执行测试SQL写入。客户端71项、67通过、4个显式现场测试跳过；随后3个明确启用的真实上传/安装fixture测试均通过。
- 实际私密原生提交：receipt visibility=private，无URL；本地完整内容只在ZIP和私有恢复记录。实际Chrome GitHub表单正文包含`Attachment reference: FM-...`及Incident，不包含`/feedback/files/`链接，不包含文档正文或文件名。没有发布Issue或评论。
- 真实匿名GET、HEAD即使同时携带上传键和删除键仍404，不能取得ZIP。生产SQL只读确认私密行存在且旧`attachments`兼容视图不可见。
- 新维护者脚本通过已有SSH认证+服务账号导出，所得ZIP SHA256与客户端收件回执一致，解压原文完全一致，文件0600。服务审计确认operator=ubuntu，action=export；不记录文档内容或能力凭据。
- 正常维护定时任务Result=success、ExecMainStatus=0。私密备份在服务端隔离目录恢复，CLI导出的fixture摘要一致、SQLite integrity_check=ok；临时恢复副本删除。备份仍为同机七天轮换，不声明异地灾备。
- 主动公开的原生上传/完整下载校验回归通过。Intel he-macpro上的当前真实Swift客户端以macOS11部署目标编译，私密和公开两种模式实际上传、回执/状态查询、重复删除均通过；不是macOS11运行时测试。
- 新本地版本`1.51.834-dev-20261117-224419`安装至`/Applications/FluxMarkdown.app`，严格嵌套签名检查通过。实际App窗口可访问性和像素截图确认：附带当前文档=1、公开附件下载链接=0，中文说明和操作按钮未裁切。默认反馈说明仍自动填写。
- 测试上传已删除、测试Issue草稿标签关闭。现场验证仅使用无敏感信息fixture。原生Continue处理链通过XCTest真实服务验证，安装版可视窗口/默认选择与实际浏览器分别验证，未声称自动点击安装版Continue完成整条GUI链路。

日志：`/tmp/flux-private-backend-red.log`、`/tmp/flux-private-backend-tests.log`、`/tmp/flux-private-client-red.log`、`/tmp/flux-private-client-tests2.log`、`/tmp/flux-private-live-native.log`、`/tmp/flux-private-linux.log`、`/tmp/flux-private-deploy.log`、`/tmp/flux-private-app-build.log`、`/tmp/flux-private-install.log`。维护者用法位于私有backend的`docs/feedback/PRIVATE_ATTACHMENTS.md`及`scripts/download-feedback.sh`。

## 边界
- 新建公开Issue后的正向持久关联未实测（不为验收发测试Issue），隔离测试覆盖公开/私密关联后的保留差异，生产维护任务已执行。未关联7天；私密已关联最长30天，备份副本按七天轮换。
- 既有公开附件保持原授权；改变一个已上传附件的共享范围需要先删除再重新提交。之前别人已下载的公开副本无法追回。新私密数据对旧服务只读路径不可见，旧服务写入/清理会失败；升级后不可把旧公开版二进制作为功能完整的回滚方案，应使用兼容私密协议的修正并保留现有DB。
- 尚未发布正式App版本，未改变Sparkle/Homebrew或Issue73数学问题状态。
