## Context
TSV requires native registration and a dedicated bounded renderer; Markdown table parsing cannot interpret it.

## Decisions
The authoritative implementation design and acceptance matrix are in [TSV_PREVIEW.md](../../../../docs/design/TSV_PREVIEW.md). Reuse existing WebView, bounded reader and error feedback; explicitly select TSV format without content sniffing. Render literal fields safely, keep the first record as data, and cap bytes, rows, columns and cells.

## Risks / Trade-offs
Literal TSV intentionally excludes quoted multiline dialects. UTF-8 is the initial supported encoding. Truncation must not misrepresent partial records or exported previews. Native and renderer state must stay consistent across reused views.

## Migration Plan
Add TSV registration without claiming default editor ownership. Existing Markdown registration and rendering remain unchanged; no user-data migration is needed.
