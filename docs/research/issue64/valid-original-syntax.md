# Issue 64 数学验收语料

原附件有效数学样例；故意错误样例单独验证。

<math xmlns="http://www.w3.org/1998/Math/MathML"><mrow><msup><mi>x</mi><mn>2</mn></msup><mo>+</mo><msup><mi>y</mi><mn>2</mn></msup><mo>=</mo><msup><mi>z</mi><mn>2</mn></msup></mrow></math>

## 10 · 数学公式（扩展）

行内美元分隔：$E = mc^2$；中文混排：当 $x > 0$ 时，$\sqrt{x^2} = x$。

行内圆括号分隔：\(a^2 + b^2 = c^2\)。

美元块级分隔：

$$
\int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}
$$

方括号块级分隔：

\[
\sum_{k=1}^{n} k = \frac{n(n+1)}{2}
\]

对齐、分式、上下标与文字：

$$
\begin{aligned}
f(x) &= \frac{x^2 + 1}{x - 1} \\
\lim_{n\to\infty}\left(1+\frac{1}{n}\right)^n &= e \\
P(A\mid B) &= \frac{P(B\mid A)P(A)}{P(B)} \quad \text{条件概率}
\end{aligned}
$$

矩阵与分段函数：

$$
A = \begin{bmatrix}1 & 2 \\ 3 & 4\end{bmatrix},\qquad
g(x) = \begin{cases}x^2, & x \ge 0 \\ -x, & x < 0\end{cases}
$$

带标签的公式（编号与交叉引用取决于公式引擎）：

$$
a^2 + b^2 = c^2 \tag{1}\label{eq:pythagoras}
$$

公式引用候选：$\eqref{eq:pythagoras}$。

数学代码块形式：

```math
\nabla \cdot \mathbf{E} = \frac{\rho}{\varepsilon_0}
```

货币与转义美元测试：价格为 \$5.00 和 \$10.00。代码中的美元：`$HOME`。

