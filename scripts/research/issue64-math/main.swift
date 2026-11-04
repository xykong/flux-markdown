import AppKit
import WebKit
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
final class ProbeSchemeHandler: NSObject, WKURLSchemeHandler {
    let base: RendererBundleSchemeHandler
    init(root: URL) { base = RendererBundleSchemeHandler(rootDirectory: root) }
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        if task.request.url?.lastPathComponent == "issue64-forbidden-math-glyph.svg" {
            fputs("FORBIDDEN_MATH_RESOURCE_REQUEST\n", stderr)
        }
        base.webView(webView, start: task)
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) { base.webView(webView, stop: task) }
}
final class Probe: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    var view: WKWebView!
    var hostWindow: NSWindow?
    let script = try! String(contentsOfFile: CommandLine.arguments[3], encoding: .utf8)
    let source = try! String(contentsOfFile: CommandLine.arguments[4], encoding: .utf8)
    func start() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.userContentController.add(self, name: "trace")
        if ProcessInfo.processInfo.environment["FLUX_MATH_PROBE_FEEDBACK_RECORDING"] == "1" {
            config.userContentController.add(self, name: "errorFeedback")
        }
        config.userContentController.addUserScript(WKUserScript(source: "window.addEventListener('error',e=>window.webkit.messageHandlers.trace.postMessage(String(e.message)));window.addEventListener('securitypolicyviolation',e=>window.webkit.messageHandlers.trace.postMessage('CSP '+e.blockedURI+' '+e.violatedDirective));window.addEventListener('unhandledrejection',e=>window.webkit.messageHandlers.trace.postMessage(String(e.reason)));console.warn=console.error=(...x)=>window.webkit.messageHandlers.trace.postMessage(x.map(String).join(' '));", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.setURLSchemeHandler(ProbeSchemeHandler(root: URL(fileURLWithPath: CommandLine.arguments[2])), forURLScheme: "flux-renderer")
        let width = Double(ProcessInfo.processInfo.environment["FLUX_MATH_PROBE_WIDTH"] ?? "960") ?? 0
        guard width.isFinite, (240...1920).contains(width) else {
            fputs("Probe width must be between 240 and 1920 points\n", stderr)
            exit(2)
        }
        view = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: 900), configuration: config)
        let zoom = Double(ProcessInfo.processInfo.environment["FLUX_MATH_PROBE_ZOOM"] ?? "1") ?? 0
        guard zoom.isFinite, (0.5...3).contains(zoom) else {
            fputs("Probe zoom must be between 0.5 and 3\n", stderr)
            exit(2)
        }
        view.pageZoom = zoom
        let theme = ProcessInfo.processInfo.environment["FLUX_MATH_PROBE_THEME"] ?? "system"
        guard ["system", "light", "dark"].contains(theme) else { exit(2) }
        if theme != "system" { view.appearance = NSAppearance(named: theme == "dark" ? .darkAqua : .aqua) }
        view.navigationDelegate = self
        if ProcessInfo.processInfo.environment["FLUX_MATH_PROBE_WINDOW"] == "1" {
            let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
            window.title = "FluxMarkdown mathematical memory probe"
            window.contentView = view
            window.orderBack(nil)
            hostWindow = window
        }
        view.load(URLRequest(url: URL(string: CommandLine.arguments[1])!))
        let timeout = CommandLine.arguments.count > 5 ? Double(CommandLine.arguments[5]) ?? 45 : 45
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { fputs("Probe timeout\n", stderr); exit(2) }
    }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "errorFeedback" {
            // Test-only recorder: never execute recovery, open a browser or send a report.
            guard let body = message.body as? [String: String],
                  Set(body.keys) == Set(["action", "kind", "generation", "id", "reason"]),
                  let data = try? JSONSerialization.data(withJSONObject: body),
                  let json = String(data: data, encoding: .utf8) else { exit(3) }
            view.evaluateJavaScript("window.__issue64FeedbackMessages.push(\(json))")
            return
        }
        fputs("JS: \(message.body)\n",stderr)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        fputs("Page loaded\n",stderr)
        webView.callAsyncJavaScript(script, arguments: ["source":source, "probeZoom":webView.pageZoom,
            "probeTheme":ProcessInfo.processInfo.environment["FLUX_MATH_PROBE_THEME"] ?? "system"], in: nil, in: .page) { result in
            switch result {
            case .success(let value):
                if JSONSerialization.isValidJSONObject(value), let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]) { print(String(data: data, encoding: .utf8)!) }
                else { print(String(describing:value)) }
                if ProcessInfo.processInfo.environment["FLUX_MATH_PROBE_CLOSE_WAIT"] == "1" {
                    self.view.configuration.userContentController.removeScriptMessageHandler(forName: "trace")
                    self.view.navigationDelegate = nil
                    self.hostWindow?.contentView = nil
                    self.hostWindow?.orderOut(nil)
                    self.hostWindow = nil
                    self.view = nil
                    fputs("JS: MEMPHASE webview-released\n", stderr)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 15) { exit(0) }
                } else if let path = ProcessInfo.processInfo.environment["FLUX_MATH_PROBE_SNAPSHOT"] {
                    webView.takeSnapshot(with: nil) { image, error in
                        guard error == nil, let tiff = image?.tiffRepresentation,
                              let bitmap = NSBitmapImageRep(data: tiff),
                              let png = bitmap.representation(using: .png, properties: [:]) else {
                            fputs("Probe snapshot failed\n", stderr); exit(1)
                        }
                        do { try png.write(to: URL(fileURLWithPath: path)); exit(0) }
                        catch { fputs("Probe snapshot could not be saved\n", stderr); exit(1) }
                    }
                } else { exit(0) }
            case .failure(let error): fputs("\(error)\n",stderr); exit(1)
            }
        }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fputs("\(error)\n",stderr); exit(1) }
}
let probe = Probe()
probe.start()
app.run()
