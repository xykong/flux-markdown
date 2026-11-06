# Release Process

本文档记录完整的版本发布流程，包括 PR 处理、CHANGELOG 生成和 Homebrew 分发。

## 概述

发布流程分为五个阶段：
1. **PR 合并前**: 收集和记录变更
2. **版本发布**: 自动化构建和发布
3. **发布后**: 更新 Homebrew Cask 和验证
4. **发布宣传图与最终验收**: 制作、压缩、上传庆祝图，将其放在 Release Notes 顶部并验证公开下载。完成后再宣布发布结束或回复 Issue。
5. **Issue 跟进**: 回复相关 Issue，说明版本、更新方式及需要的复测。

**每次正式发布必须包含本版庆祝宣传图。** `make release` / `publish-release.sh`
目前只处理程序包、更新源和 Homebrew，不会自动生成宣传图；脚本成功不代表全部发布流程完成。
按下文「庆祝宣传图」完成图片和页面检查，不得因为是修复版本而省略。

---

## 阶段 1: PR 合并前的处理

### 1.1 PR Review 和分析

当收到 PR 时，需要：

1. **获取 PR 元数据**:
   ```bash
   gh pr view <PR_NUMBER> --json title,body,author,number
   ```

2. **分析代码变更**:
   ```bash
   # 查看 PR 的所有提交
   gh pr view <PR_NUMBER> --json commits
   
   # 查看具体的代码变更
   git log --oneline <BASE_COMMIT>..<PR_COMMIT>
   git show <PR_COMMIT> --stat
   git show <PR_COMMIT>
   ```

3. **提取 PR 信息**:
   - PR 编号
   - PR 标题
   - PR 作者 GitHub 用户名
   - PR 描述
   - 修改的文件和行数
   - 具体的代码变更

### 1.2 生成 CHANGELOG 条目

基于 PR 分析，生成符合格式的 CHANGELOG 条目：

**格式模板**:
```markdown
### [Added|Fixed|Changed|Removed]
- **[Scope]**: [简短描述]。（感谢 [@username](https://github.com/username) 的贡献 [#PR_NUMBER](https://github.com/xykong/flux-markdown/pull/PR_NUMBER)）
  - [技术实现细节 1]
  - [技术实现细节 2]
  - [技术实现细节 3]
```

**示例**:
```markdown
### Fixed
- **QuickLook**: 修复双击 Markdown 文件时意外触发"使用默认应用打开"的问题。（感谢 [@sxmad](https://github.com/sxmad) 的贡献 [#2](https://github.com/xykong/flux-markdown/pull/2)）
  - 通过自定义 `InteractiveWebView` 子类拦截鼠标事件，防止事件冒泡到 QuickLook 宿主。
  - 添加 `NSClickGestureRecognizer` 拦截双击手势，确保 WebView 内的交互（如文本选择）不受影响。
  - 实现 `acceptsFirstMouse(for:)` 方法，允许 WebView 直接响应首次点击事件。
```

### 1.3 更新 CHANGELOG

**重要**: PR 合并后，立即将生成的条目添加到 `CHANGELOG.md` 的 `## [Unreleased]` 部分：

```bash
# 编辑 CHANGELOG.md，在 [Unreleased] 下添加新条目
vim CHANGELOG.md

# 提交更新
git add CHANGELOG.md
git commit -m "docs(changelog): add PR #<NUMBER> to unreleased section"
git push origin master
```

---

## 阶段 2: 版本发布

### 2.1 执行发布命令

使用 `make release` 命令发布新版本：

```bash
# Patch 版本 (1.2.69 -> 1.2.70)
make release patch

# Minor 版本 (1.2.69 -> 1.3.70)
make release minor

# Major 版本 (1.2.69 -> 2.0.70)
make release major
```

### 2.2 发布脚本自动执行的步骤

`scripts/release.sh` 会自动执行：

1. **更新版本号**:
   - 读取 `.version` 文件
   - 根据 bump 类型更新 major/minor
   - 计算新的完整版本号（base_version.commit_count）

