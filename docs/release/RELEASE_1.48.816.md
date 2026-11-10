# v1.48.816 发布与验收记录

## 发布身份与范围

- 用户授权接受 PR #70 并发布新版本；默认 minor。
- 标签 v1.48.816，提交 994dbb99cc1d03d36229d875882774fa0cc11bdb。
- GitHub PR #70 已合并，原实现提交 5fc0d724，作者 @Schnee013；条目内署名与完整链接已写入 CHANGELOG。
- 范围：普通 Finder 渲染和源码预览选区 Command-C；全屏仍可能复制 Finder 文件名，使用右键拷贝。
- 产品验证见 docs/debug/DEBUG_QUICKLOOK_SELECTION_COPY.md；Intel 11 项聚焦 XCTest 通过，两架构实际普通预览复制/关闭/导航通过。全屏失败明确保留。Intel ad-hoc 搜索交接 XPC 校验失败，不能视为该 PR 新回归。

## 发布执行

- appcast-generation 4 项、release-publication 5 项通过；链接检查和 diff 检查通过。
- 最终标签发布构建：https://github.com/xykong/flux-markdown/actions/runs/42854428287 已通过。
- 最终提交 CI：https://github.com/xykong/flux-markdown/actions/runs/42854417266 已通过；同 SHA 重复运行 42854426917 已取消。603 renderer 测试、36 real WebKit 用例通过；原生 XCTest 409 项、跳过 1 项、失败 0 项。原始日志 build/release-verification-1.48.816/ci.log。
- 沿用现行 ad-hoc 应用签名与 Sparkle EdDSA 更新签名流程；不声称 Developer ID 签名或 Apple 公证。
- DMG、manifest、公共渠道、最终包验证均待完成，尚未公开新版 Release。

## 宣传图

- Animal MediaKit，requested gpt-image-2.5-flare，resolved azure/gpt-image-2.5-flare。
- prompt: docs/release/artwork/v1.48.816-prompt.txt。
- 原始 1536×1024 PNG 与生成日志：build/release-artwork-1.48.816/。
- 最终 WebP：1200×800，124806 bytes；原图和压缩图已目视检查，版本与拼写正确。
- 公共上传与发布页视觉验收待完成。

## 当前状态

PR 已接受；发布准备进行中。远程构建仍排队，未把排队记为测试通过。

## 最终包验证

- 最终标签工作流 42854428287 全部通过；日志 release-build.log 已归档。
- 下载 commit.txt、version.txt、SHA256SUMS 均校验；三个主要可执行文件均含 arm64/x86_64，minos 11.0。
- manifest 校验通过，DMG release entitlements、嵌套 deep/strict 签名通过。
- 使用实际 vendor installer 安装到隔离目录成功，版本读回 1.48.816、签名通过。注销隔离测试扩展并重新注册 /Applications 原版；未替换日常安装。
- 未执行真实 Sparkle 升级；不以签名校验替代升级验收。
- DMG SHA256: 1176e634598e7c9dd563b6c0454a43b2e00e0dcba915b6dc47680c7c419b0e44。
- MacPorts SHA256: add56d6d00bd781fac0eb7ebb2856e2ed7b765d4524ed567b8501e9e054f4359。
