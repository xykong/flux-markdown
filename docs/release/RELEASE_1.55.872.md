# v1.55.872 发布与验收记录

## 发布身份与范围

- 用户授权正式发布。标签 `v1.55.872`，提交 `ceb10ac60ec69577da8c1451d15c1e98c414a849`，版本由 minor 发布脚本生成。
- 本版包含文档与图表独立缩放、专注查看、图表导出、阅读导航与位置恢复、紧凑图表按钮，以及反馈复现材料与回复提醒。维护者的工作直接合入 master。
- [Issue #73](https://github.com/xykong/flux-markdown/issues/73) 报告者为 [@syutheoria](https://github.com/syutheoria)。对应反馈复现材料条目保留署名和调查状态。未修改 Issue 状态。
- `v1.52.860` 和 `v1.53.865` 是未公开的构建候选，保留已冻结标签及失败证据。前者在旧 WebKit 下暴露坐标差异，后者在测试视口变更尚未生效时读到不稳定的几何值。最终修正坐标和测试的窗口、焦点及变量隔离后通过预检 [CI #44256634653](https://github.com/xykong/flux-markdown/actions/runs/44256634653)。最终标签的独立 [Release build #44258203219](https://github.com/xykong/flux-markdown/actions/runs/44258203219) 重新执行验证。
- 旧 WebKit 坐标兼容依据及上游实现可参见 [WebKit 300474](https://bugs.webkit.org/show_bug.cgi?id=300474)。兼容路径运行时检测 Element 与 Range 的返回值，再保留文档滚动偏移换算到视口坐标。
- [v1.54.870 构建](https://github.com/xykong/flux-markdown/actions/runs/44257103934) 通过 50 项 WebKit 用例与 464 项原生测试统计（跳过 5 项，失败 0 项），打包时旧校验清单拒绝了 SearchLauncher 已有的 FeedbackTransfers 目录。修复只更新签名校验脚本的精确期望列表。验证器接受当前权限，并拒绝附加 Documents 访问。该候选未公开。

## 测试与正式包

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| 最终标签构建 | 通过 | Release build #44258203219 对应标签完整 SHA，Xcode 16.4，下载的 bundle 来源及摘要校验通过 |
| 渲染器 / WebKit | 通过 | 标签 70 套 634 项渲染器测试、50 项真实 WebKit 用例，零失败 |
| XCTest | 通过 | 统计 464 项、跳过 5 项、零失败。跳过项为需显式启用的外部反馈测试及 CI 未检出相邻 Homebrew 仓库所需的用例，基准测试按工作流排除 |
| MacPorts / 发布脚本 | 通过 | 标签内 MacPorts export 测试，appcast 4 项、publication 5 项及链接检查 |
| 最低系统 / 双架构 | 通过 | 主程序、扩展、SearchLauncher 的 arm64/x86_64 slice 均为 minos 11.0 |
| 签名、权限与 manifest | 通过 | 深度签名，Quick Look 沙箱，SearchLauncher 精确权限，版本、标签、DMG、MacPorts 源码包及原始说明摘要 |
| 本机安装和功能 | 通过 | 从 DMG 将已验签的 App 复制到可写暂存目录，再用包内安装器安装，回读版本 1.55.872，保留原编辑器关联，实际 PDF 导出成功。旧 App 已备份 |
| Intel 真机 | 通过 | he-macpro x86_64 从同一正式包执行 PDF 导出，包内 renderer 的 10 项真实 WebKit 阅读用例通过 |

首次本地安装尝试把只读挂载上的 App 直接交给安装器，清除扩展属性失败。改用可写暂存副本后成功。发布沿用 ad-hoc 应用签名与 Sparkle EdDSA，`stapler validate` 显示无 Apple 公证票据。未执行 macOS 11 运行测试、真实 Sparkle 自动升级、Homebrew 命令安装或 Finder 内 Quick Look 文件保存的实机操作。

## 公共分发

- [GitHub Release](https://github.com/xykong/flux-markdown/releases/tag/v1.55.872) 已公开，为 latest，非预发布。DMG SHA-256 `c9c6bc2b618548fb5789546f1cb58b35f81096ca75deb5aaa2d22e6a8f4958fd`，MacPorts 源码包 SHA-256 `dac1df07297e55dbb4431ef96dcbbdc11de97266af02dd37b484833c83975a1b`，原始 notes SHA-256 `92716087da3d925c0e956dadfbfca0fe44d7982407d108d58b69a2d2bb32e7da`。
- [Sparkle 公共源](https://raw.githubusercontent.com/xykong/flux-markdown/master/appcast.xml) 由提交 `c1af4ee` 更新。默认源已回读到 1.55.872，包内公钥验 Ed25519 通过。Release、CHANGELOG 和 Sparkle 均保留条目内完整 @syutheoria 及 #73 链接。
- [Homebrew tap](https://github.com/xykong/homebrew-tap/blob/master/Casks/flux-markdown.rb) 和 [官方 cask 草稿](https://github.com/xykong/homebrew-tap/blob/master/Drafts/flux-markdown-official.rb) 更新至 `0a99cbb599ce43a8bda8b0813ea15891e59238b6`，版本与 DMG 哈希一致，Ruby 语法及远端文件比较通过。发布脚本在非交互 tap 提交阶段退出 2，已单独补完推送。官方草稿未向上游提交。

## 宣传图

- Animal MediaKit，模型 `gpt-image-2.5-flare`，trace `349dd83656f827b0e020409f1ba71830`。Prompt 见 [artwork/v1.55.872-prompt.txt](artwork/v1.55.872-prompt.txt)，原图及日志位于 ignored 的 `build/release-artwork-1.55.872/`。
- 目视检查 1536×1024 PNG 和最终 1200×800 WebP，确认产品名、版本和主题正确。WebP 108720 bytes，SHA-256 `ab9c7878d28294949ee4e834e87d4605cd9640f6e6328c915415d6f34425bcac`。Release asset MIME 为 image/webp，下载 CDN 为 application/octet-stream，公开文件与本地逐字节一致。
- 正文顶部图片实际加载，浏览器回读 complete=true 和 1200×800，已检查截图。更新前后比较 Release metadata、附件 ID 和摘要，原正文和 manifest-bound notes 保留。证据位于 `build/release-verification-1.55.872/`。

## 最终回读

- 从公开附件链接下载 DMG 与 MacPorts 源码包，逐字节比较均与 manifest 对应的本地产物一致。Ed25519 签名以最终 App 的公钥和公开下载的 DMG 独立验签通过。公开回读日志位于 `build/release-verification-1.55.872/public-verification.log`。
- Issue #73 保持 OPEN。此次发布提供反馈所需的复现材料，原问题仍在调查中，未添加 `done` 标签或发布修复回复。