2. **提取发布说明**:
   - 从 `CHANGELOG.md` 的 `[Unreleased]` 部分提取内容
   - 过滤掉内部变更（架构、构建、测试等）
   - 生成 `release_notes_tmp.md`

3. **更新 CHANGELOG**:
   - 将 `[Unreleased]` 替换为新版本号和日期
   - 保留空的 `[Unreleased]` 部分供下次使用

4. **提交和打标签**:
   ```bash
   git add .version CHANGELOG.md
   git commit -m "chore(release): bump version to <VERSION>"
   git tag "v<VERSION>"
   git push origin master
   git push origin "v<VERSION>"
   ```

5. **构建 DMG**:
   - 构建 TypeScript 渲染器
   - 生成 Xcode 项目
   - 编译 macOS 应用
   - 创建 DMG 安装包

6. **创建 GitHub Release**:
   ```bash
gh release create "v<VERSION>" build/artifacts/FluxMarkdown.dmg \
     --title "v<VERSION>" \
     --notes-file release_notes_tmp.md
   ```

### 2.3 验证发布

检查以下内容：

- [ ] GitHub Release 已创建: https://github.com/xykong/flux-markdown/releases/tag/v<VERSION>
- [ ] DMG 文件已上传
- [ ] Release Notes 包含所有 PR 的感谢信息
- [ ] Git tag 已推送
- [ ] CHANGELOG.md 已更新
- [ ] 已完成下文庆祝宣传图流程：本版文案、压缩 WebP、公开资源校验、Release Notes 顶部展示

---

## 阶段 3: 发布后的 Homebrew 更新

### 3.1 计算 DMG 的 SHA256

```bash
shasum -a 256 build/artifacts/FluxMarkdown.dmg
```

输出示例：
```
ca72b7201410962f0f5d272149b2405a5d191a8e692d9526f23ecad3882cd306  build/artifacts/FluxMarkdown.dmg
```

### 3.2 更新 Homebrew Cask

编辑 `../homebrew-tap/Casks/flux-markdown.rb`：

```ruby
cask 'flux-markdown' do
  version '1.3.73'  # 更新版本号
  sha256 'ca72b7201410962f0f5d272149b2405a5d191a8e692d9526f23ecad3882cd306'  # 更新 SHA256
  
  # ... 其余内容保持不变
end
```

### 3.3 提交和推送 Homebrew Cask

```bash
cd ../homebrew-tap
git add Casks/flux-markdown.rb
git commit -m "chore(cask): update flux-markdown to v<VERSION>"
git push origin master
```

### 3.4 验证 Homebrew 安装

```bash
# 更新本地 tap
brew update

# 升级应用
brew upgrade flux-markdown

# 或全新安装测试
brew install --cask flux-markdown
```

---

## 完整示例: v1.3.73 发布流程

### 实际执行的命令和输出

```bash
# 1. 分析合并的 PR #2
$ gh pr view 2 --json title,body,author
{
  "author": {"login": "sxmad", "name": "asdfq"},
  "body": "Use NSClickGestureRecognizer to intercept double-click events.",
  "title": "fix double click"
}

$ git show 790e41b --stat
commit 790e41bddc3abfdc0c2ea45702aed24d37424e22
Author: xiaoxin.sun <xiaoxin.sun@happyelements.com>
Date:   Tue Jan 13 12:25:58 2026 +0800

    fix double click

 Sources/MarkdownPreview/PreviewViewController.swift | 31 +++++++++++++++++++---
 1 file changed, 28 insertions(+), 3 deletions(-)

# 2. 手动添加到 CHANGELOG.md [Unreleased] 部分
# （本次因为漏掉了这步，所以发布后需要回填）

# 3. 执行 minor 版本发布
$ make release minor
🚀 Bumping Minor Version: 1.2 -> 1.3
🎯 Target Version: 1.3.73
✅ DMG created successfully at: build/artifacts/FluxMarkdown.dmg
🎉 Successfully released v1.3.73!

# 4. 回填 CHANGELOG（修正漏掉的步骤）
$ vim CHANGELOG.md  # 添加 PR #2 的详细说明和感谢
$ git add CHANGELOG.md
$ git commit -m "docs(changelog): backfill v1.3.73 release notes with PR #2 fix"
$ git push origin master

# 5. 更新 GitHub Release
$ gh release edit v1.3.73 --notes-file /tmp/release_notes_v1.3.73_updated.md

# 6. 计算 SHA256
$ shasum -a 256 build/artifacts/FluxMarkdown.dmg
ca72b7201410962f0f5d272149b2405a5d191a8e692d9526f23ecad3882cd306

# 7. 更新 Homebrew Cask
$ cd ../homebrew-tap
$ vim Casks/flux-markdown.rb  # 更新 version 和 sha256
$ git add Casks/flux-markdown.rb
$ git commit -m "chore(cask): update flux-markdown to v1.3.73"
$ git push origin master

# 8. 验证
$ brew upgrade flux-markdown
```

