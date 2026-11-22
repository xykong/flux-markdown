# 图表工具栏按钮被拉高

2026-11-18，用户提供实际截图：减号、百分比、加号和专注按钮呈竖长矩形，“更多”按钮高度不同。基线 `46de1c9` / `1.51.834-dev-reading3`。

## 预先验收条件

- 图表工具栏的图标按钮和更多入口均为28×28 CSS像素，百分比按钮同高且按内容加宽；不同文档倍率下屏幕尺寸不变。
- Mermaid、独立SVG、App/Quick Look、正文/专注层、浅深主题均保持一致；更多菜单展开不改变工具栏高度。
- 真实WebKit测量，并在安装App前台实际截图复核。保留现有缩放、导出和专注交互。

## 调查

新增的更多入口使用 details/summary。正文 Markdown 样式给 details 底部外边距，flex 默认 stretch 把同一行其他按钮拉高；专注层的通用 button 样式还会覆盖图表小按钮。修复将图表控件几何与文档排版、专注层动作按钮隔离。

## 验证结果

- 修复前新增真实WebKit用例测得控件高46px（50%文档倍率下仍被拉高），明确失败：`/tmp/flux-toolbar-red.log`。
- 修复后图标/更多入口28×28，百分比按钮高28且最小宽48。固定 border-box、居中与不拉伸，清除 details 的正文外边距；专注层通用动作样式只作用于专注工具栏，不覆盖图表小控件。
- App/Quick Look、Mermaid/引用SVG、浅深主题、50%/100%/150%/300%文档倍率和菜单展开/收起矩阵通过，专注层也通过。Apple Silicon全部10项阅读WebKit回归通过；Intel新增几何用例通过：`/tmp/flux-toolbar-{arm,intel}.log`。
- 全量Jest：634项、70套通过；TypeScript/Vite及Debug App构建通过。未修改Swift逻辑或正式部署目标。
- 安装本地 `1.51.834-dev-reading4`；实际前台复核正文、更多菜单、专注层，控件紧凑同高。截图：[正文](evidence/diagram-toolbar/normal.png)、[展开菜单](evidence/diagram-toolbar/menu-open.png)、[专注层](evidence/diagram-toolbar/focus.png)。
- 先前安装版保留在 `~/Library/Application Support/FluxMarkdown/Install Backups/20261118-110127/FluxMarkdown.app`；保持编辑器关联，签名与安装资源摘要再次校验。
