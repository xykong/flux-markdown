# v1.41.635 发布记录

日期：2026-10-28。用户授权发布；默认 minor 从 1.40 升至 1.41，构建号 635 由发布脚本按提交数生成。

- 发布标签：`v1.41.635`，提交 `7cd1ce78c8cf1bfbc50b70cf8d290fbabccdf12c`。
- GitHub Release：https://github.com/xykong/flux-markdown/releases/tag/v1.41.635
- 正式构建：https://github.com/xykong/flux-markdown/actions/runs/40672642550
- 固定 Xcode 16.4 / macos-15：402 项 renderer 测试、23 项真实 WebKit 场景、373 项原生测试（1 项预期跳过、0 失败）通过。CI 中 20,000 个 TSV 单元格渲染为 794 ms。
- 主应用、QuickLook 和 XPC 的 arm64/x86_64 架构、双架构 macOS 11.0 minimum、版本与提交 provenance、嵌套签名和 Release entitlement 校验通过。
- 正式 DMG SHA256：`e6d670c31a70d8824e87286b2fab1daab33dce9138adf52c8d751a7d1b24a87a`。DMG 与 MacPorts source tarball 均已发布；重跑 publication 从 GitHub 下载并逐字节比较两项资产成功。
- Sparkle feed 已提交推送，远端 appcast 首项确认 `1.41.635` 并指向本次 DMG；EdDSA 签名生成成功。未将 feed 验证称为执行了 Sparkle GUI 自动更新。
- Homebrew tap 和官方候选草稿均更新至相同版本/SHA，tap 提交 `604ae5e` 已推送且与 origin/master 一致。官方候选是 tap 内草稿，不表示已合并 homebrew/homebrew-cask。
- 实际 `brew upgrade --cask xykong/tap/flux-markdown` 从 1.40.622 升级至 1.41.635 成功。升级后 `/Applications/FluxMarkdown.app` 严格深度签名通过，Markdown 默认编辑器状态与升级前逐字节一致。
- 正式包 Finder 实测：选中 `Tests/fixtures/test.tsv` 按空格，窗口显示 `v1.41.635`、两列表头和两行数据。首次仍显示系统文本预览，关闭后执行 `qlmanage -r` / `qlmanage -r cache`，再按空格正确显示本版本表格。保留原 TSV 默认编辑器（Orca）。
- DMG 安装预检先误将只读挂载目录作为 vendor installer 输入，因清理 xattr 失败而停止且未替换应用；改为与 Homebrew 一致的可写 staging 副本后安装成功。用户手动 DMG 使用拖放安装，不直接运行这个预检调用。
- Homebrew updater 在非交互模式准备修改后返回 2，已按提示完成 tap 提交推送。发布重试时对已有 appcast 选择保留（输入 n），资产一致性验证和渠道更新最终成功。`build/artifacts/publication-status.txt` 记录完成状态。
- 本机保留正式发布版 1.41.635；之前的验收备份保留于 ignored build 目录。未发送 V2EX 回复、GitHub Issue 评论或其他外部通知。
