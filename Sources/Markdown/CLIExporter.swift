import AppKit
import WebKit
import os.log

final class CLIAppDelegate: NSObject, NSApplicationDelegate {
    private var exporter: CLIExporter?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        guard let idx = args.firstIndex(of: "--export-pdf"), idx + 1 < args.count else {
            fputs("Usage: FluxMarkdown --export-pdf <input.md> [output.pdf]\n", stderr)
            CLIErrorGuidance.printReport(); exit(1)
        }

        let inputPath  = args[idx + 1]
        let outputPath = args.count > idx + 2 ? args[idx + 2] : nil
        let inputURL   = URL(fileURLWithPath: inputPath).standardizedFileURL

        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            fputs("Error: file not found: \(inputURL.path)\n", stderr)
            CLIErrorGuidance.printReport(); exit(1)
        }

        let outputURL: URL
        if let op = outputPath {
            outputURL = URL(fileURLWithPath: op).standardizedFileURL
        } else {
            outputURL = inputURL.deletingPathExtension().appendingPathExtension("pdf")
        }

        exporter = CLIExporter(input: inputURL, output: outputURL)
        exporter?.run()
    }
}

final class CLIExporter: NSObject {

    private let inputURL:  URL
    private let outputURL: URL
    private let logger = OSLog(subsystem: "com.markdownquicklook.app", category: "CLIExporter")

    private var webView: WKWebView!
    private var offscreenWindow: NSWindow!
    private var rendererReady = false
    private var deadline: DispatchWorkItem?
    private var rendererBundleSchemeHandler: RendererBundleSchemeHandler?

    init(input: URL, output: URL) {
        self.inputURL  = input
        self.outputURL = output
    }

    func run() {
        let timeout = DispatchWorkItem { fputs("Error: PDF export timed out\n", stderr); CLIErrorGuidance.printReport(); exit(1) }
        deadline = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: timeout)
        setupWebView()
        loadRenderer()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        let ucc    = WKUserContentController()
        ucc.add(self, name: "logger")

