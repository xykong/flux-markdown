# v1.57.885 发布与验收记录

## 发布身份与范围

- 经维护者授权完成 PR #74 的验收和正式发布。标签为 `v1.57.885`，提交为 `522cfde8e9819c110372806ad302902bcd7cbbfb`。版本由 minor 发布脚本生成。
- 合并提交 `7df0435` 带来 Quick Look 的 Follow Changes、2 MiB Markdown 窗口和渐进渲染。维护者在 [PR #74 的回复](https://github.com/xykong/flux-markdown/pull/74#issuecomment-6994748246) 感谢 [@ziadulhuq](https://github.com/ziadulhuq) 并说明了集成调整。本版 GitHub Release、CHANGELOG 和 Sparkle 对应功能条目均保留完整署名和 PR 链接。
- `v1.56.883` 是未公开的候选，保留了已冻结标签及通过的[构建记录](https://github.com/xykong/flux-markdown/actions/runs/44490652664)。Finder 基线验收暴露原生通知将辅助反馈操作全部铺开的问题。修正提交 `881011c` 把报告详情、复现材料和回复管理收进原生菜单，保留直接恢复、报告和关闭。正式包重新按新标签生成。

## 测试与正式包

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| 最终标签与构建来源 | 通过 | [Release build 44491655691](https://github.com/xykong/flux-markdown/actions/runs/44491655691) 和 [标签 CI 44491653579](https://github.com/xykong/flux-markdown/actions/runs/44491653579) 均对应最终 SHA。下载的 App 压缩包摘要、提交和版本一致 |
| 渲染器与原生 | 通过 | Jest 720 项、真实 WebKit 56 项、XCTest 493 项中通过 488 项及跳过 5 项，零失败 |
| 发布与兼容 | 通过 | appcast 4 项、publication 5 项、MacPorts 导出转换通过。主程序、扩展、SearchLauncher 的 arm64 和 x86_64 slice 均为 minos 11.0 |
| 签名、权限与 manifest | 通过 | DMG 深度验签，Quick Look 和 SearchLauncher 权限校验通过。manifest 绑定标签提交、DMG、MacPorts 源码包及原始 notes |
| Apple silicon 安装 | 通过 | 正式 DMG 内的安装脚本使用可写暂存副本安装。安装版本和深度签名回读通过，默认编辑器设置前后相同，正式包 PDF 导出包含测试标记 |
| Apple silicon Finder | 通过 | 安装路径的正式扩展记录 2 MiB 试件完整渲染。超限试件只显示紧凑通知。开启 Follow 后尾部和追加内容可见，关闭 Follow 后回到开头并恢复超限提示 |
| Intel | 通过已执行的用例 | he-macpro 的 x86_64 正式 DMG 摘要相同，签名和 PDF 导出通过。包内渲染器 2 项 Follow 用例和 10 项阅读用例通过 |

首次本地运行新增菜单断言按预期失败，修正后连同相邻回归共 46 项通过。正式工作流派发后首次读取返回 404，随后复用同一次工作流取得产物。Finder 初次在已打开的预览中切换文件时出现纯文本，排查发现测试暂存副本与安装副本同时注册；注销本次暂存副本并重新登记安装版后，日志指向 `/Applications/FluxMarkdown.app` 中的正式扩展。

沿用此前的 ad-hoc 应用签名和 Sparkle EdDSA 签名。Apple stapler 回读显示应用无附加公证票据。Intel SSH 会话无法代替 Finder 桌面交互；Finder 实机交互在 Apple silicon 完成。macOS 11 以二进制最低系统目标验收。本次未执行真实 Sparkle 自动升级和 Homebrew 命令安装。反馈菜单的可见入口由 Finder AX 回读证实，菜单项和 action 由 XCTest 校验；测试未提交反馈。

### 大文件性能

- M5 Max 后台 WKWebView 直接加载正式包 renderer，2 MiB 密集 Markdown 5 次，正文首批进入 DOM 中位数 137 ms，主线程间隔最高 140 ms，完整渲染中位数 751 ms。5 次 DOM 指纹完全一致。
- Finder 内两个未缓存试件从自动选中文件到首个录得正文的帧，采样区间分别为 384–492 ms 和 402–492 ms。另一次对新试件自动按空格时，首个录得正文的帧采样区间为 642–762 ms，包含自动化命令和截屏开销。同一次正式扩展从 `prepared` 到 `rendered` 为 1.21 s。
- Finder 可见首帧和 WebKit 主线程间隔是分别采样的指标。证据收录在忽略的 `build/release-verification-1.57.885/`，包含截屏、时间戳和扩展路径。

## 分发渠道

| 渠道 | 结果 | 证据 |
| --- | --- | --- |
| GitHub Release | 通过 | [v1.57.885](https://github.com/xykong/flux-markdown/releases/tag/v1.57.885) 已公开，为 latest，非预发布 |
| DMG 公共下载 | 通过 | 46,436,406 bytes，SHA-256 `d9359ec7f66b378b1e1728773190f47385b34fedc22105f77009ac041e8bbbbd` |
| MacPorts 源码包公共下载 | 通过 | 32,939,320 bytes，SHA-256 `5831a2bce9fd2b0aefd2c5a88f2202c33bb365f50e4692f8d75c6edf39246111` |
| Sparkle | 通过 | [实际公开 feed](https://raw.githubusercontent.com/xykong/flux-markdown/master/appcast.xml) 对应提交 `88b8cb4`，版本、长度、URL、最低系统及署名回读正确。使用正式包内公钥对公开 DMG 独立验证 Ed25519 |
| Homebrew | 通过 | [tap cask](https://github.com/xykong/homebrew-tap/blob/master/Casks/flux-markdown.rb) 和[官方 cask 草稿](https://github.com/xykong/homebrew-tap/blob/master/Drafts/flux-markdown-official.rb) 均回读到 `b9849a2c0b7879c4c14a70322b2f6c7fc749b211`，版本、哈希和 Ruby 语法一致。官方草稿尚无上游提交 |

Homebrew updater 在非交互模式完成文件修改后退出 2，已显式提交、推送并从 GitHub 读回。普通附件连接吞吐较低，从相同公开 URL 按字节区间取得余下数据，合并恢复后与 manifest 一一验证。原始 notes SHA-256 为 `a487d4b04e8cc8ad8864b81b200a31d524a7e696fb39995b05fea1b68f0eeab3`。

## 宣传图

- Animal MediaKit，模型 `gpt-image-2.5-flare`，成功请求 trace `9bd807e35f4f889d4cb972f7424b45a4`。首次请求超时后用同一 prompt 重试生成。[本版 prompt](artwork/v1.57.885-prompt.txt)
- 检查了 1536×1024 PNG、最终 1200×800 WebP 和发布页截图。WebP 115,458 bytes，SHA-256 `7bd9fc56e401cfed65fdb5d985092eb6568b7dd6726938d05935da8bdf66c0bf`。Release asset MIME 为 `image/webp`，[公开附件](https://github.com/xykong/flux-markdown/releases/download/v1.57.885/flux-markdown-v1.57.885-celebration.webp) 与本地逐字节一致。
- 图片置于原正文顶部，原正文、标签、原附件 ID 及摘要保持一致。实际浏览器 DOM 读回图片已加载且为 1200×800，截图确认可见。

## 收尾

- PR #74 已合并、已回复。此次未将其他 Issue 标记为修复。
- 发布及本次适用的验收已完成。未执行的独立场景见测试记录。
