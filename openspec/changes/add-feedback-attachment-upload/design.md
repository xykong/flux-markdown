## Current evidence
- `Sources/Shared/ErrorFeedback.swift` 的继续操作只调用本地 `prepareDocumentAttachment`、打开 Finder 和 `ErrorFeedback.report`，无上传 HTTP 请求。
- `flux-markdown-backend/src/main.rs` 当前没有附件路由；现有 HTTPS 遥测入口限制 64 KiB 请求且声称不采集文档，不可偷偷改变语义。
- 官方文档核对：普通 Issue 创建接口 body 是 Markdown 字符串；浏览器附件在拖放/选择后上传。CLI --attach 只支持图片/视频且要求 push 权限。Issue artifacts 接口是已存在 Issue 的文本/链接工件，不是未创建 Issue 的匿名 ZIP 上传。
- 来源：https://docs.github.com/en/rest/issues/issues 、https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/attaching-files 、https://docs.github.com/en/github-cli/github-cli/attaching-files-with-github-cli 、https://docs.github.com/en/rest/issues/artifacts

## Decisions

### Storage and destination
使用既有自有基础设施，独立 `flux-feedback` 服务、服务用户和数据目录；不共用遥测 DB，不扩大已有 64 KiB 遥测路由限制。实现代码放 private backend repo；公开客户端只保留固定 HTTPS 服务地址和公开协议，不含服务器凭据。

实际域名、磁盘可用容量、反向代理配置及备份方式在只读部署预检后写入部署记录；本方案阶段不更改生产服务器。附件链接是自有服务的固定主机、不可猜测对象 ID、固定中性 ZIP 下载名，没有公开列表目录。

### Upload protocol
- POST 上传原始 ZIP（最多 25 MiB；保持客户端 20 MiB 入包预算），传 incident ID、内容 SHA-256、稳定幂等键。
- 服务计算实际内容摘要，不信任客户端声明。原子持久化内容及元数据后才确认；同一键/同一内容返回同一对象，不一致返回 409。
- 服务返回固定格式对象 URL、大小、SHA-256 与独立删除凭据；删除凭据仅在本地私有保存，不放入 Issue、日志或公开链接。
- GET/HEAD 下载仅返回 attachment/zip，禁止 HTML 内联执行、缓存混淆和任意文件路径；禁止把用户文件名当存储路径。不解压上传包，拒绝不符 ZIP 类型的请求。
- 客户端验证 receipt 主机/路径/大小/摘要，并检查公共下载可用后再生成 GitHub URL。最终验收必须完整下载并验证字节摘要和原文档内容，不能只测 HEAD 或脚本退出码。
- 响应超时先查询稳定上传键状态，确认未存储再重试，避免产生副本；选择或编辑变化后重新绑定摘要，不误用旧附件。

### User flow
默认勾选文件仍保留。首屏清楚说明“文件会先上传到 FluxMarkdown 附件服务，附件链接随 Issue 公开”。主按钮随选择显示“上传附件并继续 GitHub”或“不带附件继续 GitHub”。打开本地对话框仅准备本地内容，不自动网络上传。

服务确认后自动添加 `[下载复现文档 ZIP](https://固定附件主机/固定格式对象地址)`；URL 6000 字节预算优先保留 incident 和附件链接，先删旧历史再删可选信息，不能静默丢掉附件。

上传失败保持当前窗口、说明具体失败阶段、允许重试或取消勾选；不退化成打开 Finder 让用户补传，也不声称已发送 Issue。App 重启可恢复未完成上传状态和草稿；取消不丢说明文本。

### Capacity, abuse and lifecycle
- 独立反向代理路径/主机限流、连接数和传输超时；以可信代理的来源 IP 限制，不能允许请求头伪造身份。
- 全局容量硬上限和剩余空间保护；容量不足明确拒绝新上传，不静默删除已关联 Issue 的附件。
- 未关联已发布 Issue 的上传暂存 7 天；客户端验证真实 Issue 后通知服务，服务自行回读公开 Issue 中的 incident 和对象链接，再建立关联。已关联附件不按暂存 TTL 删除。
- 删除入口使用独立能力凭据；用户取消或误传后可主动撤销。保留策略在 UI 详情和隐私说明中公开。
- 新目录加入备份与恢复验证；不能把现有遥测备份状态当作文档存储保障。
- 默认匿名上传需要服务限额和滥用保护，不能通过在客户端塞共享管理 Token 来假装认证。

## Rollout and acceptance
先完成两仓本地/隔离服务测试，构建 Linux 制品；明确批准后部署独立附件服务和固定 HTTPS 入口。用公开 fixture 实际上传、独立下载与解压回读，再在实际 GitHub 预填页确认 Markdown 链接存在且可打开下载。真实 Issue 发布/评论仅在获明确授权时执行；不为了验证而给 #73 写测试垃圾。

上传服务未部署或不可用时，不得宣称“自动附件上传已完成”。保留原安装包以便回滚，更新本地验收版不等于正式发布。
