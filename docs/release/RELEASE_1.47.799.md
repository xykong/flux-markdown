# v1.47.799 发布与验收记录

## 发布身份与范围

- 用户授权：完成所有适用验证后发布；默认 minor，版本由 `scripts/release.sh` 生成。
- 标签 `v1.47.799`，提交 `4e435cc29232e826644db937d8abec12ef25da03`，`.version=1.47.799`。
- 功能：最近文档持久保存、当前文档路径复制、Mermaid/SVG 可读尺寸、SVG 居中及统一单图缩放。
- 本轮需求由维护者在开发会话中提出，无对应外部 issue/PR。GitHub 核实本轮实现提交作者为 `xykong`；自有工作直接合入 master，不创建 PR，也不借用其他报告的署名。
- 主要实现提交：`b43877d`、`d9d2b67`、`98901ad`、`14bd5ea`、`1f50e87`；`d05dbf0` 明确迁移限制。完整范围见 ignored 证据 `build/release-verification-1.47.799/commits.txt`。
- 已明确限制：系统在迁移前已经失效的历史不能恢复；每张图的临时缩放在文档重新渲染时重置。

## 测试与正式包

| 检查 | 状态 | 证据与限制 |
| --- | --- | --- |
| 最终标签构建及来源 | 通过 | [Release build](https://github.com/xykong/flux-markdown/actions/runs/42484964854)，Xcode 16.4 |
| 本地 renderer / appcast / publication | 通过 | 603 renderer tests；appcast 4 tests；publication 5 tests；links OK |
| 本地真实 WebKit | 通过 | 36 cases；原始 SVG、本机 UI 与此前安装已验证，见 DEBUG_SVG_IMAGE_SIZING.md |
| 最终标签原生测试 | 通过，1 项环境跳过已本机补验 | 394 tests：393 passed、1 skipped、0 failures；跳过项是相邻 Homebrew 仓库不存在，本机按同样文件路径断言核验通过 |
| macOS 11 / universal | 通过 | App、扩展、搜索服务均为 arm64/x86_64，Mach-O 与主应用 plist 的最低版本均为 11.0；不是 macOS 11 实机运行证明 |
| 嵌套签名与权限 | 通过 | 最终 DMG deep/strict 签名、沙箱与 release entitlements 校验通过；无开发 get-task-allow 或构建机私有路径 |
| manifest / notes | 通过 | 标签 SHA、DMG、MacPorts 源码包、原始 notes 的 SHA-256 均已冻结并验证；未改写已绑定 notes |
| 正式包实际安装/手工升级 | 通过 | 从本机开发版升级到 DMG 内 1.47.799，安装包 vendor installer 执行成功；7 条最近文档与默认编辑器设置保留；不是 Sparkle 自动升级或 brew install 测试 |

最终标签远程验证：603 renderer tests、36 WebKit cases 均通过；最终标签两次 CI（master/tag）均成功。下载 provenance/zip checksum 通过，App 与扩展的 173 个 renderer 资源完全一致。包内 App renderer 的 36 个用例和扩展 renderer 的原始 SVG 用例在本机独立复验通过。

独立 CryptoKit Ed25519 校验使用包内公钥验证最终 DMG，并拒绝单字节篡改。证据位于 ignored 的 `build/release-verification-1.47.799/`。

## 分发渠道

| 渠道/产物 | 状态 | 证据 |
| --- | --- | --- |
| GitHub Release | 通过 | [v1.47.799](https://github.com/xykong/flux-markdown/releases/tag/v1.47.799) 非草稿、非预发布，latest API 返回本版 |
| 公共 DMG / 源码包 | 通过 | 两个 canonical download URL 均成功下载，与 manifest 绑定的本地文件逐字节一致 |
| Sparkle | 通过 | 公共 `master/appcast.xml` 与本地文件逐字节一致；version=1.47.799、build=799、minOS=11.0、URL/大小/签名均对应最终 DMG |
| 三处发布说明 | 通过 | CHANGELOG、Release 原始正文、Sparkle HTML 包含同一五项用户变更与历史迁移限制；无独立致谢章节或借用外部报告署名 |
| Homebrew tap | 通过 | [9c7ba48](https://github.com/xykong/homebrew-tap/commit/9c7ba483d9adcad779f5f24b5050dcef70875617) 已推送；fetch 后两份文件与远端一致，版本/DMG SHA-256 和 Ruby 语法校验通过 |
| 官方 cask 草稿 | 通过 | `Drafts/flux-markdown-official.rb` 同提交更新；不等于向上游 homebrew-cask 提交或获接收 |

发布脚本在 Homebrew 阶段按预期以非交互状态 2 返回；只对两份 cask 显式提交/推送并回读解决。没有重跑发布脚本、重复生成 appcast 或替换已经公开的安装包。

| 资产 | SHA-256 |
| --- | --- |
| FluxMarkdown.dmg | `d74da7b92fa3d23ba655149f3786ed64564b7e2ecf6dba2c62c5b8971148b03d` |
| FluxMarkdown-1.47.799-macports-source.tar.gz | `5e5c37a32fa3ce43ba24bbcbc49336562cec8b129271b22c012a2d136a34f3d3` |
| 原始 release_notes_tmp.md | `28506bdcde6b79e7b8ac0ecf8172c75ab446315253cfefa96d86a79bbb1e525d` |

### 真实 Sparkle 升级补验

- 原始上一正式版隔离副本可调用“检查更新”，但本机辅助功能接口无法读取其更新对话框；没有将这一尝试当作 UI 升级通过。
- 使用仓库已有 `scripts/tests/sparkle-on-demand/Host.m` 自动化宿主，沿用上一正式版 1.46.779 的公开 feed、公钥和 Sparkle 2.9.3 runtime；仅宿主自动接受提示，不注入 `OnDemand.dylib`，不关闭 EdDSA/应用签名检查，也不修改待发布 DMG。
- 实际公共更新源发现 1.47.799，下载、校验、安装后启动了隔离目录内的新应用。实测 CFBundleShortVersionString=1.47.799、CFBundleVersion=799；deep/strict 签名通过，主程序字节与正式构建一致，新的运行进程位于该隔离目录，7 条既有历史仍在。
- 证据：`sparkle-upgrade.log`、`sparkle-relaunch-verification.log`、`history-after-sparkle.json`。这是实际 Sparkle 升级链路验收，自动化宿主并非未修改旧版主程序的完整 GUI 验收。
- 测试未回退 `/Applications` 的正式版；完成后停止隔离进程、注销并归档测试 app bundle，修复已安装正式版 Quick Look 注册，核对默认编辑器不变并重新打开用户文档。

## 本版宣传图

- 工具：Animal MediaKit；请求 `gpt-image-2.5-flare`，返回 `azure/gpt-image-2.5-flare`；trace `c65197e110ad0c2d8558fb2e778bdfc8`。
- Prompt：`artwork/v1.47.799-prompt.txt`。原图/服务日志在 ignored 的 `build/release-artwork-1.47.799/`。
- 原图视觉检查通过：1536×1024；产品、版本、主题拼写正确，无未经验证的性能/全面修复宣称。
- 压缩图视觉检查通过：1200×800 WebP，111496 bytes，quality 90；SHA-256 `3443486876b9efed9564cdc157a44a744a141bae3d94a45d646dc05fbf2d7b27`。
- [公开图片](https://github.com/xykong/flux-markdown/releases/download/v1.47.799/flux-markdown-v1.47.799-celebration.webp) 上传成功；API `content_type=image/webp`，digest/大小与本地一致，canonical 下载逐字节相同。
- Release 正文顶部插图，原正文完整保留；manifest-bound notes 未修改。公共页面实际图片 `complete=true`、`naturalWidth=1200`、`naturalHeight=800`，浏览器截图已视觉检查，版本与主题清晰、无破图。
- 页面证据：`build/release-artwork-1.47.799/release-page.png`；最终工作区图片：`build/release-artwork-1.47.799/flux-markdown-v1.47.799-celebration.webp`。

## Issue 与最终状态

- 无本轮外部 issue 跟进；不关闭或标记无关报告。
- 最终状态：发布及本流程适用验收完成。
- 当前未完成的必需发布门禁：无。正式版本也已安装到本机。
- 验证范围限制：最低系统为构建/包目标检查，未在 macOS 11 实机运行；Homebrew 验证为远端 cask/哈希/语法与实际 vendor installer，不声称执行了 `brew install`；Sparkle 使用上述自动化宿主验证真实链路。已失效历史恢复和跨重渲染保存单图临时缩放不属于本版保证。
- 收尾提交只包含本记录和宣传图 prompt；产品/发布脚本与已验证标签的输入保持一致，因此不会重建或替换公开产物。
