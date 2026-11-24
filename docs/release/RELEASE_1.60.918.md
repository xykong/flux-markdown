# v1.60.918 发布与验收记录

## 发布身份与范围

- 用户授权验证 PR #79、合并后发布并回复。按默认 minor 发布。标签提交为 `eee788919969e5676497222df32191f22fbdeb90`。
- [PR #79](https://github.com/xykong/flux-markdown/pull/79) 修正 Finder Quick Look 中的拖选、双击选词、三击选段和窗口外松手时的复制工具条。合并提交为 `f1e44ec2fdf5f699ab83463152fb3f1afae9af4f`。
- 首次发布已合并的 [PR #78](https://github.com/xykong/flux-markdown/pull/78)，源码纯文本复制保留行结构。两个 PR 的作者和报告者均为 [@Schnee013](https://github.com/Schnee013)。CHANGELOG、GitHub Release 和 Sparkle 的对应条目均含完整署名和对应 PR 链接。未发现关联的独立 Issue。

## 测试与正式包

| 检查 | 结果与证据 |
| --- | --- |
| PR 与标签 | [PR CI](https://github.com/xykong/flux-markdown/actions/runs/45311797622)、[标签 CI](https://github.com/xykong/flux-markdown/actions/runs/45312494938) 和[正式构建](https://github.com/xykong/flux-markdown/actions/runs/45312497014)通过。发布构建 SHA、App 版本和压缩包摘要均核对。 |
| renderer / 原生 | 778 项 renderer 测试和 61 项 WebKit 用例通过。511 项 XCTest 中 506 项通过、5 项跳过，零失败，工作流排除渲染基准。appcast 4 项、publication 5 项、MacPorts 导出转换、文档链接检查通过。 |
| 兼容与签名 | 主程序、Quick Look 扩展和 SearchLauncher 的 arm64、x86_64 均保持 macOS 11.0 最低目标。DMG 内嵌套 ad-hoc 签名、release entitlements 和 manifest 均通过，包内无附加 Apple 公证票据。 |
| Finder 正式包 | Apple Silicon 的 Finder 进程加载隔离注册的 v1.60.918 扩展。左侧留白拖选、双击选词、三击选段、左侧窗口外松手均实测通过。用纯文本和 Markdown 两个复制工具条按钮从系统剪贴板读回预期文本。恢复原扩展注册和原剪贴板。 |
| 双架构正式资源 | Apple Silicon 和 Intel 使用正式 DMG 的 App 导出 PDF。两台机器在真实 WKWebView 中以 DMG 内置 renderer 验证 AppKit 复制、CRLF、diff、TSV 和渲染视图 HTML。Intel he-macpro 为 x86_64、macOS 26.7.3。两架构还验证标签 Swift 源码的原生手势仲裁。 |

本地新增测试首轮受窗口外 WKWebView 暂停动画帧影响。测试改为有界等待并单独驱动工具条的帧回调后，窗口外 WKWebView 与 CI 均通过。Finder 自动化首轮因预览内容实际由独立扩展进程接收而被工具拒绝，之后使用已获授权的前台指针输入和真实 Finder 工具条完成上述验收。Finder 的 Cmd+C 尝试没有取得预期的独立读回，AppKit 的原生复制由双架构 WKWebView 验证。未执行 Intel Finder 前台操作、实际 Sparkle 自动升级、Homebrew 命令安装或 macOS 11 运行时测试。

## 分发渠道

| 渠道 | 远端证据 |
| --- | --- |
| GitHub | [v1.60.918](https://github.com/xykong/flux-markdown/releases/tag/v1.60.918) 已公开，标记为 latest，非预发布。 |
| DMG | 46,448,314 bytes，SHA-256 `4ec1623533135d990d763f03fe8f436b4a8588dd1aadc74738e62042278a569c`。公开下载与正式文件逐字节一致。 |
| MacPorts 源码包 | 32,977,688 bytes，SHA-256 `727ac0878ea4b3036d88bdba234e505bacf46acefe2816d9a9b1fb75493c1e01`。公开下载与正式文件逐字节一致。 |
| Sparkle | [默认公共更新源](https://raw.githubusercontent.com/xykong/flux-markdown/master/appcast.xml) 回读一致，核对版本、build、最低系统、URL、长度和条目内署名。使用包内公钥验过公开 DMG 的 Ed25519 签名。 |
| Homebrew | [Tap cask](https://github.com/xykong/homebrew-tap/blob/master/Casks/flux-markdown.rb) 和[官方 cask 草稿](https://github.com/xykong/homebrew-tap/blob/master/Drafts/flux-markdown-official.rb) 从远端提交 `266f3a5c27b0ac93366954fb607bbcf2b193c797` 回读。Ruby 语法、版本和 DMG 摘要均一致。 |

Homebrew 脚本在非交互模式准备完两份 cask 后退出 2，随后显式提交推送并回读。manifest 绑定原始说明的 SHA-256 为 `984ee7c721f3c39ee490410b7d93b101f50d9201ab8b4f0f277b70c76e64cf19`。

## 宣传图与回复

- Animal MediaKit 请求并返回 `gpt-image-2.5-flare`，trace `b895dc6fe53a22bb16dfcbbf990acb2d`。[本版 Prompt](artwork/v1.60.918-prompt.txt)
- 已检查 1536×1024 原图和最终 1200×800 WebP。最终图为 107,890 bytes，SHA-256 `622c87abe819cc5c59b076fc95c26a635a8f890a69f7693eb710e2dd0f3dbe8c`，公开下载与本地字节一致。浏览器中已从 Release Notes 顶部读取实际渲染的图像并检查截图。
- 已发送并读回 [PR #79 英文回复](https://github.com/xykong/flux-markdown/pull/79#issuecomment-7120473626)，包含版本、实测结果、Homebrew 更新命令和 DMG 链接。
- 产物、发布、截图、Finder 测试和回读证据位于 `build/release-verification-1.60.918/`。宣传图原件及日志位于 `build/release-artwork-1.60.918/`。
