import WebKit
import os.log

final class RendererBundleSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "flux-renderer"

    private let logger = OSLog(subsystem: "com.markdownquicklook.app", category: "RendererBundleSchemeHandler")
    private let rootDirectory: URL

    init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory.standardizedFileURL.resolvingSymlinksInPath()
        super.init()
    }

    convenience init?(bundle: Bundle) {
        guard let indexURL = Self.findIndexHtml(in: bundle) else {
            return nil
        }
        self.init(rootDirectory: indexURL.deletingLastPathComponent())
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              let fileURL = resolveContainedFileURL(from: url) else {
            urlSchemeTask.didFailWithError(NSError(
                domain: "RendererBundleSchemeHandler",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Renderer resource not found or outside bundle"]
            ))
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let response = buildResponse(for: url, fileURL: fileURL, data: data)
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            os_log("Failed to load renderer resource %{public}@: %{public}@", log: logger, type: .error, fileURL.path, error.localizedDescription)
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        os_log("Stopped renderer resource load: %{public}@", log: logger, type: .debug, urlSchemeTask.request.url?.absoluteString ?? "unknown")
    }

    func resolveContainedFileURL(from url: URL) -> URL? {
        let resourcePath = normalizedResourcePath(from: url)
        let candidate = rootDirectory
            .appendingPathComponent(resourcePath)
            .standardizedFileURL
            .resolvingSymlinksInPath()

        return isContained(candidate, in: rootDirectory) ? candidate : nil
    }

    func buildResponse(for url: URL, fileURL: URL, data: Data) -> URLResponse {
        let mime = mimeType(for: fileURL)
        let headers: [String: String] = [
            "Content-Type": mime,
            "Content-Length": "\(data.count)",
            "Cache-Control": "no-cache, no-store, must-revalidate"
        ]

        if let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) {
            return response
        }

        return URLResponse(url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: nil)
    }

    static func rendererURL(for relativePath: String = "index.html") -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "bundle"
        components.path = "/" + relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return components.url!
    }

    static func findIndexHtml(in bundle: Bundle) -> URL? {
        if let url = bundle.url(forResource: "index", withExtension: "html", subdirectory: "WebRenderer") {
            return url
        }
        if let url = bundle.url(forResource: "index", withExtension: "html", subdirectory: "dist") {
            return url
        }
        return bundle.url(forResource: "index", withExtension: "html")
    }

    private func normalizedResourcePath(from url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil

        let path = components?.percentEncodedPath.removingPercentEncoding ?? url.path
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed.isEmpty ? "index.html" : trimmed
    }

    private func mimeType(for fileURL: URL) -> String {
        switch fileURL.pathExtension.lowercased() {
        case "html": return "text/html; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "js", "mjs": return "application/javascript; charset=utf-8"
        case "json", "map": return "application/json; charset=utf-8"
        case "wasm": return "application/wasm"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        case "ttf": return "font/ttf"
        case "otf": return "font/otf"
        default: return "application/octet-stream"
        }
    }

    private func isContained(_ url: URL, in baseDirectory: URL) -> Bool {
        let basePath = baseDirectory.resolvingSymlinksInPath().standardizedFileURL.path
        let filePath = url.resolvingSymlinksInPath().standardizedFileURL.path
        if filePath == basePath { return true }
        return filePath.hasPrefix(basePath.hasSuffix("/") ? basePath : "\(basePath)/")
    }
}
