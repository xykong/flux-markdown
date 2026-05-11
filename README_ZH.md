# FluxMarkdown

<p align="center">
  <em>在 macOS Finder 中按空格即可预览精美的 Markdown</em><br>
  Mermaid • KaTeX • GFM • 目录 • 图表 • 导出
</p>

<p align="center">
  <a href="https://github.com/xykong/flux-markdown/stargazers">
    <img src="https://img.shields.io/github/stars/xykong/flux-markdown?style=social" alt="GitHub stars">
  </a>
  <a href="https://github.com/xykong/flux-markdown/releases">
    <img src="https://img.shields.io/github/v/release/xykong/flux-markdown?style=flat-square" alt="最新版本">
  </a>
  <a href="https://github.com/xykong/flux-markdown/releases">
    <img src="https://img.shields.io/github/downloads/xykong/flux-markdown/total?style=flat-square" alt="下载量">
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/github/license/xykong/flux-markdown?style=flat-square" alt="开源协议">
  </a>
</p>

<p align="center">
  <a href="README.md">English</a> •
  <a href="README_ES.md">Español</a> •
  <a href="README_ZH.md">中文文档</a> •
  <a href="#-快速安装30-秒">安装</a> •
  <a href="#️-常见问题">常见问题</a>
</p>

---

## ✨ 演示

![FluxMarkdown 演示](docs/assets/demo.gif)

<p align="center">
  <strong>在 Finder 中选中文件按 <code>空格</code> → 立即预览图表、公式等内容。</strong>
</p>

<p align="center">
  <em>👋 如果 FluxMarkdown 对你有帮助，请考虑给它一个</em>
  <a href="https://github.com/xykong/flux-markdown/stargazers">⭐ GitHub Star</a>！
</p>

---

## 🚀 快速安装（30 秒）

### Homebrew（推荐）

```bash
brew install --cask xykong/tap/flux-markdown
```

### 手动安装（DMG）