---

## 自动化改进建议

### 短期改进（手动执行，规范流程）

**创建 PR 合并后的 Checklist**:

```bash
# scripts/pr-merged-checklist.sh
#!/bin/bash

PR_NUMBER=$1
if [ -z "$PR_NUMBER" ]; then
    echo "Usage: $0 <PR_NUMBER>"
    exit 1
fi

echo "✅ PR #$PR_NUMBER Merged - Post-Merge Checklist"
echo ""
echo "1. 分析 PR 内容："
echo "   gh pr view $PR_NUMBER --json title,body,author,commits"
echo ""
echo "2. 查看代码变更："
echo "   gh pr diff $PR_NUMBER"
echo ""
echo "3. 生成 CHANGELOG 条目（手动）："
echo "   - 确定类型: Added/Fixed/Changed/Removed"
echo "   - 确定范围: QuickLook/渲染器/构建系统等"
echo "   - 提取作者信息和 PR 链接"
echo ""
echo "4. 更新 CHANGELOG.md [Unreleased] 部分"
echo "   vim CHANGELOG.md"
echo ""
echo "5. 提交更新："
echo "   git add CHANGELOG.md"
echo "   git commit -m 'docs(changelog): add PR #$PR_NUMBER to unreleased section'"
echo "   git push origin master"
```

### 中期改进（脚本辅助）

**创建 PR 分析和 CHANGELOG 生成脚本**:

```bash
# scripts/analyze-pr.sh
#!/bin/bash
set -e

PR_NUMBER=$1
if [ -z "$PR_NUMBER" ]; then
    echo "Usage: $0 <PR_NUMBER>"
    exit 1
fi

echo "📊 Analyzing PR #$PR_NUMBER..."

# 获取 PR 信息
PR_INFO=$(gh pr view $PR_NUMBER --json title,body,author,files)
PR_TITLE=$(echo "$PR_INFO" | jq -r '.title')
PR_AUTHOR=$(echo "$PR_INFO" | jq -r '.author.login')
PR_BODY=$(echo "$PR_INFO" | jq -r '.body')

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PR #$PR_NUMBER: $PR_TITLE"
echo "Author: @$PR_AUTHOR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Description:"
echo "$PR_BODY"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 获取修改的文件
echo "Modified Files:"
gh pr view $PR_NUMBER --json files --jq '.files[].path'
echo ""

# 查看 diff
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Code Changes:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
gh pr diff $PR_NUMBER

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Suggested CHANGELOG Entry:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "### [TODO: Category]"
echo "- **[TODO: Scope]**: $PR_TITLE。（感谢 [@$PR_AUTHOR](https://github.com/$PR_AUTHOR) 的贡献 [#$PR_NUMBER](https://github.com/xykong/flux-markdown/pull/$PR_NUMBER)）"
echo "  - [TODO: 技术实现细节 1]"
echo "  - [TODO: 技术实现细节 2]"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  请根据以上信息手动完善 CHANGELOG 条目，然后："
echo "    1. 编辑 CHANGELOG.md"
echo "    2. git add CHANGELOG.md"
echo "    3. git commit -m 'docs(changelog): add PR #$PR_NUMBER to unreleased section'"
echo "    4. git push origin master"
```

