# v1.59.907 发布与验收记录

## 发布身份与范围

- 用户授权修正、合并并发布 [PR #77](https://github.com/xykong/flux-markdown/pull/77)。按默认 minor 发布，合并提交为 `bb9713d3d19b94a2868b4709fe7d21339bb50927`，标签提交为 `5a8118fc0c3cdca48d871fc0016b1f57c47ff867`。
- 源码视图的原生复制保留空行。Quick Look 的纯文本和 Markdown 复制也保留相同的空行数量。贡献者及问题报告者 [@Schnee013](https://github.com/Schnee013) 的署名和 PR 链接均已在 CHANGELOG、GitHub Release 和 Sparkle 对应条目中核对。PR 未关联单独的 Issue。

## 测试与正式包

| 检查 | 证据 |
| --- | --- |
| 标签 CI 与实际构建 | [标签 CI](https://github.com/xykong/flux-markdown/actions/runs/44991900163) 与[发布构建第 2 次尝试](https://github.com/xykong/flux-markdown/actions/runs/44991901721/attempts/2) 均通过并对应标签 SHA。已验证构建来源、压缩包摘要和包内版本。 |
| 产品测试 | 80 个 renderer 套件共 764 项、61 项真实 WebKit 用例通过。509 项 XCTest 中 504 项通过、5 项跳过、0 项失败，工作流排除渲染基准。appcast 4 项、publication 5 项、MacPorts 导出转换及文档链接检查通过。 |
| 架构与签名 | 主程序、Quick Look 扩展和 SearchLauncher 的 arm64、x86_64 slice 均以 macOS 11.0 为最低部署目标。嵌套 ad-hoc 签名、release entitlements 和 manifest 验证通过。包内无附加 Apple 公证票据。 |
| Apple Silicon 正式包 | 隔离解包后，应用实际导出 PDF。使用包内 Quick Look renderer，在 macOS WKWebView 验证单个和连续空行的原生选区、空白行高度，以及两种复制格式的四次原生剪贴板读回。 |
| Intel 正式包 | he-macpro（x86_64，macOS 26.7.3）DMG 摘要、应用签名和版本一致。真实 WKWebView 验证原生选区、空白行高度和四次复制请求进入原生桥接的准确文本。登出 SSH 会话的独立 NSPasteboard 探针写入返回 false，PDF 导出无结果后终止。 |
| 其他验证范围 | Finder 后台预览未取得可操作窗口，未完成 Finder 前台按键和工具栏端到端验收。未执行实际 Sparkle 自动升级、Homebrew 安装或 macOS 11 运行时测试。 |

发布构建首轮中，空行复制用例已通过，编辑器式行号链接用例以空回调列表失败。标签 CI 和同标签的发布构建第 2 次尝试均通过该用例。保留首轮日志与重试记录。manifest 绑定原始说明的 SHA-256 为 `a2a1692aff802979a88e6758666c857910d7ff76f6b08283649abc58c8917ef9`。

## 分发渠道

| 渠道 | 远端证据 |
| --- | --- |
| GitHub | [v1.59.907](https://github.com/xykong/flux-markdown/releases/tag/v1.59.907) 是公开 latest，非预发布。 |
| DMG | 46,474,955 bytes，SHA-256 `a1f9fb122e2fe1ff29bfc4c4ed84503ce68da67620f2ebc7a2acbe0c5eacd488`。公开下载与 manifest 逐字节一致。 |
| MacPorts 源码包 | 32,980,361 bytes，SHA-256 `4f9d4bbc9238d4d8c2f493e4da8854f0673b662027445bdc7b533eceb47075fa`。公开下载与 manifest 逐字节一致。 |
| Sparkle | [实际公共更新源](https://raw.githubusercontent.com/xykong/flux-markdown/master/appcast.xml) 与 `8388fc74171bcaefefea44217e9c16959ce433d4` 一致。核对版本、build、最低系统、URL、长度及署名。用正式包公钥独立验证了公开 DMG 的 Ed25519 签名。 |
| Homebrew | [tap cask](https://github.com/xykong/homebrew-tap/blob/master/Casks/flux-markdown.rb) 和[官方 cask 草稿](https://github.com/xykong/homebrew-tap/blob/master/Drafts/flux-markdown-official.rb) 均从远端提交 `164b99ae54b472a79f294e1eb0877d6699a7a3b3` 回读，版本、DMG SHA-256 和 Ruby 语法一致。 |

首次附件上传返回 HTTP 408，GitHub 中只有尚未完成的附件。换用 Intel 主机的 SSH 转发路径上传同一草稿、同一字节的正式附件，核对 GitHub 摘要后公开。Homebrew updater 完成两个文件更新后以非交互码 2 退出，随后显式提交推送并回读远端。

## 宣传图

- Animal MediaKit 请求并返回 `gpt-image-2.5-flare`，trace `9df8f979e2bc293cc2e8a51e400a1c42`。[本版 Prompt](artwork/v1.59.907-prompt.txt)
- 已检查 1536×1024 原图及 1200×800 WebP。最终图片为 107,664 bytes，SHA-256 `a216e4967289cba15088f0094427ed55e37c0a6aac19ff8f966c80469eef578c`。公开附件以 `application/octet-stream` 提供下载，文件识别为 WebP，字节一致。
- Release Notes 顶部的图片在公开页面实际显示，浏览器回读 1200×800，截图已检查。原图与生成日志位于 `build/release-artwork-1.59.907/`，发布、测试和回读证据位于 `build/release-verification-1.59.907/`。

GitHub、Sparkle、Homebrew tap 和发布图均已上线并回读。正式包的实机验证范围见上表。
