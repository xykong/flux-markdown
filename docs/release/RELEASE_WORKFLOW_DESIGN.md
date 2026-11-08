# 当前发布实现与恢复边界

此文件描述现有实现。规则见 [发布流程](RELEASE_PROCESS.md)，操作见
[发布操作手册](RELEASE_RUNBOOK.md)。旧版“先打标签、再提交版本”的设计已经废止，
不要按历史示例执行；本文件不提供另一套发布流程。

## 版本与产物

`scripts/release.sh` 在干净的 master 上读取 `.version`，普通发布默认 minor。
第三位取版本提交前的 git commit count；随后提交 `.version` 和 CHANGELOG、创建
指向该发布提交的标签并推送。标签内包含正确的 `.version`，此后所有渠道沿用它。
后续源码包校验和、appcast 和发布记录提交不改变这一冻结版本。

`RELEASE_REMOTE_BUILD=1` 从标签调用 `release-build.yml`，使用 Xcode 16.4 构建并
验证 macOS 11 与双架构。下载器验证 SHA、版本、归档哈希、签名和部署目标后，
本地生成 DMG。源码包与原始 notes 同时写入 release manifest。
`RELEASE_PREPARE_ONLY=1` 在完成准备后停下，不自动创建公开 Release。

## 发布顺序

`publish-release.sh` 验证 manifest 与权限，调用 Sparkle 签名生成，然后创建草稿
并公开 GitHub Release，再推送 appcast，最后调用 Homebrew updater。
已有 Release 的重试会比较附件字节，不覆盖发布包。整个过程不是跨服务原子事务：
后续阶段失败时，GitHub 可能已经公开。

署名与排版由 markdown-it 和 stdin 数据传递处理；不再把正文拼进 Perl。
Homebrew 非交互修改返回 2，需要操作员提交推送。updater 的“版本/哈希相同”早退
不能证明远端已经更新，必须独立 fetch/diff 两份 cask。

## 实际限制与恢复

- 准备失败用 `release.sh --resume`，沿用现有版本、标签及 notes；先检查其前置条件。
  正式附件已发布后不再通过准备重跑来重建它们。
- 发布重试会再次调用 `generate-appcast.sh`。若该版本已存在，它会询问是否替换；
  不可假设无人值守重跑完全无提示。为补 Homebrew 或署名文案，不要重生成已签 feed。
- 已完成的 GitHub/Sparkle 渠道只核对不重写；按操作手册补齐失败渠道。
- `publication-status.txt` 不验证署名语义、宣传图或浏览器显示，不能当作最终验收单。
- 历史正文纠错只修改 metadata；发布包、签名、版本与原始 manifest 不变。
- CDN 缓存、网络错误和 CI 依赖失败分别记录；替代下载路径或一次成功请求不能
  自动证明默认路径或页面渲染已经恢复。

本仓库没有 `release-dry-run.sh` 或 `verify-release.sh`；使用实际存在的
manifest、权限、测试和公开回读步骤。失败恢复不删除既有标签/Release，不强制
回退 master，也不重新分配已发布版本。
