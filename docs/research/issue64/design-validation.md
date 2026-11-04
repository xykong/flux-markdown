# Issue #64 详细设计验证

日期：2026-11-04。此报告验证设计选择和已知接入风险，不宣称生产渲染器已实现新能力。

## 1. 环境和方法

- Apple M5 Max，128 GiB，arm64，macOS 27.0.1 (26A434)；真实 WKWebView，960×900。
- MathJax 4.1.3；SVG 与 CHTML 使用相同的 assistive MathML 配置，关闭语音/盲文/Explorer，禁止 Worker；脚本、字体数据和允许字体均从本地 scheme 加载。
- 每种输出 20 次新进程/nonPersistent WebKit 启动；每种 13/100/1000 项负载先预热 5 次再测 30 次。未清空操作系统文件缓存，因此是进程冷启动，不是重启机器后的磁盘冷启动。
- 13 项为原始数学语料（12 有效、1 故意无效）；100/1000 项为固定分式/根号/上下标压力语料。每次测量后核对数学项数和预期错误数，防止丢公式换来“性能提升”。
- 排版计时包含输出后的布局和所需字体就绪。初版只等待 fonts.ready 会遗漏布局后启动的字体；另一次实验使用 setTimeout 让不可见 WKWebView 出现约 1 秒的定时器节流。两种数据均未作为最终基线。最终脚本强制布局、等待字体、再次布局并检查 loading 状态，不使用该定时器。
- p50/p95 采用 nearest-rank。进程启动时间、引擎初始化时间与首次数学处理分别保存，不能相互混称。CPU 长任务、WebContent RSS、最旧系统与真实宿主开销尚未测量。

## 2. 最终比较

| 指标 | SVG | CHTML |
| --- | ---: | ---: |
| 引擎初始化 p95 (ms) | 80 | 77 |
| 首次原文数学排版 p95 (ms) | 36 | 60 |
| 新进程到结果 p95 (ms) | 250.01 | 285.74 |
| 13 项暖态 p50 / p95 (ms) | 7 / 9 | 7 / 9 |
| 100 项暖态 p50 / p95 (ms) | 37 / 43 | 35 / 40 |
| 1000 项暖态 p50 / p95 (ms) | 416 / 442 | 396 / 413 |
| 首次原文实际本地资产请求合计 (bytes) | 1854448 | 1115986 |
| 1000 项序列化 DOM (bytes) | 6675198 | 2787810 |
| 原文辅助 MathML / 数学项 | 13 / 13 | 13 / 13 |

SVG 比 CHTML 的输出 DOM 更大；本方案为离线/自足输出选择 SVG，并显式控制 DOM 和内存预算。两者本次均能用标准 href 和辅助 MathML完成，选型不建立在某个引擎无法排版这些公式的假设上。

字体状态与资产请求证明 CHTML 会加载 NewCM WOFF2 文件。SVG 中普通数学符号是路径，中文 text 仍使用系统文本字体；不能承诺 SVG 完全没有字体相关的就绪工作。

## 3. 实际发现与设计约束

| 实验 | 实际结果 | 设计处理 |
| --- | --- | --- |
| 未编号 label / 失败目标 | 标签留在表中但 tag 是 ???、id 为空 | 根据有效目标图核对，不能只看 labels 中有键 |
| `a b` 与 `a_b` | 默认都得到 `mjx-eqn:a_b` | 用精确标签字节编码和独立命名空间 |
| `constructor` | 默认被当作已有标签 | AMS adapter 使用无原型 label 字典并测试保留键 |
| 显式 tag 1 后自动编号 | 自动编号仍为 1 | 区分视觉编号与唯一身份，不自创计数规则 |
| `tag*{B}` | tag/ref 为 B，eqref 为 (B) | 独立 TeX 参照核对这一语义 |
| 新会话宏 | A 定义 newcommand 后正常，独立 B 中未定义 | 每次新建语义状态；模块缓存与宏缓存分开 |
| 当前 document sanitizer | 13 个 mjx 容器全失，152 个 use 全失 | 专用 math profile 和清理后完整性检查 |
| 当前 diagram sanitizer | 保留 152 个 use，但 mjx 容器全失 | 不能直接借 diagram profile 宣告适配完成 |
| 显式 assistive-MathML profile | 13 个辅助 MathML，标准 href，无 Worker/CSP拒绝 | 选定默认辅助语义；实际朗读仍待验收 |

