# Change: 完善长文阅读与图表工作流

## Why
用户已确认缩放手感并明确要求实施上一轮提出的五项体验改进，同时完成端到端验证。现有图表交互缺少专注查看/导出，跳转缺少返回，原始 scrollY 在内容与布局变化后不稳定。

## What Changes
- 短暂的文档/图表倍率反馈，补全六种界面的手势说明。
- Mermaid / 独立 SVG 的图表专注面板：适应窗口、局部 100%、连续缩放/平移、关闭回到原位置。
- 前进/后退记录目录、脚注和本地 Markdown 链接跳转，恢复阅读位置与文档倍率。
- 按文件保存有界的段落锚点与倍率，保留旧 scrollY 回退；重渲染和重开文档恢复。
- 图表复制 PNG 与保存 PNG/SVG，经过原生校验、真实剪贴板/文件写入回读；失败复用 ErrorIncident / ErrorFeedback。

## Impact
- Affected specs: reading-workflow（新增）；沿用 improve-document-reading、add-url-position-navigation、add-error-feedback 的实现。
- Affected code: renderer reading/diagram modules, App/QuickLook bridge, shared native reading store, help/localization, integration probes。
- 用户已授权上述五项建议的实施；本提案记录实现与验收细节，不重复请求同一范围授权。正式版本发布不在本轮授权范围。
