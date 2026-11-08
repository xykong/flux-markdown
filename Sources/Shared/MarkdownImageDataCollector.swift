import Foundation
import os.log

enum MarkdownImageDataCollector {
    struct Limits {
        let maxImageCount: Int
        let maxImageBytes: UInt64
        let maxTotalBytes: UInt64

        static let `default` = Limits(
            maxImageCount: 32,
            // Keep the per-resource guard aligned with the document-wide budget.
            // A fixed 2 MiB cutoff hid legitimate assets such as the project's
            // README demo GIF; the aggregate budget still bounds memory use.
            maxImageBytes: 8 * 1024 * 1024,
            maxTotalBytes: 8 * 1024 * 1024
        )
    }

    static func collectImageData(
        from markdownURL: URL,
        content: String,
        limits: Limits = .default,
        fileExtensions: Set<String>? = nil
    ) -> [String: String] {
        var imageData: [String: String] = [:]
        var collectedImageCount = 0
        var collectedBytes: UInt64 = 0
        for reference in budgetedReferences(from: markdownURL, content: content, limits: limits) {
            guard collectedImageCount < limits.maxImageCount else { break }
            let imagePath = reference.path
            let imageURL = reference.url
            if let fileExtensions, !fileExtensions.contains(imageURL.pathExtension.lowercased()) { continue }
            guard let mimeType = mimeType(for: imageURL) else { continue }
            guard let fileSize = fileSize(of: imageURL) else { continue }
            guard fileSize <= limits.maxImageBytes else { continue }
            guard fileSize <= limits.maxTotalBytes else { continue }
            guard collectedBytes <= limits.maxTotalBytes - fileSize else { continue }
            let data: Data
            do { data = try BoundedFileReader.read(imageURL, maxBytes: Int(limits.maxImageBytes)) }
            catch { LocalResourceDiagnostics.log(error, operation: "inline-read"); continue }

            let dataURL = "data:\(mimeType);base64,\(data.base64EncodedString())"
            imageData[imagePath] = dataURL
            collectedImageCount += 1
            collectedBytes += UInt64(data.count)

            if imagePath.hasPrefix("./") {
                imageData[String(imagePath.dropFirst(2))] = dataURL
            } else {
                imageData["./\(imagePath)"] = dataURL
            }
        }

        return imageData
    }

    static func referencedLocalImageURLs(from markdownURL: URL, content: String) -> Set<URL> {
        Set(budgetedReferences(from: markdownURL, content: content, limits: .default).map(\.url))
    }

    private static func budgetedReferences(from url: URL, content: String, limits: Limits) -> [LocalImageReference] {
        var sizes: [URL: UInt64] = [:]
        var total: UInt64 = 0
        return localImageReferences(from: url, content: content).filter { reference in
            if sizes[reference.url] != nil { return true }
            guard let bytes = fileSize(of: reference.url) else { return false }
            guard sizes.count < limits.maxImageCount, bytes <= limits.maxImageBytes,
                  bytes <= limits.maxTotalBytes, total <= limits.maxTotalBytes - bytes else {
                LocalResourceDiagnostics.log(CocoaError(.fileReadTooLarge), operation: "image-budget")
                return false
            }
            sizes[reference.url] = bytes
            total += bytes
            return true
        }
    }

    private struct LocalImageReference {
        let location: Int
        let path: String
        let url: URL
    }

