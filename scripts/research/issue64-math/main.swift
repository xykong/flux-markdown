import AppKit
import WebKit
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
final class Probe: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    var view: WKWebView!
    let script = try! String(contentsOfFile: CommandLine.arguments[3], encoding: .utf8)
    let source = try! String(contentsOfFile: CommandLine.arguments[4], encoding: .utf8)
    func start() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.userContentController.add(self, name: "trace")
        config.userContentController.addUserScript(WKUserScript(source: "window.addEventListener('error',e=>window.webkit.messageHandlers.trace.postMessage(String(e.message)));window.addEventListener('securitypolicyviolation',e=>window.webkit.messageHandlers.trace.postMessage('CSP '+e.blockedURI+' '+e.violatedDirective));window.addEventListener('unhandledrejection',e=>window.webkit.messageHandlers.trace.postMessage(String(e.reason)));console.warn=console.error=(...x)=>window.webkit.messageHandlers.trace.postMessage(x.map(String).join(' '));", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.setURLSchemeHandler(RendererBundleSchemeHandler(rootDirectory: URL(fileURLWithPath: CommandLine.arguments[2])), forURLScheme: "flux-renderer")
        view = WKWebView(frame: NSRect(x: 0, y: 0, width: 960, height: 900), configuration: config)
        view.navigationDelegate = self
        view.load(URLRequest(url: URL(string: CommandLine.arguments[1])!))
        let timeout = CommandLine.arguments.count > 5 ? Double(CommandLine.arguments[5]) ?? 45 : 45
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { fputs("Probe timeout\n", stderr); exit(2) }
    }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) { fputs("JS: \(message.body)\n",stderr) }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        fputs("Page loaded\n",stderr)
        webView.callAsyncJavaScript(script, arguments: ["source":source], in: nil, in: .page) { result in
            switch result {
            case .success(let value):
                if JSONSerialization.isValidJSONObject(value), let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]) { print(String(data: data, encoding: .utf8)!) }
                else { print(String(describing:value)) }
                exit(0)
            case .failure(let error): fputs("\(error)\n",stderr); exit(1)
            }
        }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fputs("\(error)\n",stderr); exit(1) }
}
let probe = Probe()
probe.start()
app.run()
