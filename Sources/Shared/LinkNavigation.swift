import Foundation

/// A clicked local link resolved against the current document.
struct LocalLinkTarget: Equatable {
    let url: URL
    /// Percent-decoded `#fragment` from the original href, when present.
    let fragment: String?
    /// 1-based source line taken from an editor-style `path:line[:column]` suffix.
    let line: Int?
}

/// What clicking a resolved local link asks FluxMarkdown to do.
enum LocalLinkAction: Equatable {
    /// Open the file in FluxMarkdown itself, optionally at a source line or anchor.
    case openFluxMarkdown(DocumentPosition?)
    /// Hand an existing non-document file to its macOS application.
    case openExternally
}

enum LinkNavigation {

    /// Document types that FluxMarkdown both hosts and can position inside.
    static let documentExtensions: Set<String> = ["md", "mdx", "markdown", "mdown", "mkd", "mkdn", "mkdown", "mdwn", "rmd", "qmd", "mdoc", "mdc", "mmd", "livemd", "tsv"]

    /// Resolves a clicked local href, accepting the `path:line[:column]` form that
    /// editors and chat tools emit (e.g. `/src/Foo.java:57`). The suffix is only
    /// stripped when the literal target is missing and the stripped file exists, so
    /// a real file whose name contains a colon keeps winning.
    static func resolveLocalLink(href: String, relativeTo fileURL: URL) -> LocalLinkTarget? {
        let parts = splitHref(href)
        guard let target = resolveLocalURL(href: parts.path, relativeTo: fileURL) else { return nil }
        if FileManager.default.fileExists(atPath: target.path) {
            return LocalLinkTarget(url: target, fragment: parts.fragment, line: nil)
        }
        guard let reference = lineReference(in: target), isRegularFile(reference.url) else {
            return LocalLinkTarget(url: target, fragment: parts.fragment, line: nil)
        }
        return LocalLinkTarget(url: reference.url, fragment: parts.fragment, line: reference.line)
    }

    static func resolveLocalURL(href: String, relativeTo fileURL: URL) -> URL? {
        let decoded = href.removingPercentEncoding ?? href

        if decoded.isEmpty { return nil }

        if decoded.hasPrefix("#") { return nil }

        if decoded.hasPrefix("file://") {
            return URL(string: decoded)
        }

        if decoded.hasPrefix("/") {
            return URL(fileURLWithPath: decoded)
        }

        let baseDir = fileURL.deletingLastPathComponent()
        var targetURL = baseDir
        for component in decoded.split(separator: "/") {
            let componentStr = String(component)
            if componentStr == ".." {
                targetURL.deleteLastPathComponent()
            } else if componentStr != "." {
                targetURL.appendPathComponent(componentStr)
            }
        }
        return targetURL
    }

    /// Text to place on the pasteboard for a destination that could not be opened:
    /// a plain filesystem path for local files, the full URL otherwise.
    static func clipboardText(for url: URL) -> String {
        url.isFileURL ? url.path : url.absoluteString
    }

    /// Chooses between in-app document navigation (line or anchor) and handing the
    /// file to macOS. Editor-style line suffixes only apply to documents, so a source
    /// file such as `Foo.java:57` opens its file instead of failing.
    static func action(for link: LocalLinkTarget) -> LocalLinkAction {
        guard documentExtensions.contains(link.url.pathExtension.lowercased()) else { return .openExternally }
        if let line = link.line { return .openFluxMarkdown(.line(line)) }
        if let fragment = link.fragment, !fragment.isEmpty { return .openFluxMarkdown(.anchor(fragment)) }
        return .openFluxMarkdown(nil)
    }

    // MARK: - Editor-style suffixes

    /// Splits `name:line[:column]` into the real file name and its 1-based line.
    private static func splitLineSuffix(_ component: String) -> (name: String, line: Int)? {
        let fields = component.split(separator: ":", omittingEmptySubsequences: false)
        guard fields.count == 2 || fields.count == 3 else { return nil }
        let name = String(fields[0])
        guard !name.isEmpty, name != ".", name != ".." else { return nil }
        guard let line = numericField(fields[1]) else { return nil }
        if fields.count == 3, numericField(fields[2]) == nil { return nil }
        return (name, line)
    }

    private static func lineReference(in url: URL) -> (url: URL, line: Int)? {
        guard let split = splitLineSuffix(url.lastPathComponent) else { return nil }
        return (url.deletingLastPathComponent().appendingPathComponent(split.name), split.line)
    }

    private static func numericField(_ field: Substring) -> Int? {
        guard !field.isEmpty, field.count <= 9,
              field.allSatisfy({ $0.isASCII && $0.isNumber }),
              let value = Int(field), value > 0, value <= 9_999_999 else { return nil }
        return value
    }

    private static func isRegularFile(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return false }
        return !isDirectory.boolValue
    }

    private static func splitHref(_ href: String) -> (path: String, fragment: String?) {
        guard let hashRange = href.range(of: "#") else { return (href, nil) }
        return (String(href[href.startIndex..<hashRange.lowerBound]), String(href[hashRange.upperBound...]))
    }
}
