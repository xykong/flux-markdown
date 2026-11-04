# Design

The authoritative project design is [Issue #64 math rendering](../../../docs/design/ISSUE_64_MATH_RENDERING.md), maintained under `docs/` per repository conventions.

It records the complete attachment inventory, the exact 13-item math corpus, the old reference site's limitations, the MathJax 4.1.3 Node/native WebKit experiments, the engine decision and alternatives, parser/state/sanitizer/export integration, independent oracles, performance gates and rollout order.

Key decision: use one document-level math engine for TeX semantics; do not fall back between engines expression by expression. Keep original Markdown token boundaries and local asset loading. Select the exact module/output/accessibility configuration after the first native offline/performance phase.

Key integration risks demonstrated by the research: unresolved references do not throw, browser SVG links use runtime-only metadata, combined components load Worker/data-font resources, and one source expression can produce multiple SVGs. None may be judged solely by nonempty DOM or absence of JavaScript exceptions.
