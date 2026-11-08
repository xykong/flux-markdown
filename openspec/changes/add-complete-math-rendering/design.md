# Design

The project design consists of [Issue #64 scope and overall design](../../../docs/design/ISSUE_64_MATH_RENDERING.md) and [implementation-level design](../../../docs/design/ISSUE_64_IMPLEMENTATION_DESIGN.md), maintained under `docs/` per repository conventions. The latter defines the selected configuration, interfaces, label/ID adapter, session state machine, sanitizer/export contracts and six implementation batches.

It records the complete attachment inventory, the exact 13-item math corpus, the old reference site's limitations, the MathJax 4.1.3 Node/native WebKit experiments, the engine decision and alternatives, parser/state/sanitizer/export integration, independent oracles, performance gates and rollout order.

Key decision: use MathJax 4.1.3 at document scope, SVG with local glyph caching, assistive MathML and no speech/Explorer Worker. Do not fall back between engines expression by expression. Keep original Markdown token boundaries and local asset loading. The production modular bundle, minimum-OS APIs, actual VoiceOver and memory gates still require implementation acceptance.

Key integration risks demonstrated by the research: unresolved references do not throw, browser SVG links use runtime-only metadata, combined components load Worker/data-font resources, and one source expression can produce multiple SVGs. None may be judged solely by nonempty DOM or absence of JavaScript exceptions.

Further design probes demonstrate default label-ID collisions (`a b` / `a_b`), inherited-key false duplicates (`constructor`), glyph/container loss through existing sanitizer profiles and font requests beginning after layout. These have explicit adapter and readiness requirements. Independent XeTeX/amsmath labels and a visually reviewed reference PDF now complement same-engine probes.
