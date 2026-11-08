# v1.42.645 发布记录

日期：2026-10-29。用户授权发布；按默认 minor 策略从 1.41 升至 1.42，构建号 645 由发布脚本按提交数生成。

- [功能 PR #66](https://github.com/xykong/flux-markdown/pull/66) 已通过 CI 并合并。包含默认开启的悬停复制控件、原生剪贴板确认与错误反馈、关闭 Typst 渲染后的源码显示，以及外观设置底部的统计/支持选项。
- 标签 `v1.42.645` 对应提交 `4844b1505e7116cc7b16e2a0cbe891c600d00180`；[GitHub Release](https://github.com/xykong/flux-markdown/releases/tag/v1.42.645) 已公开，非 draft、非 prerelease。
- [正式构建 40841020395](https://github.com/xykong/flux-markdown/actions/runs/40841020395) 使用 Xcode 16.4 / macos-15，47 个 renderer suite、416 项测试、27 项真实 WebKit 检查通过。原生执行 377 项测试，1 项预期跳过（缺少相邻 Homebrew tap）、0 失败；仓库既有的旧 benchmark harness 按工作流排除。
- 主应用、QuickLook、XPC helper 均包含 arm64/x86_64，两个架构的部署目标均为 macOS 11.0；这是构建/部署目标验证，不是 macOS 11 真机测试。产物版本、commit provenance、归档 SHA256、嵌套签名和 Release entitlements 均通过发布脚本校验。
- DMG SHA256：`228e6065117584ce88056b1d126cc4b5988a661ac0b6a2072735ce4e80996d1a`。
- MacPorts source tarball SHA256：`86021fd780fdd02c85c64312fde74bb99cd9e08513e19782edbdae8b3d5c9cf6`。Portfile 更新已推送，提交 `091235e`。
- `release-manifest.json` 将标签提交、DMG、源码包和发布说明绑定。公开 Release 两项 asset digest 与本地 manifest 一致；publication 重试又下载并逐字节比对了两项资产。
- Sparkle feed 更新已推送，提交 `de3c2b9`。从 GitHub 重新读取 feed，首项版本为 1.42.645。用正式 app 内 `SUPublicEDKey` 和 Python cryptography 的 Ed25519 验证器独立验证最终 DMG 签名，并核对版本和文件长度；未宣称执行 Sparkle GUI 自动更新。
- 正式 DMG 先复制到可写 staging 后通过包内 vendor installer 安装，安装前后 Markdown 默认编辑器状态逐字节一致，`--quicklook-self-test` 返回 `quicklook_preview=rendered`。
- Homebrew tap cask 与官方候选草稿更新至同一版本/SHA，tap 提交 `ade5686` 已推送；官方候选仍是 tap 内草稿，没有提交或合并到 homebrew/homebrew-cask。
- 实际 `brew upgrade --cask xykong/tap/flux-markdown` 从 1.41.635 升级至 1.42.645 成功。升级后的 `/Applications/FluxMarkdown.app` 版本、严格深度签名、QuickLook 注册路径均正确；Markdown 默认编辑器仍与升级前一致。本机保留正式发行版。
- Homebrew updater 的非交互模式返回 2 时，已完成其准备好的 cask 提交/推送后重试 publication。保留已经独立验证的 Sparkle feed 条目；`publication-status.txt` 最终为 `github and sparkle complete; homebrew updater completed`。
- [Issue #65 发布回复](https://github.com/xykong/flux-markdown/issues/65#issuecomment-6491812217) 已发送（英语，与原 Issue 一致），添加 `done`，未关闭 Issue。

原始构建日志、安装前后状态与签名记录保存在 ignored `build/release-copy-controls/`，正式产物和发布 manifest 保存在 `build/artifacts/`。功能开发期实际 App/QuickLook 剪贴板读回、PDF、键盘、紧凑预览验证详见 [DEBUG_BLOCK_COPY.md](../debug/DEBUG_BLOCK_COPY.md)。