### 长期改进（完全自动化）

使用 AI 辅助或 GitHub Actions 自动化：

1. **PR 合并时自动生成 CHANGELOG 草稿**:
   - GitHub Action 监听 PR merge 事件
   - 使用 GPT API 分析代码变更
   - 自动生成 CHANGELOG 条目并创建 commit

2. **发布时自动更新 Homebrew Cask**:
   - 在 `scripts/release.sh` 末尾添加 Homebrew 更新逻辑
   - 自动计算 SHA256
   - 自动提交到 homebrew-tap 仓库

---

## 常见问题

### Q1: 发布后发现遗漏了 PR 的 CHANGELOG 怎么办？

**回填流程**（如 v1.3.73）:

1. 分析遗漏的 PR
2. 编辑 CHANGELOG.md，在对应版本下添加条目
3. 提交: `git commit -m "docs(changelog): backfill v<VERSION> with PR #<NUMBER>"`
4. 更新 GitHub Release: `gh release edit v<VERSION> --notes-file <new_notes.md>`
5. 推送: `git push origin master`

### Q2: 如何判断 PR 属于哪个类型（Added/Fixed/Changed）？

- **Added**: 全新功能或特性
- **Fixed**: Bug 修复
- **Changed**: 现有功能的改进或重构
- **Removed**: 删除的功能
- **Deprecated**: 即将废弃的功能

### Q3: 如何确定 CHANGELOG 的 Scope？

根据修改的文件路径：
- `Sources/MarkdownPreview/` → **QuickLook** 或 **Extension**
- `Sources/Markdown/` → **App** 或 **Host App**
- `web-renderer/` → **渲染器 (Renderer)** 或 **预览 (Preview)**
- `Makefile`, `project.yml`, `scripts/` → **构建系统 (Build)**
- `docs/` → **文档 (Documentation)**

### Q4: 什么样的变更不应该出现在 Release Notes 中？

根据 `scripts/release.sh` 的过滤逻辑，以下类型会被过滤：
- 架构 (Architecture)
- 内部 (Internal)
- 构建 (Build)
- 测试 (Test)
- CI
- Refactor（除非影响用户体验）

这些变更保留在 CHANGELOG.md 中，但不出现在 GitHub Release 的发布说明中。

---

## 阶段 4: 庆祝宣传图与最终验收（必做）

此流程承接会话 `01a1a600-87b4-7700-8932-bdde596e02f6` 最后确认的
v1.43.755 优化方案：专业且有庆祝氛围的宣传图，**不能直接嵌入数 MB 的原始 PNG**。
参考产物为该版 Release 顶部的 `celebration-v2.webp`（1200×800，129,950 字节）。

### 4.1 制作本版图片

- 先确定本版真实用户价值，检查版本号和发布说明。不要沿用上版功能文案；修复版也需要庆祝图，但不能宣称尚未验证的全面修复、性能提升或安全认证。
- 延续专业发布视觉：深靛蓝/蓝紫背景、金色烟花/丝带/彩屑、玻璃与金属 Markdown 文档主体、清晰的文字层级和留白。庆祝元素不得遮挡文字；不要退化成过于素净的单个图标。
- 图片只保留产品名、完整版本号、简短主题文案；不塞入完整 changelog、错误码或小字。
- 沿用指定会话的 `animal-mediakit generate image`、`gpt-image-2.5-flare`、1536×1024、high 质量生成路径。若该工具/模型不可用，应明确记录替代方案，不能假称仍使用同一模型。
- 将最终 prompt 保存到 `docs/release/artwork/v<VERSION>-prompt.txt`。原始图和生成日志保存在 ignored 的 `build/release-artwork-<VERSION>/`，不将原始 PNG 或原始服务响应提交到仓库。

