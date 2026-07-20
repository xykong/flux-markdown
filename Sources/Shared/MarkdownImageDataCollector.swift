import Foundation

enum MarkdownImageDataCollector {
    struct Limits {
        let maxImageCount: Int
        let maxImageBytes: UInt64
        let maxTotalBytes: UInt64

        static let `default` = Limits(
            maxImageCount: 32,
            maxImageBytes: 2 * 1024 * 1024,
            maxTotalBytes: 8 * 1024 * 1024
        )
    }

    static func collectImageData(
        from markdownURL: URL,
        content: String,
        limits: Limits = .default
    ) -> [String: String] {
        var imageData: [String: String] = [:]
        var collectedImageCount = 0
        var collectedBytes: UInt64 = 0
        for reference in localImageReferences(from: markdownURL, content: content) {
            guard collectedImageCount < limits.maxImageCount else { break }
            let imagePath = reference.path
            let imageURL = reference.url
            guard let mimeType = mimeType(for: imageURL) else { continue }
            guard let fileSize = fileSize(of: imageURL) else { continue }
            guard fileSize <= limits.maxImageBytes else { continue }
            guard fileSize <= limits.maxTotalBytes else { continue }
            guard collectedBytes <= limits.maxTotalBytes - fileSize else { continue }
            guard let data = try? Data(contentsOf: imageURL) else { continue }

            let dataURL = "data:\(mimeType);base64,\(data.base64EncodedString())"
            imageData[imagePath] = dataURL
            collectedImageCount += 1
            collectedBytes += fileSize

            if imagePath.hasPrefix("./") {
                imageData[String(imagePath.dropFirst(2))] = dataURL
            } else {
                imageData["./\(imagePath)"] = dataURL
            }
        }

        return imageData
    }

    static func referencedLocalImageURLs(from markdownURL: URL, content: String) -> Set<URL> {
        Set(localImageReferences(from: markdownURL, content: content).map(\.url))
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

        let markdownPattern = #"!\[[^\]]*\]\(([^)\"]+(?:\s+\"[^\"]*\")?)\)"#
        if let regex = try? NSRegularExpression(pattern: markdownPattern) {
            for match in regex.matches(in: content, range: fullRange) where match.numberOfRanges >= 2 {
                let originalReference = nsContent.substring(with: match.range(at: 1))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                pathMatches.append((match.range.location, stripMarkdownImageTitle(from: originalReference)))
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
        guard let quoteIndex = reference.firstIndex(of: "\"") else { return reference }
        let prefix = reference[..<quoteIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        return prefix.isEmpty ? reference : prefix
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
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let fileSize = values.fileSize,
              fileSize >= 0
        else { return nil }

        return UInt64(fileSize)
    }
}
