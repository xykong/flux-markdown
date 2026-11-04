# Issue 64 production end-to-end checks

Run from the repository with installed renderer dependencies, Xcode command-line tools and a macOS desktop session:

```sh
scripts/test-issue64-math.sh
```

The command verifies every original attachment file against its recorded hash, runs the renderer tests/build and complete native WebKit suite, and executes the unmodified corpus with real math/diagram engines. It derives a valid mathematical document by removing only the intentional unknown-command line and including the original MathML. It verifies matrix/cases structure, Chinese text, reference targets, failed-export rejection and recovery.

It then saves the production export, opens it in a fresh WebKit process with scripts/network/fonts blocked by CSP, and checks formula geometry, auxiliary semantics, links and absence of application controls/resource violations. Evidence and logs are retained in the printed temporary directory; failure prints that path for diagnosis.

The build emits Vite's module manifest. The runner verifies every declared module/import/resource exists inside the bundle and the mathematical license notices match their sources, then imports all 40 upstream SVG dynamic glyph modules through the production scheme handler in a fresh WebKit process. A disposable copy with its double-struck glyph chunk removed must fail both static verification and native imports. This proves executable resource closure on the current platform; it does not assert visual correctness for every glyph or minimum-system compatibility.

Image-backed MathML (`mglyph`, nested SVG `image`, HTML `img`) is outside the mathematical output profile. The runner verifies source-preserving errors, export rejection and subsequent-document recovery, with no sentinel bundle-resource requests. A separate loopback HTTP control proves ordinary images can load while these mathematical images produce zero HTTP requests. The local server serves only a fixed test SVG and shuts down after the probe. Ordinary document and diagram image policies remain separate.

The mathematical layout matrix uses actual WKWebView widths of 320/600/960 points, native pageZoom 1/2 and native Aqua/Dark Aqua appearance, with LTR/RTL containing blocks across app/quicklook/finder renderer contexts (72 combinations). It checks all original valid math plus a wide display, local overflow, copy-control geometry, reference targets and inherited text/link colors. Native appearance and page zoom are essential: changing renderer theme/zoom variables alone is not the host contract. The trusted keyboard case also scrolls an oversized inline formula with Right Arrow. Run native UI checks serially; concurrent app probes can disturb focus-dependent checks. The research probe accepts optional width/zoom/theme/snapshot environment variables; defaults remain unchanged.

Against that damaged copy, `resource-failure.js` checks the actual renderer in all six languages and app/quicklook/finder rendering contexts: preserved source and following content, failed-export rejection, recovery on the next valid document, named feedback actions, incident identity, allowlisted diagnostic fields and detached-control rejection. An opt-in Swift message receiver records the real WK bridge delivery and acknowledges barriers without background timer polling. It never executes recovery or opens/submits feedback. Context options are not proof that the system selected the new QuickLook extension, and synthetic action activation is not a native keyboard/VoiceOver acceptance test.

`report.json` describes only the checks actually performed. It explicitly lists the remaining actual host UI, minimum-platform, VoiceOver, PDF visual, memory and human-review gates. This runner does not install or replace FluxMarkdown, send feedback, change file associations or declare the full feature accepted. The native suite briefly uses its own window and isolated test pasteboard, restoring the prior foreground application afterward.

Do not edit the immutable original fixture to make an expectation pass. Document the line-132 parenthesis-escape/math ambiguity separately from the dedicated 13-item corpus; the full original currently has 14 mathematical items including that ambiguous example and the one intentional error.

After building the actual native application, validate its CLI export separately:

```sh
scripts/test-issue64-product-export.sh /path/to/FluxMarkdown.app /tmp/new-issue64-export-evidence
```

The output directory must be new. This checks the app signature, all manifest-declared renderer resources against the current build, mathematical resource/license closure, actual valid and invalid CLI exports, and the two-page PDF's internal equation-reference destination using PDFKit. Render and visually inspect both pages afterward; the script explicitly does not claim visual or PDF-viewer/VoiceOver acceptance. It neither installs the app nor changes the selected QuickLook provider.

For whole-renderer developer comparison:

```sh
scripts/build-issue64-math-backend.sh current /tmp/new-current-math-profile
scripts/build-issue64-math-backend.sh legacy /tmp/new-legacy-math-profile
```

Each creates an isolated `bundle` and `profile.json`. Current mode uses the working renderer and records dirty state; legacy mode archives the pinned v1.42.645 renderer/configuration and uses its unchanged lockfile. Dependencies for the current workspace must already be installed. Invalid profiles, existing destinations and destinations inside renderer sources are rejected. The legacy profile has the old syntax limitations and is for controlled comparison, not issue-64 feature acceptance or installation into a differently versioned app.

Use the existing native research probe with `backend-profile.js` and the generated `profile.json`. The smoke fixture deliberately distinguishes the profiles: current yields three MathJax outputs; legacy yields one KaTeX output and retains the math fence as code. Full feature acceptance still uses the current production runner above.

The complete runner clears `FLUX_WEBKIT_CASE_FILTER` for its native suite; use the separate native script for focused debugging. Interactive cases require an unlocked graphical session and wait for `document.hasFocus()` before checking keyboard-dependent behavior. Missing focus fails explicitly as an environment condition; it is not silently skipped or counted as a passing UI check.
