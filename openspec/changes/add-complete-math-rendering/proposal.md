# Change: Complete mathematical rendering and equation references

## Why

Issue #64 supplies a mixed Markdown corpus whose valid math includes parenthesis/bracket delimiters, math fences, labelled equations and cross references. The current renderer renders six TeX items, leaves three input forms as text/code, and fails on label/eqref. Its existing MathML and native/export integration also need explicit acceptance criteria.

## What Changes

- Recognize mathematics in Markdown tokens and preserve non-math source boundaries.
- Introduce a document-scoped, locally bundled MathJax 4 path for TeX and supported MathML, with AMS numbering, reference resolution and isolated state.
- Adapt math output to the shared sanitizer, navigation, accessibility, error feedback, settings and export lifecycle.
- Freeze the issue corpus and independent semantic/visual/host/performance acceptance criteria.
- **Behavior change:** valid additional math forms render as math; mathematical typesetting appearance changes. Preserve the persisted math toggle and existing Typst/Mermaid dependency boundaries.

## Impact

- Affected specs: new `math-rendering` capability; implementation must preserve existing rendering, feedback and export contracts.
- Affected code (proposed): `web-renderer/src/index.ts`, new math syntax/renderer modules, `safe-html.ts`, `error-feedback.ts`, `export-readiness.ts`, math/RTL/print CSS, bundle configuration, native setting labels and integration tests.
- Investigation, implementation design and scope: [design](../../../docs/design/ISSUE_64_MATH_RENDERING.md).
- User-facing rewritten implementation task: [requirements](../../../docs/design/ISSUE_64_TASK_REQUIREMENTS.md).
- Original inputs and isolated engine experiments are included. Product rendering code is not changed by this proposal.

## Review Status

Draft for review. The user requested comprehensive analysis, an implementation design and a rewritten task; this proposal does not record approval to implement it.
