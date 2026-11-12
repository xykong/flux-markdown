# GitHub → 飞书通知

## 验收标准

- Issue、PR 的新建、修改、关闭、重开，以及普通评论均触发通知。
- PR 审核和代码行评论也触发通知，包括外部 fork 的 PR。
- 内容包含仓库、事件、编号、标题、操作者、摘要和详情链接；合并区别于关闭。
- `FEISHU_MENTION_OPEN_ID` 配置后使用原生 text 的 at 标签；未配置时只发送普通通知。
- Webhook、签名密钥均使用 GitHub Secrets，不出现在源码或日志中。
- 失败必须使工作流失败；HTTP 429/5xx 做有限重试；检查飞书业务返回码。
- PR 内容仅作为数据，不执行 fork 的代码；不直接向 shell 插入标题、正文。

## 运行方式

通知使用 GitHub Actions，通过飞书自定义机器人的 Webhook 发往群聊。无需额外服务器，但存在 Actions 排队和启动延迟，不保证秒级送达。工作流部署到默认分支后才生效，不补发历史事件。

Issue / PR / 普通评论由 `feishu-notify.yml` 直接处理。审核及代码行评论先由无 Secret 的 `feishu-review-event.yml` 保存事件 JSON，再由默认分支上的通知工作流读取。artifact 仅当 JSON 数据处理，不执行其中代码。通知脚本始终从默认分支检出；外部 PR 不会取得机器人密钥。

仓库配置：

| 名称 | 类型 | 用途 |
|---|---|---|
| `FEISHU_WEBHOOK_URL` | Secret | 群机器人接收地址 |
| `FEISHU_WEBHOOK_SECRET` | Secret，可选 | 机器人启用签名校验时必须配置 |
| `FEISHU_MENTION_OPEN_ID` | Variable，可选 | 群内需要 @ 的成员 Open ID，通常以 `ou_` 开头 |

不要把实际 Webhook 写入本文档。Open ID 需对该机器人有效且属于群成员。Webhook 返回成功只能证明消息被接收，真实 @ 效果需要在飞书客户端确认。此配置不会 @ 所有人。

为了避免自动标签造成刷屏，默认只发送 Issue / PR 的主要状态与内容变更、普通评论、审核和代码行评论，不发送标签、分配人等管理操作。

## 验证与运维

本地运行 `node --test scripts/tests/feishu-notify.test.cjs`。线上在 Actions 中手动运行 **Feishu GitHub notifications**，群里应收到测试消息；随后观察真实 Issue / PR 事件对应的工作流。

失败时查看 Actions 日志（只记录 HTTP 状态、飞书错误码，不记录密钥）；确认机器人的签名校验、关键词要求与群成员身份。Webhook 关键词建议使用 `flux-markdown`，所有消息都包含仓库名。

HTTP 429/5xx 最多尝试三次，每次请求有超时。网络超时或不明确的响应不会自动重发，防止消息重复；手动重跑可能产生重复消息，飞书自定义机器人没有本实现可使用的幂等键。审核事件的 artifact 保留 1 天。

停用：禁用上述两个工作流。GitHub 若对 `pull_request_target` 设置阻止策略，需要明确允许仅处理通知的工作流，禁止检出或执行 PR head 代码。

## Parameter Foundry 上游托管申请

`feishu-upstream-watch.yml` 复用本仓库机器人和 @ 配置，每 5 分钟检查
`jenkins-infra/repository-permissions-updater#5412`。Actions 排队可能延迟通知。
只读取该公开申请，不修改上游；转发新评论、评论编辑和标题/状态/标签变化。
首次运行仅建立基线，不补发历史。手动运行可选择发送连接测试。
通知带原始链接，并保留 `flux-markdown` 路由标识以兼容现有机器人关键词。

游标通过 Actions cache 保存，串行运行防止并发重复。缓存被清理或超过保留期时，
下次重新建立基线，这段空窗中的事件无法保证补发。投递前写入 pending；
失败或响应不明确时保留 pending，后续运行停止发送，避免盲目重复。
恢复时先在群里核对 pending 链接：确认收到后手动清除 pending 并推进对应游标，
确认未收到才清除 pending 后重试；通过下载/修订游标并上传新 cache 进行处理。
工作流失败会在 Actions 显示，需订阅 GitHub Actions 失败通知。

本地验证：`node --test scripts/tests/feishu-upstream-watch.test.cjs scripts/tests/feishu-notify.test.cjs scripts/tests/workflow-security.test.cjs`。