1. 从 [Releases](https://github.com/xykong/flux-markdown/releases) 下载最新的 `FluxMarkdown.dmg`
2. 打开 DMG
3. 将 **FluxMarkdown.app** 拖入 **Applications（应用程序）**

---

## 💡 为什么选择 FluxMarkdown？

| 功能 | 说明 |
|------|------|
| 📊 **Mermaid 图表** | 架构图、流程图、时序图等 |
| 🧮 **KaTeX 数学公式** | 行内和块级数学表达式 |
| 📝 **GFM 支持** | 表格、任务列表、删除线及 GitHub 警示 |
| 🎨 **Code 高亮** | 支持 40 多种语言的语法高亮 |
| 📊 **图表与图形** | 支持 Vega, Vega-Lite 和 Graphviz (DOT) |
| 📑 **目录面板** | 交互式目录，自动跟踪当前章节 |
| 📄 **YAML 元数据** | 自动解析 Frontmatter 并以表格展示 |
| 📤 **导出选项** | 支持导出为 PDF (Cmd+Shift+P) 或 HTML (Cmd+Shift+E) |
| 🔍 **缩放与平移** | Cmd +/-/0、Cmd+滚轮、触控板捏合 |
| 💾 **位置记忆** | 记忆每个文件的滚动位置及最后查看的文件 |
| 🌓 **主题** | 亮色、暗色、跟随系统 |
| 📂 **文件格式** | 支持 .md, .mdx, .rmd, .qmd, .mdoc, .mkd, .mkdn, .mkdown |

---

## ⚙️ 设置 (Cmd+,)

FluxMarkdown 提供专用的设置窗口，方便你自定义预览体验：

- **外观**: 在亮色、暗色或跟随系统主题之间切换。
- **渲染**: 开启或关闭 Mermaid、KaTeX 或 Emoji 支持。
- **编辑器**: 调节基础字体大小，并选择不同的代码高亮主题（GitHub, Monokai, Atom One Dark 等）。

---

## ⌨️ 快捷键

| 快捷键 | 动作 |
|--------|------|
| `Space` | 在 Finder 中打开 QuickLook 预览 |
| `Cmd` + `+` / `-` / `0` | 放大 / 缩小 / 重置缩放 |
| `Cmd` + `Shift` + `E` | 导出为 HTML |
| `Cmd` + `Shift` + `P` | 导出为 PDF |
| `Cmd` + `,` | 打开设置 |

---

## 🛠️ 常见问题

<details>
<summary><strong>"应用已损坏" / "无法验证开发者"</strong></summary>

在终端运行：
```bash
xattr -cr "/Applications/FluxMarkdown.app"
```
</details>

<details>
<summary><strong>QuickLook 不显示更新</strong></summary>

重置 QuickLook 缓存：
```bash
qlmanage -r
```
</details>

<details>
<summary><strong>预览完全不工作</strong></summary>

1. 检查应用是否在 `/Applications/` 目录
2. 尝试重启 Finder：`killall Finder`
3. 检查 `pluginkit -m -v` 查看活动的 QuickLook 扩展
</details>

**📚 更多帮助：** 参见 [`docs/user/TROUBLESHOOTING.md`](docs/user/TROUBLESHOOTING.md) 和 [`docs/user/AUTO_UPDATE.md`](docs/user/AUTO_UPDATE.md)

**📖 文档索引：** [`docs/README.md`](docs/README.md)

---

## 对比（QuickLook Markdown 插件）

| 功能 | FluxMarkdown | [QLMarkdown](https://github.com/sbarex/QLMarkdown) | [qlmarkdown](https://github.com/whomwah/qlmarkdown) | [PreviewMarkdown](https://github.com/smittytone/PreviewMarkdown) |
| --- | --- | --- | --- | --- |
| 安装方式 | brew cask / DMG | brew cask / DMG | 手动安装 | App Store / DMG |
| Mermaid | 支持 | 支持（[来源](https://github.com/sbarex/QLMarkdown/blob/main/README.md#mermaid-diagrams)） | 未提及 | 未提及 |
| KaTeX/数学公式 | 支持 | 支持（[来源](https://github.com/sbarex/QLMarkdown/blob/main/README.md#mathematical-expressions)） | 未提及 | 未提及 |
| GFM / 警示 | 支持 | 支持（cmark-gfm；[来源](https://github.com/sbarex/QLMarkdown/releases/tag/1.0.18)） | 部分支持（Discount；[来源](https://github.com/whomwah/qlmarkdown#introduction)） | 未提及 |
| 目录（TOC） | 支持 | 未提及 | 不支持 | 未提及 |
| 图表 (Vega / DOT) | 支持 | 未提及 | 不支持 | 不支持 |
| 导出 (PDF / HTML) | 支持 | 不支持 | 不支持 | 不支持 |
| YAML 元数据 | 支持 | 支持 | 不支持 | 不支持 |
| 主题 | 亮/暗/跟随系统 | CSS（[来源](https://github.com/sbarex/QLMarkdown/blob/main/README.md#extensions)） | 未提及 | 基础调节（[来源](https://github.com/smittytone/PreviewMarkdown#adjusting-the-preview)） |
| 缩放 | 支持 | 未提及 | 不支持 | 未提及 |
| 滚动位置记忆 | 支持 | 未提及 | 不支持 | 未提及 |

> 注：对比表基于上述项目公开 README/Release 内容；如果对方未公开说明，则标为“未提及”。

---

## 从源码构建

```bash
git clone https://github.com/xykong/flux-markdown.git
cd flux-markdown
make install
```

## 📄 开源协议

**FluxMarkdown 采用双许可证模式：**

### 开源许可证：GPL-3.0
- ✅ **免费**用于个人、教育和开源项目
- ✅ 任何修改必须以 GPL-3.0 开源
- 📜 完整条款见 [`LICENSE`](LICENSE)

### 商业许可证
- 💼 **闭源**或商业产品需要商业许可证
- 💼 允许分发而无需开源您的修改
- 📧 联系方式：**xy.kong@gmail.com** 咨询商业授权
- 📜 详情见 [`LICENSE.COMMERCIAL`](LICENSE.COMMERCIAL)

**为什么采用双许可证？** 这确保了 FluxMarkdown 对社区保持免费和开源，同时也为需要闭源使用的商业用户提供了选择。

---

<p align="center">
  <sub>本项目受 <a href="https://github.com/shd101wyy/markdown-preview-enhanced">markdown-preview-enhanced</a> 启发，并使用了其部分内容</sub>
</p>
