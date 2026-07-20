import WebKit
import os.log

class LocalSchemeHandler: NSObject, WKURLSchemeHandler {
    private let logger = OSLog(subsystem: "com.markdownquicklook.app", category: "LocalSchemeHandler")
    private let allowedFilesLock = NSLock()
    private var allowedFilePaths = Set<String>()
    var baseDirectory: URL?
    var allowedFileURLs: Set<URL> {
        get {
            allowedFilesLock.lock()
            defer { allowedFilesLock.unlock() }
            return Set(allowedFilePaths.map { URL(fileURLWithPath: $0) })
        }
        set {
            allowedFilesLock.lock()
            allowedFilePaths = Set(newValue.map { $0.standardizedFileURL.path })
            allowedFilesLock.unlock()
        }
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else { return }
        
        guard let baseDir = baseDirectory else {
            os_log("🔴 Base directory not set", log: logger, type: .error)
            urlSchemeTask.didFailWithError(NSError(domain: "LocalSchemeHandler", code: -1, userInfo: [NSLocalizedDescriptionKey: "Base directory not set"]))
            return
        }

        let filePath = resolveFilePath(from: url)

        os_log("🔵 Start loading resource: %{public}@", log: logger, type: .debug, filePath)

        guard let fileUrl = resolveContainedFileURL(from: url) else {
            os_log("🔴 Rejected resource outside base directory: %{public}@", log: logger, type: .error, filePath)
            urlSchemeTask.didFailWithError(NSError(domain: "LocalSchemeHandler", code: -3, userInfo: [NSLocalizedDescriptionKey: "Resource outside base directory"]))
            return
        }
        
        var coordinatorError: NSError?
        var resultData: Data?
        var accessError: Error?
        
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: fileUrl, options: [], error: &coordinatorError) { url in
            let _ = baseDir.startAccessingSecurityScopedResource()
            defer {
                baseDir.stopAccessingSecurityScopedResource()
            }
            
            do {
                resultData = try Data(contentsOf: url)
            } catch {
                accessError = error
            }
        }
        
        if let error = coordinatorError ?? accessError {
            os_log("🔴 Failed to load resource: %{public}@. Error: %{public}@", log: logger, type: .error, filePath, error.localizedDescription)
            urlSchemeTask.didFailWithError(error)
            return
        }
        
        if let data = resultData {
            let response = buildResponse(for: url, data: data)
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
            os_log("🟢 Successfully loaded: %{public}@", log: logger, type: .debug, filePath)
        } else {
            let error = NSError(domain: "LocalSchemeHandler", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data"])
            os_log("🔴 Failed to load resource: %{public}@. No data", log: logger, type: .error, filePath)
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        os_log("Stopped loading: %{public}@", log: logger, type: .debug, urlSchemeTask.request.url?.path ?? "unknown")
    }

    func resolveFilePath(from url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil

        let cleanURL = components?.url ?? url

        if let host = cleanURL.host, !host.isEmpty {
            return "/" + host + cleanURL.path
        }
        return cleanURL.path
    }

    func resolveContainedFileURL(from url: URL) -> URL? {
        guard let baseDirectory else { return nil }

        let fileURL = URL(fileURLWithPath: resolveFilePath(from: url))
        if isContained(fileURL, in: baseDirectory) || isExplicitlyAllowed(fileURL) {
            return fileURL
        }
        return nil
    }

    func buildResponse(for url: URL, data: Data) -> URLResponse {
        let mime = mimeType(for: url)
        let headers: [String: String] = [
            "Content-Type": mime,
            "Content-Length": "\(data.count)",
            "Cache-Control": "no-cache, no-store, must-revalidate"
        ]

        if let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) {
            return httpResponse
        }

        return URLResponse(url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: nil)
    }
    
    private func mimeType(for url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        let cleanPath = components?.url?.pathExtension.lowercased() ?? url.pathExtension.lowercased()
        switch cleanPath {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "css": return "text/css"
        case "js": return "application/javascript"
        default: return "application/octet-stream"
        }
    }

    private func isContained(_ url: URL, in baseDirectory: URL) -> Bool {
        let basePath = baseDirectory.resolvingSymlinksInPath().standardizedFileURL.path
        let filePath = url.resolvingSymlinksInPath().standardizedFileURL.path
        if filePath == basePath { return true }
        return filePath.hasPrefix(basePath.hasSuffix("/") ? basePath : "\(basePath)/")
    }

    private func isExplicitlyAllowed(_ url: URL) -> Bool {
        let resolvedPath = url.resolvingSymlinksInPath().standardizedFileURL.path
        allowedFilesLock.lock()
        defer { allowedFilesLock.unlock() }
        return allowedFilePaths.contains(resolvedPath)
    }
}
