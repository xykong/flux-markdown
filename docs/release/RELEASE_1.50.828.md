# v1.50.828 发布与验收记录

## 发布身份与范围

- 用户授权：发布上线；默认 minor。
- 标签：`v1.50.828`；标签提交：`34e409fc23b9276bf6d34bc4ed2f9cbd4a2d838d`。
- 实现：`09815f6`；已安装 App 端到端验证：`4ef902c`。
- 修复 #72 行内数学后的额外空白；发起人通过 GitHub 实时核实为 [@avdbauw](https://github.com/avdbauw)，实现为维护者仓库中的 Agent 修复。CHANGELOG 对应修复条目包含个人主页和 [issue](https://github.com/xykong/flux-markdown/issues/72) 链接。
- 不改公式源文或数学内容；复制按钮移出正文流，错误恢复仍回到文档流。

## 测试与正式包

| 检查 | 状态 | 证据与限制 |
| --- | --- | --- |
| 最终标签构建 | 通过 | [CI 43457743640](https://github.com/xykong/flux-markdown/actions/runs/43457743640)，固定 Xcode 16.4 |
| 本地 renderer | 通过 | 67 suites / 613 tests，零失败 |
| appcast / publication | 通过 | 4 / 5 tests；check-links 通过 |
| 标签 WebKit / 原生测试 | 通过 | 38 real WebKit；430 XCTest，跳过 1，零失败；标签 renderer 613 tests 通过 |
| Intel 功能 | 通过（范围见限制） | he-macpro，x86_64，macOS 26.7.3；真实 WebKit 间距与数学基线/引用导出各 1 项通过。GUI 副屏不可用，未冒充前台复制验证 |
| macOS 11 最低目标 / universal | 通过 | 主程序、扩展、SearchLauncher 均含 arm64/x86_64，两个 slice 均 minos 11.0；未声称 macOS 11 runtime |
| 签名 / entitlements / manifest | 通过 | deep/strict 嵌套签名、release entitlements、manifest 校验通过；Sparkle Ed25519 用正式包公钥独立验证通过 |
| 正式包安装 / Intel 启动 | 通过 | vendor installer：arm64 安装 /Applications，Intel 安装隔离目录；两端版本 1.50.828、签名通过，PDF 导出成功。本机 GUI 间距正常，截图已检查 |

Intel 首次执行因传输漏掉测试 helper 未启动；补传后前台探针正确拒绝不存在的副屏。
随后临时 geometry-only 探针保留原间距断言，仅去除焦点检查，在 App 与 Quick Look context
通过；该临时诊断代码不进入产品。原始失败与成功日志均保存在证据目录。

## 分发渠道

| 渠道/产物 | 状态 | 远端证据 |
| --- | --- | --- |
| GitHub 非草稿 / 非预发布 | 通过 | 实际 latest 为 v1.50.828，draft=false / prerelease=false |
| DMG / MacPorts 公共下载 | 通过 | 默认公开 URL 下载，cmp 与本地一致，GitHub asset digests 与 manifest 一致 |
| Sparkle 签名及默认公共 feed | 通过 | appcast.xml 公共 master 默认 URL 字节一致；包内公钥独立 Ed25519 验证通过；build 828、最低系统 11.0、URL/长度一致 |
| Release / CHANGELOG / Sparkle 条目内署名 | 通过 | 三处完整 @avdbauw、个人主页及 #72 链接，均在本条修复内；浏览器可见 |
| Homebrew tap / 官方 cask 草稿 | 通过 | homebrew-tap 提交 3018a4f；fetch/diff、远端版本/DMG SHA、两个 Ruby 语法检查通过。草稿不等于官方上游接收 |

## 本版宣传图

- 实际工具：Animal MediaKit；请求/返回模型 `gpt-image-2.5-flare`，resolved `azure/gpt-image-2.5-flare`；trace `71e769556bdfab32316c470063bad29b`。
- Prompt：`artwork/v1.50.828-prompt.txt`。
- 原图与生成日志：`build/release-artwork-1.50.828/`（ignored）；1536×1024 PNG。
- 原图与最终图均已视觉检查：完整版本、拼写和用户价值准确，文字清晰。
- 最终图：1200×800 WebP，101518 bytes；`flux-markdown-v1.50.828-celebration.webp`。
- 最终图 SHA-256：`c9459fe043b445998a3b2100b8204c77123c7ac036c8f57d0a968c55cbaffa49`。
- [公共图](https://github.com/xykong/flux-markdown/releases/download/v1.50.828/flux-markdown-v1.50.828-celebration.webp) 下载与原字节一致；asset MIME 为 image/webp，GitHub 下载 CDN 响应实际为 application/octet-stream，Pillow 解码为 WEBP，1200×800。
- Release 顶部引用正确，原正文保留；只通过独立 body payload 增加图片，metadata 和 asset ID/digest 未变，manifest-bound notes 未改写。
- 浏览器 complete=true、naturalWidth=1200 / naturalHeight=800；顶部和滚动后的实际截图 `release-page.png`、`release-page-bottom.png` 已视觉检查，图与署名正常。Orca full-screenshot 拼接出现重复顶部，保留其证据但不以它替代实际窗口截图。

## Issue 与最终状态

- #72 已添加 done；[英文发布回复](https://github.com/xykong/flux-markdown/issues/72#issuecomment-6858475511) 已独立回读，包含修复、版本、Homebrew 命令与 DMG 链接。issue 保持 OPEN。
- 当前状态：发布及本次适用验收完成。必需渠道与宣传图无待完成项；未执行的额外验证见正式包范围限制。
- 原始证据：`build/release-verification-1.50.828/`、`/tmp/issue72-release-prepare.log`。
- 发布后元数据：仅按流程在 Release 正文顶部增加庆祝图；未改写 manifest-bound notes 或重建制品。

## 正式包验收补充

- DMG SHA-256：`739fe1f63750624d2d00b876887bb034da3e4c88654e64fbb424edebc72cda31`。
- MacPorts SHA-256：`0a24109733d763fe3ce7373c0781c480b7fc9cef9e6123dda851add82db56147`。
- Manifest-bound notes SHA-256：`ce59793d3cebfafff49f4d62cd60b17f6f2c918e92c5175a2430b0eafb6ce62f`。
- 沿用既有 ad-hoc 应用签名 + Sparkle EdDSA 分发流程；`codesign` 读回为 adhoc，stapler 检查确认无公证票据。不声称 Developer ID 或 Apple 公证。
- arm64 正式包已通过 vendor installer 替换本机安装，保留编辑器偏好；实际窗口版本读回 1.50.828，公式间距正常。截图 `installed-app.png`。
- Intel 正式包通过同一 vendor installer 安装到 `/tmp/flux-release-1.50.828/installed/`，实际 x86_64 进程完成示例 PDF 导出。日志 `intel-official-install.log`，PDF 已回传。
- 不将安装器验证称为实际 Homebrew 安装；未执行真实 Sparkle 自动升级、Intel 前台 GUI 或本版 Finder 托管 Quick Look 手工验证。
- Intel 验证后已注销隔离 App/扩展的系统注册；测试安装和日志保留在临时证据目录。未替换远端日常 Applications 安装。

## 上传重试

- 首次 `publish-release.sh` 在 GitHub 附件阶段收到 `HTTP 408: Upload body timed out due to inactivity`，未公开草稿，未上传成功任何附件。
- 独立读回同一草稿 ID `444436561` 的 assets 为空，保留失败日志 `publish.log`。
- 使用同一 tag/manifest-bound 制品，按文件顺序、`GODEBUG=http2client=0` 重试上传；不重新运行 appcast 生成器、不重新签名、不重建或覆盖已成功附件。

## 最终渠道回读与收尾

- [正式发布](https://github.com/xykong/flux-markdown/releases/tag/v1.50.828) 为 GitHub latest，两个产品附件和庆祝图均公开可下载。
- Sparkle feed 提交：`fcae7f1`；MacPorts Portfile：`4fde4ac`；Homebrew：`3018a4f`。
- Homebrew updater 按预期非交互退出 2，仅手动完成其 cask 提交/推送；无重复 publication、appcast 重签或附件替换。
- 首次 HTTP 408 不再阻塞：同一草稿顺序 HTTP/1.1 上传完成，两产品附件公共下载及 SHA-256 校验通过。
- 发布记录与 prompt 随纯文档收尾提交推送；该提交不改变已验证的标签代码、制品或签名。
