## 1. Proposal
- [x] 1.1 Inspect Quick Look monitoring, rendering, toolbar and preview limits.
- [x] 1.2 Define scope, architecture and measurable acceptance.

## 2. Tests
- [x] 2.1 Renderer tests for follow state and selection deferral; native tests for changed-file detection, replacement and bounded snapshots.
- [x] 2.2 Renderer tests for safe suffix replacement and nonlocal Markdown effects.
- [x] 2.3 Native failure and interval policy tests; renderer cancellation, pending-copy and document-switch tests.
- [ ] 2.4 Native fault injection for repeated partial writes and trailing-write delivery.

## 3. Implementation
- [x] 3.1 Localized, accessible toolbar control and explicit Quick Look capability.
- [x] 3.2 Bounded refresh coordination, lifecycle cleanup and contextual recovery.
- [x] 3.3 Semantic comparison, retained-node lifecycle and full-render fallback.
- [x] 3.4 Bottom tracking, pause and resume, anchor preservation and selection-safe updates.

## 4. Verification
- [x] 4.1 Renderer, typecheck, build, native and real-WebKit checks pass.
- [x] 4.2 Copy buttons and copying selected text work through repeated updates.
- [ ] 4.3 Finder (repeat on the integration candidate): final content under stress, size limit, source reset, access recovery, scroll pause and resume.
- [ ] 4.4 Compact preview, other formats and app-window checks.
- [ ] 4.5 Latency and memory targets; accessibility checks.
