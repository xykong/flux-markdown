---
name: publish
description: FluxMarkdown 发布入口。按项目发布流程准备、验证和发布版本，或维护已发布说明与分发渠道。
model: animal-gateway/glm-5.1
---

# Publish 发布入口

执行前必须读取：

1. 根 [AGENTS.md](../../AGENTS.md)。
2. [发布流程与验收要求](../../docs/release/RELEASE_PROCESS.md)——唯一规则来源。
3. [发布操作手册](../../docs/release/RELEASE_RUNBOOK.md)——实际命令及中断恢复。
4. [发布记录模板](../../docs/release/RELEASE_RECORD_TEMPLATE.md)——按证据填写状态。

本入口不维护第二套发布脚本或相互冲突的示例。用户已授权发布或“测试通过后发布”时，
先完成检查，再按授权执行，不机械地重复请求确认；有实际缺项时具体说明。

## 参数与任务范围

- `/publish` 或普通发布请求：默认 **minor**。
- `patch` / `major`：仅用户明确指定时使用。
- 指定完整版本：先识别为检查、纠错或恢复已有版本的目标；不直接改 `.version`。
  新发布的完整版本及 commit-count build 由 `scripts/release.sh` 生成。
- 补署名、修正说明、补图：走操作手册的元数据纠错流程，不重新发版。

## 执行要求

- 自有开发直接验证、合并 master、提交和推送；除非用户明确要求，不创建 PR。
- 核实 issue 发起人和实现者，把个人主页与 issue/PR 链接直接写在对应功能/修复
  条目中。GitHub Release、CHANGELOG 和 Sparkle 同步；不建立独立
  Acknowledgments/Acknowledgements/致谢章节或统一感谢名单。
- 使用 prepare-only 流程，默认命令为
  `RELEASE_REMOTE_BUILD=1 RELEASE_PREPARE_ONLY=1 make release minor`。
  正式包必须保留 macOS 11 与双架构；验证最终标签 SHA、测试、签名和 manifest。
- 仅在产物检查通过后运行 `scripts/publish-release.sh`。缺少 Sparkle 签名工具/
  密钥或 Homebrew 验证不能静默跳过。非交互 cask 退出 2 时按手册单独完成提交推送。
- 每版宣传图必须生成、压缩、视觉检查、上传到 Release 顶部，公开下载校验并确认
  浏览器实际显示。图片引用正确或附件可下载，不等于页面视觉验收通过。
- 发布后修正文案需先快照和核对并发修改；只修改目标说明，保持签名、版本、日期、
  下载地址、附件字节、既有正文/宣传图和其他署名不变。不要改写 manifest-bound notes。
- 多行正文用文件或结构化 JSON；内容作为数据处理，不插入 Perl/Shell 代码。
- 已有版本的恢复沿用标签与产物；不删除标签/Release、不硬回退、不靠重签重建绕过失败。
- 每项完成均需实际回读。默认 feed 的 CDN 缓存、下载 504、CI 未执行测试和图片破图
  分别记录为未完成项；后续恢复时更新记录，保留历史事实。
- 修复确认且发布验收完成后，按 issue 原语言回复版本和更新方法，添加 `done` 并保留
  issue 打开。未确认的修复不能借发布动作标记已解决。

## 输出与收尾

按发布记录模板提交本版 prompt、结果和限制，直接推送。报告实际完成的阶段、验证证据、
版本链接和剩余项。不得使用预填成功的模板，不得把“版本已公开”写成“所有验证已完成”。
只有全部适用验收项通过，才能报告发布全部完成。
