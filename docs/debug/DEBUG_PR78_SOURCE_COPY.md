# PR #78 源码选区复制

在 PR 提交 `683045c` 上，本机 WKWebView 复现了三个问题。CRLF 文件每行之间多出一个空行。以 `first\nremoved\nlast\n` 为旧内容渲染 `first\nlast\n` 时，复制丢失末尾换行，清除差异标记后已删除的行还占一个空行。全选截断的 TSV 时，提示文字会接到首行数据。

验收覆盖 Markdown 原生复制、原有两种 Quick Look 复制操作、LF 和 CRLF 的行结构、差异标记清除前后、TSV 原生复制、渲染视图和搜索框。

Markdown 源码行进入 diff 前将 CRLF 和单独 CR 统一为 LF，使 HTML 解析与复制拼接只生成一份行分隔符。源码 diff 补上末尾换行所对应的空行。选区提取根据当前文件行号排除已删除行。纯文本事件拦截仅用于 Markdown 源码行容器，TSV 交由系统处理。

`npm test -- --runInBand` 通过 80 套件、775 项。生产 renderer 构建与针对源码复制的真实 WKWebView 用例通过，覆盖上述边界、两种 Quick Look 复制格式的剪贴板读回、搜索输入及渲染视图。