原始观测见 `contract-results.json`、`sanitizer-results.json`、`design-comparison.json`。研究脚本中的失败是特意记录的上游/当前接入边界，不是已经修好的产品行为。

## 4. 独立参照

原先计划的 LuaLaTeX 路线在本机没有现成运行时。本轮采用独立于 MathJax 的 Tectonic 0.17.0（XeTeX）+ amsmath，使用同一 LaTeX 数学源码验证标签/编号与布局；不需要改变全局 TeX 安装。这个工具选择替换的是参照引擎实现，不改变被验收的数学语义。

- 版本、下载地址、二进制归档 hash、LaTeX/amsmath/fontspec 版本、系统中文字体 hash、输入/PDF hash 均记录于 `oracle/manifest.json`。
- 两遍编译得到五个预先定义的标签值：原文 1、前向 A、自动 1、align 行 2、tag-star B；与手写期望一致。
- 另一个只生成辅助记录的两遍编译验证 `a b`、`a_b`、`constructor`、`__proto__`、`toString` 分别得到 A/B/C/D/E。它们是独立 TeX 引擎接受的标签，进一步证实需要修正 MathJax 默认身份边界。
- 缓存资源离线复跑成功；无 undefined-reference、缺字或 overfull/underfull 警告。系统 Songti 字体依赖被明确记录；不同环境更换字体时不要求像素相等。
- 两页最终 PDF 经 Poppler 渲染并逐页检查：分式、上下限、三行对齐、中文、2×2 矩阵、两行 cases、编号/引用均清晰，无裁切或重叠。
- 原文 M13 直接按 MathML XML 验证三个平方项 x/y/z 和 +、=；没有把其结构检查混算成 TeX 编译通过。
- M12 是无效控制组，不加入成功编译 PDF。它的错误恢复仍是产品实现验收要求。
- 把参照辅助记录中的原文编号故意改成 99 时，独立校验脚本按预期失败；没有通过更新期望掩盖错误。

参照只确立独立期望，尚未将最终产品截图/PDF与它逐项比较；真实 VoiceOver/PDF链接能力也不能从参考 PDF 推断。

## 5. 复现

```sh
# 输出选择、冷暖性能、原生本地资源、边界语义（临时目录保留结果）
scripts/research/issue64-math/compare.sh

# 对指定目录中的两遍 TeX 编译结果做独立标签/日志检查
python3 scripts/research/issue64-math/verify-oracle.py /path/to/oracle-output

# 原有引擎语料研究，输出 semantic-output.html
scripts/research/issue64-math/run.sh

# 使用生产 safe-html.ts，检查该真实引擎 HTML 经当前清理后的结构
node scripts/research/issue64-math/sanitize-probe.cjs "$PWD" /path/to/semantic-output.html
```

TeX 参照源码为 `oracle/reference.tex`，在记录的字体环境下用固定 Tectonic 运行：

```sh
tectonic --keep-intermediates --keep-logs --reruns 1 --outdir /path/to/oracle-output docs/research/issue64/oracle/reference.tex
tectonic --outfmt aux --keep-intermediates --keep-logs --reruns 1 --outdir /path/to/oracle-output docs/research/issue64/oracle/identities.tex
# 缓存就绪后以同样命令加 --only-cached 验证离线重建
```

运行时生成的时间戳可能使 PDF 字节 hash 变化；语义、标签值、页面数与视觉内容才是比较依据。源码、引擎和依赖版本仍必须记录。

## 6. 门槛和未完成项

当前参考机的详细预算已写入 `ISSUE_64_IMPLEMENTATION_DESIGN.md`：首次数学 p95 150ms、100 项 150ms、1000 项 2000ms，首次运行资产 3MiB、1000 项 DOM 10MiB。它们是实施后的验收门槛；当前独立原型达到这些局部指标，不证明完整 App/QuickLook 达到。

发布前仍必须完成：人工独立审阅期望、生产模块化 bundle 的资源闭包、最旧 macOS/Safari 14 和 Intel、WebContent RSS/长任务、真实三个宿主、VoiceOver/键盘、明暗/窄屏/缩放、标准链接及 HTML/PDF 导出、generation 故障注入、原始完整附件回归。缺项不得用本报告的原型数据替代。