示例（版本号读取 `.version`，不手写 build number）：

```sh
version=$(cat .version)
artwork_dir="build/release-artwork-$version"
mkdir -p "$artwork_dir"
animal-mediakit --json generate image "$(cat "docs/release/artwork/v$version-prompt.txt")" \
  --model gpt-image-2.5-flare --size 1536x1024 --quality high --output-format png \
  -o "$artwork_dir/original.png" > "$artwork_dir/generate.json"
```

### 4.2 压缩和视觉验收

1. 查看原始图，确认文字拼写、版本号、主题、构图及庆祝氛围。
2. 按比例缩到 **1200×800**，转换为 WebP，再压缩（质量 80–85 起步）。
3. 目标 **100–200 KB**，通常不超过 **250 KB**；超过时继续优化，或在发布记录明确说明保留更大尺寸的必要性。
4. **必须重新查看最终压缩图**，检查小尺寸下的文字清晰度、边缘和压缩伪影。工具成功或文件体积合格不能代替视觉检查。

```sh
animal-mediakit image resize "$artwork_dir/original.png" \
  --width 1200 --height 800 -o "$artwork_dir/resized.png"
animal-mediakit image convert "$artwork_dir/resized.png" \
  --format webp -o "$artwork_dir/converted.webp"
animal-mediakit image compress "$artwork_dir/converted.webp" --quality 82 \
  -o "$artwork_dir/flux-markdown-v$version-celebration.webp"
```

### 4.3 上传、插入和回读验证

- 上传最终 WebP 到**对应版本 GitHub Release assets**。第一次采用
  `flux-markdown-v<VERSION>-celebration.webp`；迭代采用 `-v2.webp` 等新文件名，避免缓存和覆盖旧文件。
- 先用 `gh release view --json body,assets` 读取当前线上内容，再把图片 Markdown 放在 Release Notes 顶部。只新增或替换该宣传图引用，保留全部原有发布说明。使用 `--notes-file`，不要在 shell 中拼接转义正文。
- 使用公开的 `https://github.com/xykong/flux-markdown/releases/download/v<VERSION>/<ASSET>` URL 和描述性 alt text，不使用本地路径、私有 URL 或生成服务临时 URL。
- **不要修改已绑定 release-manifest 的 `release_notes_tmp.md` 来补图**，也不要重建/覆盖已发布的 DMG 或修改 appcast。用独立 notes 文件更新 GitHub 正文，保留原始发布清单可验证性。
- 回读 Release：图片引用位于正文顶部，版本和 asset 名正确；原有正文完整。
- 从公开 URL 下载图片，与本地 WebP 做字节比较并核对 SHA-256、MIME、尺寸、大小。检查发布页实际渲染；若浏览器不可用，记录这一限制，并至少确认远端 Markdown、资源下载和本地最终图均正确。
- 在 `docs/release/RELEASE_<VERSION>.md` 记录模型、可用的 trace ID、prompt 路径、图片链接、尺寸/字节数/SHA-256、视觉审查与远端校验结果，提交并推送。二进制图作为 Release asset 保存，工作区保留最终副本。

### 4.4 最终发布门禁

- [ ] 正式包、签名、双架构/最低系统版本、GitHub/Sparkle/Homebrew 渠道已核验。
- [ ] 本版庆祝图已生成、压缩、肉眼检查并上传；公开下载一致。
- [ ] Release Notes 顶部显示本版图片，原有说明保留；不直接嵌入原始 PNG。
- [ ] 发布记录已提交；需要的 Issue 回复已发出并回读。

未完成上述检查，不要将发布标记为全部完成。补图不需要重新发版或改版本号。

---

## 阶段 5: Issue 回复规范

### 5.1 核心原则

| 规则 | 说明 |
|------|------|
| **语言匹配** | **永远用 issue 的语言回复**。英文 issue → 英文回复；中文 issue → 中文回复。无需询问。 |
| **不关闭 issue** | 只添加 `done` 标签 + 回复。由 issue 作者决定是否关闭。 |
| **不重复打开** | 若 issue 被误关闭，先 reopen，再补标签和回复。 |

