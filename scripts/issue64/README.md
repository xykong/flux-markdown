# Issue 64 production end-to-end checks

Run from the repository with installed renderer dependencies, Xcode command-line tools and a macOS desktop session:

```sh
scripts/test-issue64-math.sh
```

The command verifies every original attachment file against its recorded hash, runs the renderer tests/build and complete native WebKit suite, and executes the unmodified corpus with real math/diagram engines. It derives a valid mathematical document by removing only the intentional unknown-command line and including the original MathML. It verifies matrix/cases structure, Chinese text, reference targets, failed-export rejection and recovery.

It then saves the production export, opens it in a fresh WebKit process with scripts/network/fonts blocked by CSP, and checks formula geometry, auxiliary semantics, links and absence of application controls/resource violations. Evidence and logs are retained in the printed temporary directory; failure prints that path for diagnosis.

The build emits Vite's module manifest. The runner verifies every declared module/import/resource exists inside the bundle and the mathematical license notices match their sources, then imports all 40 upstream SVG dynamic glyph modules through the production scheme handler in a fresh WebKit process. A disposable copy with its double-struck glyph chunk removed must fail both static verification and native imports. This proves executable resource closure on the current platform; it does not assert visual correctness for every glyph or minimum-system compatibility.

`report.json` describes only the checks actually performed. It explicitly lists the remaining actual host UI, minimum-platform, VoiceOver, PDF visual, memory and human-review gates. This runner does not install or replace FluxMarkdown, send feedback, change file associations or declare the full feature accepted. The native suite briefly uses its own window and isolated test pasteboard, restoring the prior foreground application afterward.

Do not edit the immutable original fixture to make an expectation pass. Document the line-132 parenthesis-escape/math ambiguity separately from the dedicated 13-item corpus; the full original currently has 14 mathematical items including that ambiguous example and the one intentional error.
