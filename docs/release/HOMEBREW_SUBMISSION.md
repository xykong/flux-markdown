# Homebrew 官方库提交与维护指南

## 双轨策略

| 版本 | 文件 | 安装方式 | 特性 |
|------|------|----------|------|
| **功能版（tap）** | `../homebrew-tap/Casks/flux-markdown.rb` | `brew install --cask xykong/tap/flux-markdown` | duti 默认关联、auto_updates、Sparkle livecheck |
| **官方版草稿** | `../homebrew-tap/Drafts/flux-markdown-official.rb` | 提交到 homebrew/homebrew-cask 后：`brew install --cask flux-markdown` | 符合官方规范，无 formula 依赖 |

---

## 首次提交到官方库

### 前提条件

- `gh` CLI 已安装且已登录（`gh auth status`）
- 当前版本已 release 并已运行 `update-homebrew-cask.sh`
- `./scripts/submit-to-homebrew.sh` 会复制草稿到官方 tap 路径后执行 `brew style`

### 提交

```bash
./scripts/submit-to-homebrew.sh
```

脚本自动完成：Fork → clone → sync upstream → 新分支 → 复制 cask → style 检查 → 提交 → 创建 PR。

---

## 后续版本更新

### 每次 release 时（已自动化）

`update-homebrew-cask.sh` 会同时更新两个文件：

```bash
./scripts/update-homebrew-cask.sh
```

### 官方库版本更新

**推荐：依赖 Homebrew Bot**

PR 合并后，Homebrew 的 `BrewTestBot` 会自动通过 livecheck 检测新版本并提 PR。
只需 approve 即可（Comment `@BrewTestBot approved`）。

**备用：手动提 PR**

```bash
VERSION="<NEW_VERSION>"
SHA256=$(shasum -a 256 build/artifacts/FluxMarkdown.dmg | awk '{print $1}')

cd ~/your-fork/homebrew-cask
git fetch upstream && git merge upstream/master
git checkout -b "bump-flux-markdown-${VERSION}"

sed -i '' "s/version \".*\"/version \"${VERSION}\"/" Casks/f/flux-markdown.rb
sed -i '' "s/sha256 \".*\"/sha256 \"${SHA256}\"/" Casks/f/flux-markdown.rb

brew style Casks/f/flux-markdown.rb

git add Casks/f/flux-markdown.rb
git commit -m "flux-markdown ${VERSION}"
gh pr create --repo Homebrew/homebrew-cask --title "flux-markdown ${VERSION}" --body "Version bump."
```

---

## 两版本差异说明

| 字段 | 功能版（tap） | 官方版 |
|------|-------------|--------|
| `auto_updates` | ✅ `true` | ❌ 官方不允许 |
| `depends_on formula: "duti"` | ✅ | ❌ 官方禁止 cask 依赖 formula |
| duti postflight | ✅ 设置默认文件关联 | ❌ 已移除 |
| livecheck | Sparkle + appcast.xml | GitHub Latest |
| caveats | 含默认 app 设置说明 | 仅 QuickLook 故障排除 |

---

## 常见问题

**Q: 官方 PR 审核要求？**

常见审核意见：
- postflight 中的 `system_command` 需要在 PR 描述中说明必要性（`submit-to-homebrew.sh` 已包含完整说明）
- 可能被要求添加 `brew test` 用例

**Q: 官方合并后与 tap 版如何共存？**

完全兼容。用户可以选择：
- `brew install --cask flux-markdown` — 官方版（精简）
- `brew install --cask xykong/tap/flux-markdown` — tap 版（完整功能）

从官方版切换到 tap 版：
```bash
brew uninstall --cask flux-markdown
brew install --cask xykong/tap/flux-markdown
```