### 5.2 已修复 Issue 的处理流程

```bash
# 1. 确认修复已包含在已发布版本中
git tag --contains <fix-commit>  # 确认 tag 存在
gh release view v<VERSION>       # 确认 release 已发布

# 2. 添加 done 标签
gh issue edit <NUMBER> --add-label "done"

# 3. 用 issue 的语言回复（英文或中文，见模板）
gh issue comment <NUMBER> --body "..."

# 禁止执行:
# gh issue close <NUMBER>
```

### 5.3 回复模板

**英文 issue**:
```
Fixed in [vX.Y.Z](https://github.com/xykong/flux-markdown/releases/tag/vX.Y.Z).

**What changed:**
- [specific fix relevant to this issue]

**To update:**
\`\`\`bash
brew update && brew upgrade --cask flux-markdown
\`\`\`
Or download the DMG from the [Releases page](https://github.com/xykong/flux-markdown/releases/tag/vX.Y.Z).
```

**中文 issue**:
```
已在 [vX.Y.Z](https://github.com/xykong/flux-markdown/releases/tag/vX.Y.Z) 中修复。

**修复内容：**
- [与此 issue 相关的具体修复]

**更新方式：**
\`\`\`bash
brew update && brew upgrade --cask flux-markdown
\`\`\`
或从 [Releases 页面](https://github.com/xykong/flux-markdown/releases/tag/vX.Y.Z) 直接下载 DMG。
```

---

## 参考资料

- [Keep a Changelog](https://keepachangelog.com/)
- [Semantic Versioning](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub CLI Manual](https://cli.github.com/manual/)

## Building when the local Xcode no longer supports macOS 11

Use `RELEASE_REMOTE_BUILD=1 make release minor` to build the tagged commit with
`.github/workflows/release-build.yml` (Xcode 16.4 on macos-15), retaining the macOS
11 deployment target and both arm64/x86_64 architectures. The downloader verifies
the workflow SHA, bundled provenance/version, archive checksum, nested signatures
and all three product deployment targets before locally packaging the DMG.
`RELEASE_APP_PATH` is only for an already verified matching-version bundle; DMG
creation rejects version mismatch. Sparkle signing continues to use the local
Keychain. Do not override the deployment target to publish with a newer Xcode.

To validate the final versioned payload before publication, run:

```bash
RELEASE_REMOTE_BUILD=1 RELEASE_PREPARE_ONLY=1 make release minor
# Verify the final package and Homebrew upgrade, then:
./scripts/publish-release.sh
```

Preparation writes `build/artifacts/release-manifest.json`, binding the release tag,
DMG, MacPorts source archive and release notes to their SHA-256 values. Publication
refuses changed/missing artifacts and does not bump the version a second time.

## Recovering interrupted preparation and publication

`./scripts/release.sh --resume` reuses the version/tag and preserved release notes after a failed build. It verifies the tag's version and ancestry before rebuilding; it does not bump again. Initial preparation requires a clean tracked worktree on master and rejects an existing target tag before changing version files.

`./scripts/publish-release.sh` verifies the prepared manifest and entitlements and generates the signed appcast before creating a release. If the release already exists, it downloads and byte-compares each asset; mismatches fail instead of replacing published artifacts. Notes remain available because the manifest and retries require them.

Each stage records progress in `build/artifacts/publication-status.txt`. A Sparkle push or Homebrew error exits unsuccessfully and names the failed stage. Rerun publication after resolving it; it verifies the existing release and retries channel updates. This is resumable publication, not an atomic transaction across services. The GitHub release may already be public when a later channel fails.

The Homebrew updater returns status 2 when cask changes are prepared but not committed/pushed. In non-interactive use, complete that explicit tap publication step and rerun; unchanged cask files are compared with the fetched tap remote before reporting completion.
