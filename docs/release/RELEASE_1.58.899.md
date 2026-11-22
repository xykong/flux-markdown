# v1.58.899 发布与验收记录

## 发布身份与范围

- 经维护者授权，按默认 minor 流程发布。标签 v1.58.899 的提交为 d9e96d8abaab6faaaa7e378507b0cde66ab8110b，部署目标保持 macOS 11。
- [PR #75](https://github.com/xykong/flux-markdown/pull/75) 带来选区复制和 Quick Look 显示修复，合并提交为 5d32e23。[PR #76](https://github.com/xykong/flux-markdown/pull/76) 改善 Follow Changes，合并提交为 23f9f94。两条 PR 作者均为 [@ziadulhuq](https://github.com/ziadulhuq)。GitHub Release、CHANGELOG 和 Sparkle 的对应条目均保留署名及链接。两条 PR 均未关联待关闭的 Issue。

## 测试与正式包

| 检查 | 结果 |
| --- | --- |
| 标签与构建来源 | [发布构建](https://github.com/xykong/flux-markdown/actions/runs/44666308261) 和 [标签 CI](https://github.com/xykong/flux-markdown/actions/runs/44666306697) 均通过且对应标签提交，验证了下载的 App 版本、来源和压缩包摘要 |
| 渲染器与原生 | 759 项 renderer 测试及 60 项真实 WebKit 用例通过。509 项 XCTest 中通过 504 项、跳过 5 项、零失败，另按工作流排除渲染 benchmark |
| 发布脚本与兼容 | appcast 4 项、publication 5 项、MacPorts 导出转换和文档链接检查均通过。主程序、Quick Look 扩展和 SearchLauncher 的 arm64、x86_64 slice 均验证 minos 11.0 |
| 签名、权限和 manifest | DMG 内嵌套深度签名和 release entitlements 通过。manifest 绑定标签、DMG、源码包和原始 notes。原始 notes SHA-256 为 5afb67ecde2f0b72d1de72c4a7d240fea469c7926488c3af980d8a42349cfa02 |
| Apple Silicon | 合并代码在 Finder 端到端通过选区复制、暂停、手动刷新后再次更新、恢复和双击停止。标签的产品代码与该候选一致。正式 DMG 暂存副本通过 PDF 导出，Finder 确认加载了正式扩展并显示 Follow 控件。测试结束恢复日常安装的扩展注册 |
| Intel he-macpro | 候选包 renderer 的 3 项原生 WebKit 用例通过。同一正式 DMG 的摘要、签名和 x86_64 PDF 导出通过 |

沿用 ad-hoc 应用签名及 Sparkle Ed25519 更新签名，stapler 回读无 Apple 公证票据。Finder 界面实测在 Apple Silicon 上完成。真实 Sparkle 自动升级、Homebrew 命令安装和 Intel Finder 界面未执行。macOS 11 验证范围为最低部署目标。

## 分发渠道

| 渠道 | 远端证据 |
| --- | --- |
| GitHub Release | [v1.58.899](https://github.com/xykong/flux-markdown/releases/tag/v1.58.899) 为公开 latest，非预发布 |
| DMG | 46,435,974 bytes，SHA-256 b5699585445c06d5864b20914bbae940d0df4f81334b81cab276fdaf14f5fd3a |
| MacPorts 源码包 | 32,963,852 bytes，SHA-256 07d8be92c3d14dc1e4dd5dcc178ed53c6d04ab185a3e9346697897c6f7a0ba43 |
| Sparkle | [公开更新源](https://raw.githubusercontent.com/xykong/flux-markdown/master/appcast.xml) 与 bdefebd9d09aa10d72b123fe51a7fa0a4598d180 一致。核对版本、构建号、最低系统、附件长度、URL 及条目内署名。用正式包公钥独立验证了公开 DMG 的 Ed25519 签名 |
| Homebrew | [tap cask](https://github.com/xykong/homebrew-tap/blob/master/Casks/flux-markdown.rb) 和[官方 cask 草稿](https://github.com/xykong/homebrew-tap/blob/master/Drafts/flux-markdown-official.rb) 均从远端读回提交 975aea59671254f6eb4d89237ddd376e2638507d，版本、摘要和 Ruby 语法一致。官方文件仍为草稿 |

Homebrew updater 在非交互模式准备好两个文件后退出 2，随后显式提交、推送并从 GitHub 回读。两个公开附件均与 manifest 逐字节核对。

## 宣传图

- Animal MediaKit 的 gpt-image-2.5-flare 请求超时。实际图片使用内置 ImageGen 生成。[初次及替代 Prompt](artwork/v1.58.899-prompt.txt)
- 已检查 1536×1024 PNG 原图、1200×800 WebP 和浏览器截图。WebP 大小 123,034 bytes，SHA-256 3702df34f8c2d60b3b2ecdbd2283d0e4f6a86cb1be76daa44e0a8285071bfb4a，与[公开附件](https://github.com/xykong/flux-markdown/releases/download/v1.58.899/flux-markdown-v1.58.899-celebration.webp)字节一致。
- 图片位于 Release Notes 顶部，原说明及原附件保持一致。浏览器回读图片为 1200×800，截图确认实际显示。原图和生成记录保存在 build/release-artwork-1.58.899/，验收截图及渠道读回在 build/release-verification-1.58.899/。

## 收尾

- 两条 PR 均已按英文回复并回读。[PR #75 回复](https://github.com/xykong/flux-markdown/pull/75#issuecomment-7029453998) · [PR #76 回复](https://github.com/xykong/flux-markdown/pull/76#issuecomment-7029454134)
- 正式发布、公开下载、发布图浏览器验收、署名核对和 PR 回复均已完成。实机测试范围见上。
