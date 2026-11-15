# v1.51.834 发布与验收记录

## 发布身份与范围

- 用户授权：发布新版本，并回复 #72、附修复前后截图请报告者确认效果；默认 minor。
- 标签 `v1.51.834`；标签提交 `5dd7a59a64414c83f56c4b76da5e83ddb12d601d`；版本由发布脚本生成。
- 实现提交 `949be61`；对比截图提交 `dfe175d`；自有工作直接合入并推送 master。
- 修复独立公式上方由隐藏复制工具占行造成的额外空白，保留正常公式边距、先前行内间距修复及复制错误恢复。
- GitHub 实时核实报告者为 [@avdbauw](https://github.com/avdbauw)，[原反馈](https://github.com/xykong/flux-markdown/issues/72#issuecomment-6880530545)；维护者仓库 Agent 实现。CHANGELOG、Release、Sparkle 均保留对应条目内的完整署名、主页和反馈链接。

## 测试与正式包

| 检查 | 状态 | 证据与限制 |
| --- | --- | --- |
| 最终标签构建 | 通过 | [CI 43687774658](https://github.com/xykong/flux-markdown/actions/runs/43687774658)，head SHA 与标签一致，固定 Xcode 16.4 |
| 标签 renderer | 通过 | 67 suites / 614 tests，零失败 |
| 标签真实 WebKit | 通过 | 39 cases；包括新增 display-math 间距对比及既有交互覆盖 |
| 标签原生测试 | 通过 | 430 XCTest，跳过 1，零失败 |
| appcast / publication / links | 通过 | 本地 4 / 5 tests；check-links、diff check 通过 |
| Intel 功能 | 通过（范围见限制） | he-macpro、x86_64、macOS 26.7.3；开发 bundle 与最终安装包分别通过 windowless WebKit 间距矩阵；安装包实际进程 PDF 导出成功 |
| arm64 安装及产品导出 | 通过 | vendor installer 安装到 /Applications，版本读回 1.51.834，deep/strict 签名与实际进程 PDF 导出通过；旧安装保留在证据目录 |
| 正式包公式截图 | 通过 | 最终正式包内 renderer 的 windowless WKWebView 截图与已确认 after.png 逐字节相同，已视觉检查 |
| macOS 11 最低目标 / universal | 通过 | 主程序、扩展、SearchLauncher 均含 arm64/x86_64；两个 slice 均 minos 11.0。未声称 macOS 11 runtime 测试 |
| 签名、权限及 manifest | 通过 | deep/strict、release entitlements、标签/DMG/源码包/原始 notes manifest 校验通过；Sparkle Ed25519 用正式包公钥独立验证通过 |

沿用现有 ad-hoc 应用签名与 Sparkle EdDSA 分发方式。stapler 检查确认本包没有 Apple 公证票据；不声称 Developer ID 或 Apple 公证。未执行真实 Sparkle 自动升级、实际 Homebrew 安装、本版 Finder 托管 Quick Look 手工验证或 Intel 前台 GUI；这些不由窗口外 renderer/CLI 结果代替。Intel 测试安装使用隔离目录，结束后注销其 App/扩展注册，未替换远端日常 Applications 安装。

## 分发渠道

| 渠道/产物 | 状态 | 证据 |
| --- | --- | --- |
| GitHub Release | 通过 | [v1.51.834](https://github.com/xykong/flux-markdown/releases/tag/v1.51.834)，draft=false、prerelease=false，实际 latest 为本版 |
| DMG / MacPorts 公共下载 | 通过 | 默认公开 URL 下载与本地逐字节一致，asset digest 与 manifest 一致 |
| Sparkle 默认公共 feed | 通过 | 实际 master/appcast.xml 与本地一致；版本/build、最低系统、URL、长度、签名一致；提交 `1a0f5d3` |
| 条目内署名 | 通过 | Release/CHANGELOG/Sparkle 完整 @avdbauw、主页与反馈链接；浏览器实际可见 |
| Homebrew tap / 官方 cask 草稿 | 通过 | 提交 `8e4acc4`；fetch/diff、公共 raw 文件版本和 DMG SHA、两个 Ruby 语法检查均通过。草稿不等于官方上游接收 |

- DMG SHA-256：`22c75628e179c1553b01cc0d1c6da0cab16f507376720373e4cd45254f38edc7`。
- MacPorts 源码包 SHA-256：`4ee1058b4b557a018e5bb9ed2f2fb48ccdde03c0e0293333d3d4ef61ea875ff0`。
- Manifest-bound 原始 notes SHA-256：`a0594d86501a2eb0496b22ea1fdaa9f95d2e1dae5c0741e7f2d481b39aab3bbc`。
- `publish-release.sh` 在 Homebrew 非交互阶段按预期退出 2；只手动完成其 cask 提交/推送，没有重建产物或重跑 appcast 签名。该阶段现已完成。

## 本版宣传图

- 实际工具 Animal MediaKit；请求/返回模型 `gpt-image-2.5-flare`，resolved `azure/gpt-image-2.5-flare`；trace `e4517554654fc0fbc6707f93354e57f1`。
- Prompt：`artwork/v1.51.834-prompt.txt`；原图及日志：`build/release-artwork-1.51.834/`（ignored）。
- 原图 1536×1024 PNG；最终 WebP 1200×800、109960 bytes，SHA-256 `b84c06cea527b0ad81cf58cead5de220322dd05f5e9d7f53cef569f72d88b470`。
- 原图及压缩图均已视觉检查，产品名、完整版本号、主题清晰准确。
- [公共宣传图](https://github.com/xykong/flux-markdown/releases/download/v1.51.834/flux-markdown-v1.51.834-celebration.webp) 下载与本地一致；asset MIME 为 image/webp，实际 CDN 为 application/octet-stream，图像可正常解码。
- Release 正文顶部增加图片，原正文保留；修改前并发检查、修改后回读确认 metadata 和全部 assets ID/digest 不变，未改写 manifest-bound notes。
- 浏览器 complete=true、naturalWidth=1200/naturalHeight=800；顶部和下半页截图已检查，实际显示及条目内署名正确。

## Issue 与最终状态

- [英文回复](https://github.com/xykong/flux-markdown/issues/72#issuecomment-6890867308) 已发送并独立读回；包含版本、修复解释、Homebrew 命令、DMG、同一示例修复前后截图，以及明确询问 After 是否符合期望。
- 两张图使用本版不可变标签中的公开 raw URL；公开下载与原图一致；浏览器两张图均 complete=true、1600×1800，实际并列显示已截图检查。
- 回复说明这是我们的复现截图，并请报告者在原始文档中确认。报告者效果确认仍待反馈，不能将发布完成视为作者已验收。
- `done` 已保留并回读，Issue 保持 OPEN，交由报告者确认和关闭。
- 当前状态：发布及本次适用验收完成；用户要求的回复和截图展示已完成；无待完成发布门禁。额外未执行范围见正式包限制，外部待办为报告者确认效果。
- 原始证据：`build/release-verification-1.51.834/`、`/tmp/flux-issue72-display-release-prepare.log`；Intel 隔离安装 `/tmp/flux-release-1.51.834/`。收尾提交仅含记录/prompt，不改变已验证标签、产品或脚本内容。
