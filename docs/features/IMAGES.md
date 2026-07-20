# Images: Support, Behavior, and Internals

This document consolidates historical docs about image handling in FluxMarkdown.

Archived originals are kept under `docs/history/images/`.

---

## 1. What is supported

FluxMarkdown primarily supports local images by **reading image files in Swift** and converting them into **Base64 data URLs** passed to the renderer.

### Supported image sources

| Type | Example | Status | Notes |
|---|---|---:|---|
| Relative path (same folder) | `./image.png` | ✅ | Read by Swift, injected as Base64 |
| Relative path (subfolder) | `./images/logo.png` | ✅ | Read by Swift, injected as Base64 |
| Relative path (parent folder) | `../image.png` | ✅ | Read by Swift, injected as Base64 |
| Absolute filesystem path | `/Users/Shared/image.png` | ✅* | Depends on sandbox entitlements |
| `file://` URL | `file:///Users/Shared/image.png` | ✅* | Normalized and treated as a file path |
| Network image (HTTPS) | `https://example.com/img.png` | ✅ | Loaded by WebView |
| Network image (HTTP) | `http://example.com/img.png` | ⚠️ | May be blocked by WebKit security policy |
| Base64 data URL | `data:image/png;base64,...` | ✅ | Extra handling for markdown-it validation / WKWebView |
| Raw HTML image | `<img src="../assets/logo.png" width="160">` | ✅ | Preserves HTML presentation attributes and uses the same local-image pipeline |

\* Absolute paths are constrained by sandbox rules (see “Security & Entitlements”).

---

## 2. Rendering approach (high-level)

1. **Swift** extracts rendered-image references from Markdown image syntax and raw HTML `<img src>` elements.
2. **Swift** attempts to read local image files and builds a map: `originalPath -> data:image/<type>;base64,...`.
3. **Swift** authorizes each exact local image reference for the `local-md://` fallback; this allows an explicit parent-directory image without granting access to the parent directory itself.
4. **Swift** calls the renderer with Markdown text + image map.
5. **Renderer (TS)** replaces image `src` for both Markdown-generated and raw HTML images.
6. Images that exceed the inline size limits fall back to `local-md://` and must match the document's explicit file allowlist.

---

## 3. Behavior / UX when something fails

The project documents three visible outcomes:

1. ✅ Image shows normally
2. ⚠️ A “placeholder” UI appears only after a local image emits a real load error
3. 🚫 Browser broken-image icon appears for unsupported path types (or blocked loads)

Details are preserved in `docs/history/images/IMAGE_DISPLAY_BEHAVIOR.md`.

---

## 4. Base64 images: why special handling exists

Two historical failure points:

1. **markdown-it `validateLink` rejecting some `data:` URLs** (notably `data:image/svg+xml;base64,...` due to `+`)
2. **WKWebView sandbox restrictions around `data:` scheme** depending on how content is loaded

Mitigations that exist in code (see archived docs for details):

- Override markdown-it link validation for `data:`
- Prefer `loadHTMLString(..., baseURL: ...)` in Swift for more permissive behavior
- Rewrite `data:` images to `blob:` URLs in JS where needed

---

## 5. Security & Entitlements

The Quick Look extension is sandboxed.

Example entitlement:

```xml
<key>com.apple.security.temporary-exception.files.absolute-path.read-only</key>
<array>
  <string>$HOME/</string>
</array>
```

This constrains which absolute-path images can be read. The custom scheme handler additionally
requires a path to remain inside the Markdown file's directory or exactly match a local image
reference extracted from the current document. Symlinked image references are not added to the
explicit allowlist.

---

## 6. How to test

### Manual test fixtures

- Main fixture: `Tests/fixtures/images-test.md`
- Supporting assets: `Tests/fixtures/images/`, `Tests/fixtures/test-image.png`, etc.

### Useful logs

```bash
log stream --predicate 'subsystem == "com.markdownquicklook.app"' --level debug
```