        let debugScript = WKUserScript(source: """
            window.onerror = function(msg, url, line) {
                window.webkit.messageHandlers.logger.postMessage("JS Error: " + msg + " at " + line);
            };
            """, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        ucc.addUserScript(debugScript)

        config.userContentController = ucc

        let handler = LocalSchemeHandler()
        handler.baseDirectory = inputURL.deletingLastPathComponent()
        if let data = try? BoundedFileReader.read(inputURL, maxBytes: BoundedFileReader.documentLimit),
           let content = String(data: data, encoding: .utf8) {
            handler.allowedFileURLs = MarkdownImageDataCollector.referencedLocalImageURLs(
                from: inputURL,
                content: content
            )
        }
        config.setURLSchemeHandler(handler, forURLScheme: "local-md")

        if let rendererHandler = RendererBundleSchemeHandler(bundle: .main) {
            config.setURLSchemeHandler(rendererHandler, forURLScheme: RendererBundleSchemeHandler.scheme)
            rendererBundleSchemeHandler = rendererHandler
        }


        // A4 width in points; height is a reasonable viewport for rendering
        let renderWidth: CGFloat  = 595.28
        let renderHeight: CGFloat = 1200

        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: renderWidth, height: renderHeight),
                            configuration: config)
        webView.appearance = NSAppearance(named: .aqua)
        webView.navigationDelegate = self

        offscreenWindow = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: renderWidth, height: renderHeight),
            styleMask:   [.borderless],
            backing:     .buffered,
            defer:       false
        )
        offscreenWindow.isOpaque = false
        offscreenWindow.contentView = webView
        offscreenWindow.orderBack(nil)
    }

    private func loadRenderer() {
        guard rendererBundleSchemeHandler != nil else {
            fputs("Error: index.html not found in bundle\n", stderr)
            CLIErrorGuidance.printReport(); exit(1)
        }
        let url = RendererBundleSchemeHandler.rendererURL()
        fputs("Loading renderer from: \(url.absoluteString)\n", stderr)
        webView.load(URLRequest(url: url))
    }

    private func renderAndExport() {
        let content: String
        var truncated = false
        do {
            if inputURL.pathExtension.lowercased() == "tsv" {
                let preview = try PreviewFileReader.read(inputURL)
                content = preview.content
                truncated = preview.isTruncated
            } else {
                let data = try BoundedFileReader.read(inputURL, maxBytes: BoundedFileReader.documentLimit)
                guard let text = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
                content = text
            }
        } catch {
            fputs("Error: cannot read input\n", stderr)
            CLIErrorGuidance.printReport(); exit(1)
        }

        guard let contentData = try? JSONSerialization.data(withJSONObject: [content]),
              let jsonArray   = String(data: contentData, encoding: .utf8) else {
            fputs("Error: cannot encode content\n", stderr)
            CLIErrorGuidance.printReport(); exit(1)
        }
        let safeArg = String(jsonArray.dropFirst().dropLast())

        let fontSize = AppearancePreference.shared.baseFontSize
        var options: [String: Any] = [
            "context":            "app",
            "baseUrl":            inputURL.deletingLastPathComponent().path,
            "theme":              "light",
            "fontSize":           fontSize,
            "codeHighlightTheme": "default",
            "enableMermaid":      true,
            "enableKatex":        true,
            "enableEmoji":        true,
            "enableTypst":        true,
            "uiLanguage":         "en",
        ]
        if inputURL.pathExtension.lowercased() == "tsv" {
            options["format"] = "tsv"
            options["isTruncated"] = truncated
        } else {
            options["imageData"] = MarkdownImageDataCollector.collectImageData(
                from: inputURL, content: content, fileExtensions: ["svg"])
        }
        guard let optData = try? JSONSerialization.data(withJSONObject: options),
              let optJson  = String(data: optData, encoding: .utf8) else {
            fputs("Error: cannot encode options\n", stderr)
            CLIErrorGuidance.printReport(); exit(1)
        }

        let js = "await window.renderMarkdown(\(safeArg), \(optJson)); await window.waitForExportReady();"
        webView.callAsyncJavaScript(js, arguments: [:], in: nil, in: .page) { [weak self] result in
            if case .failure(let error) = result {
                fputs("Error: export rendering failed: \(error.localizedDescription)\n", stderr)
                CLIErrorGuidance.printReport(); exit(1)
            }
            self?.capturePDF()
        }
    }

    private func capturePDF() {
        fputs("Capturing PDF via NSPrintOperation…\n", stderr)

        let fontSize = AppearancePreference.shared.baseFontSize
        let injectJS = "document.documentElement.style.setProperty('--print-font-size', '\(fontSize)px');"
        webView.evaluateJavaScript(injectJS) { [weak self] _, _ in
            self?.runPrintOperation()
        }
    }

    private func runPrintOperation() {
        let a4PaperSize = NSSize(width: 595.0, height: 842.0)
        let printInfo = NSPrintInfo()
        printInfo.paperSize = a4PaperSize
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.topMargin    = 0
        printInfo.bottomMargin = 0
        printInfo.leftMargin   = 0
        printInfo.rightMargin  = 0
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered   = false
        printInfo.jobDisposition = .save
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = outputURL

        offscreenWindow.setContentSize(a4PaperSize)
        webView.frame = NSRect(origin: .zero, size: a4PaperSize)

        let printOperation = webView.printOperation(with: printInfo)
        printOperation.showsPrintPanel    = false
        printOperation.showsProgressPanel = false
        printOperation.view?.frame = NSRect(origin: .zero, size: a4PaperSize)

        let capturedOutputURL = outputURL
        DispatchQueue.global(qos: .userInitiated).async {
            let success = printOperation.run()
            DispatchQueue.main.async {
                if success && FileManager.default.fileExists(atPath: capturedOutputURL.path) {
                    print("✅ PDF exported to: \(capturedOutputURL.path)")
                    exit(0)
                } else {
                    fputs("Error: PDF file not created at \(capturedOutputURL.path)\n", stderr)
                    CLIErrorGuidance.printReport(); exit(1)
                }
            }
        }
    }
}

extension CLIExporter: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        fputs("CLIExporter: webView didFinish navigation\n", stderr)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        defer { CLIErrorGuidance.printReport(); exit(1) }
        fputs("CLIExporter: webView didFail: \(error.localizedDescription)\n", stderr)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation nav: WKNavigation!, withError error: Error) {
        defer { CLIErrorGuidance.printReport(); exit(1) }
        fputs("CLIExporter: didFailProvisional: \(error.localizedDescription)\n", stderr)
    }
}

extension CLIExporter: WKScriptMessageHandler {
    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard RendererBridgePolicy.accepts(message) else { return }
        guard message.name == "logger", let body = message.body as? String else { return }
        os_log("CLIExporter JS: %{public}@", log: logger, type: .debug, body)

        if body == "rendererReady" && !rendererReady {
            rendererReady = true
            renderAndExport()
        }
    }
}

private enum CLIErrorGuidance {
    static func printReport() {
        let incident = ErrorIncident(kind: .exportPDF, source: .cli, environment: DiagnosticEnvironment.current())
        fputs("Try a readable UTF-8 Markdown file and a writable output folder.\n", stderr)
        fputs("Report this problem (review before publishing): \(incident.feedbackURL().absoluteString)\n", stderr)
        fputs("Safe diagnostic summary (no document content or paths):\n\(incident.report)\n", stderr)
    }
}
