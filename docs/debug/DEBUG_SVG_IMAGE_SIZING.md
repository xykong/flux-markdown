# Referenced SVG diagram sizing

2026-11-08 follow-up to document-reading changes. The reported Markdown embeds `mode-selection.svg` as an image, not a Mermaid code fence. Its root is `width="100%"`, has no absolute height, and contains `viewBox="4 4 586.5 1088"`, `max-width:586.5px`, and 16px diagram labels. The existing Mermaid layout only visits `.mermaid svg`; it cannot reach SVG loaded through `<img>`. Image CSS only caps width at the document width, allowing the scalable image to expand far beyond its drawing coordinates on a wide screen.

Acceptance before implementation:
- A synthetic SVG with the same percentage width, viewBox and font geometry must stay <=586.5 CSS pixels at wide document widths, shrink to narrow containers, preserve aspect ratio and keep 16px labels <=16px body text.
- The actual user-provided SVG is used locally for real WebKit acceptance without copying private documentation into this repository.
- Respect smaller explicit image sizes (icons); leave raster images alone. Handle base64 and percent-encoded SVG, malformed input and absent geometry safely.
- Keep SVG in image isolation: inspect only inert XML metadata; never mount untrusted SVG/style/scripts into the document and never add network fetches for measurement.
- Export retains the sizing constraint and app/Quick Look share the same behavior. Font changes must retain the cap.

## Evidence and implementation
The pre-fix installed renderer reproduced the issue with the original local SVG: at a 1800px document width the image measured **1723px**, almost three times its 586.5-unit drawing width. The same assertion passes after applying the new image constraint.

The renderer inspects bounded, inert SVG data-URL XML for viewBox, absolute width and inline maximum width. It retains an image-level maximum of the drawing/native width and available document width; SVG text metadata adds an em-based cap so smaller body-font settings also shrink labels. Smaller explicit HTML image sizes remain intact. No SVG DOM/style is injected into the page, no extra fetch is introduced, and raster images are unchanged. Non-inlined SVGs use browser-decoded intrinsic width as a fallback. This is deliberately conservative metadata analysis, not a general SVG CSS/transform interpreter.

Verification: TypeScript and production Vite build pass; 66 Jest suites / 600 tests pass. The actual source SVG passes native WebKit sizing assertions in app, Quick Look and Finder contexts at 360/1800px widths, with preserved aspect ratio, 96px icon sizing, font-size changes and export caps. The synthetic regression contains no private source material; `FLUX_SVG_SIZING_FIXTURE` optionally supplies a local file to the test harness. The user's Markdown and SVG files remain unchanged.

The existing local Xcode 27 build uses `LOCAL_DEPLOYMENT_TARGET=12.0`; the product's macOS 11 deployment setting is unchanged. Full SVG source styles with nested transformations, outlined glyphs or unavailable external CSS cannot be exactly inferred from metadata; no-upscale intrinsic bounds still apply where geometry is available. This fix targets referenced SVG images, not a new inline-SVG rendering engine.

## Visual acceptance caught a second intrinsic-size issue
The first constraint-only implementation passed upper-bound tests but showed the chart too small in the installed app. A new regression measured WebKit's default intrinsic SVG viewport as **80 × 150** when percentage width had no absolute height. Merely setting max-width cannot enlarge that default viewport to the intended drawing size. The final fix also normalizes the isolated SVG image's root width/height to the drawing aspect ratio; the source file is untouched. Tests now assert both natural dimensions and a readable lower width bound, not just the maximum. This prevents replacing an oversized chart with an unreadable thumbnail.

## Native bridge coverage
Installed-app inspection also exposed a bridge difference: Quick Look already sends image data, while the host and CLI exporter previously supplied only local-scheme URLs. They now use the existing bounded collector's SVG-only filter so metadata and normalized intrinsic dimensions reach the shared renderer. Raster images keep the existing scheme. The native collector regression verifies SVG inclusion, raster exclusion and alias handling; the real WebKit fixture now passes through this collector rather than constructing data directly. Existing resource count/byte budgets still apply before filtering.

Final local acceptance: native collector suite passes all 12 tests; the final SVG bridge fixture passes real WebKit. The renderer's full 35-case WebKit suite and 600 Jest tests pass. Installed `1.46.779-dev-20261108-204901`, reopened the user's original document and visually inspected the actual chart: node labels are readable and smaller than the surrounding table text, and the drawing is neither stretched nor reduced to the 80×150 fallback thumbnail. Recent-document history and default editor associations are preserved. No private diagram/document or screenshot is committed.