    private static func localImageReferences(from markdownURL: URL, content: String) -> [LocalImageReference] {
        let nsContent = content as NSString
        let fullRange = NSRange(location: 0, length: nsContent.length)
        var pathMatches: [(location: Int, path: String)] = []

        let markdownPattern = #"!\[[^\]]*\]\(\s*(<[^>\r\n]+>|(?:\\.|[^()\\\r\n]|\([^()\r\n]*\))+)\s*\)"#
        if let regex = try? NSRegularExpression(pattern: markdownPattern) {
            for match in regex.matches(in: content, range: fullRange) where match.numberOfRanges >= 2 {
                let originalReference = nsContent.substring(with: match.range(at: 1))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                pathMatches.append((match.range.location, stripMarkdownImageTitle(from: originalReference)))
            }
        }

        // Reference-style images use the same resolved source as markdown-it.
        func label(_ value: String) -> String {
            value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").lowercased()
        }
        var definitions: [String: String] = [:]
        let definitionPattern = #"(?m)^[ \t]{0,3}\[([^\]\r\n]+)\]:[ \t]*(<[^>\r\n]+>|[^\s]+)"#
        if let regex = try? NSRegularExpression(pattern: definitionPattern) {
            for match in regex.matches(in: content, range: fullRange) {
                let key = label(nsContent.substring(with: match.range(at: 1)))
                if definitions[key] == nil { definitions[key] = stripMarkdownImageTitle(from: nsContent.substring(with: match.range(at: 2))) }
            }
        }
        let referencePattern = #"!\[([^\]]*)\](?:\[([^\]]*)\])?(?!\()"#
        if let regex = try? NSRegularExpression(pattern: referencePattern) {
            for match in regex.matches(in: content, range: fullRange) {
                let alternate = match.range(at: 2).location != NSNotFound ? nsContent.substring(with: match.range(at: 2)) : ""
                let key = label(alternate.isEmpty ? nsContent.substring(with: match.range(at: 1)) : alternate)
                if let path = definitions[key] { pathMatches.append((match.range.location, path)) }
            }
        }

        let htmlPattern = #"<img\b[^>]*?\bsrc\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s\"'=<>`]+))[^>]*>"#
        if let regex = try? NSRegularExpression(pattern: htmlPattern, options: [.caseInsensitive]) {
            for match in regex.matches(in: content, range: fullRange) {
                for captureIndex in 1..<match.numberOfRanges where match.range(at: captureIndex).location != NSNotFound {
                    let path = nsContent.substring(with: match.range(at: captureIndex))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    pathMatches.append((match.range.location, path))
                    break
                }
            }
        }

        let resolvedBaseDirectory = markdownURL.deletingLastPathComponent()
            .resolvingSymlinksInPath()
            .standardizedFileURL
        var seenPaths = Set<String>()

        return pathMatches
            .sorted { $0.location < $1.location }
            .compactMap { match in
                guard shouldInline(match.path), seenPaths.insert(match.path).inserted else { return nil }

                let imageURL = resolveImageURL(match.path, relativeTo: resolvedBaseDirectory)
                    .standardizedFileURL
                guard mimeType(for: imageURL) != nil else { return nil }

                // Do not turn a symlink into an implicit escape from the explicitly named path.
                guard imageURL.resolvingSymlinksInPath().standardizedFileURL == imageURL else { return nil }

                return LocalImageReference(location: match.location, path: match.path, url: imageURL)
            }
    }

    private static func stripMarkdownImageTitle(from reference: String) -> String {
        var path = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.hasPrefix("<"), let end = path.firstIndex(of: ">") {
            return String(path[path.index(after: path.startIndex)..<end])
        }
        if let range = path.range(of: #"\s+(?:"[^"]*"|'[^']*')$"#, options: .regularExpression) {
            path.removeSubrange(range)
        }
        return path.replacingOccurrences(of: #"\([() ])"#, with: "$1", options: .regularExpression)
    }

    private static func shouldInline(_ imagePath: String) -> Bool {
        let lowercasedPath = imagePath.lowercased()
        return !imagePath.isEmpty
            && !lowercasedPath.hasPrefix("http://")
            && !lowercasedPath.hasPrefix("https://")
            && !lowercasedPath.hasPrefix("data:")
            && !lowercasedPath.hasPrefix("file://")
            && !imagePath.hasPrefix("/")
    }

    private static func resolveImageURL(_ imagePath: String, relativeTo baseDirectory: URL) -> URL {
        var normalizedPath = imagePath.removingPercentEncoding ?? imagePath
        if normalizedPath.hasPrefix("./") {
            normalizedPath = String(normalizedPath.dropFirst(2))
        }

        var imageURL = baseDirectory
        for component in normalizedPath.split(separator: "/") {
            if component == ".." {
                imageURL.deleteLastPathComponent()
            } else if component != "." {
                imageURL.appendPathComponent(String(component))
            }
        }
        return imageURL
    }

    private static func mimeType(for url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        default: return nil
        }
    }

    private static func fileSize(of url: URL) -> UInt64? {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard let size = values.fileSize, size >= 0 else { return nil }
            return UInt64(size)
        } catch {
            LocalResourceDiagnostics.log(error, operation: "image-stat")
            return nil
        }
    }
}

/// Never publish document paths or error userInfo in diagnostic logs.
enum LocalResourceDiagnostics {
    static func category(_ error: Error) -> String {
        let e = error as NSError
        if e.domain == NSCocoaErrorDomain {
            switch e.code {
            case NSFileReadNoPermissionError, NSFileWriteNoPermissionError: return "permission-denied"
            case NSFileNoSuchFileError, NSFileReadNoSuchFileError: return "missing-file"
            case NSFileReadTooLargeError: return "resource-limit"
            default: break
            }
        }
        if e.domain == NSPOSIXErrorDomain {
            if e.code == 1 || e.code == 13 { return "permission-denied" }
            if e.code == 2 { return "missing-file" }
        }
        return "read-failed"
    }
    static func log(_ error: Error, operation: String) {
        let e = error as NSError
        os_log("Local image failure operation=%{public}@ reason=%{public}@ domain=%{public}@ code=%{public}ld",
               log: OSLog(subsystem: "com.markdownquicklook.app", category: "LocalResources"),
               type: .error, operation, category(error), e.domain, e.code)
    }
}
