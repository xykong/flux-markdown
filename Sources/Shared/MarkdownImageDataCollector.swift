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
        let baseDirectory = markdownURL.deletingLastPathComponent()
        let resolvedBaseDirectory = baseDirectory.resolvingSymlinksInPath().standardizedFileURL
        let nsContent = content as NSString
        let pattern = #"!\[[^\]]*\]\(([^)\"]+(?:\s+\"[^\"]*\")?)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [:] }

        let matches = regex.matches(
            in: content,
            range: NSRange(location: 0, length: nsContent.length)
        )

        var imageData: [String: String] = [:]
        var collectedImageCount = 0
        var collectedBytes: UInt64 = 0
        for match in matches where match.numberOfRanges >= 2 {
            guard collectedImageCount < limits.maxImageCount else { break }

            let originalReference = nsContent.substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let imagePath = stripMarkdownImageTitle(from: originalReference)

            guard shouldInline(imagePath) else { continue }

            let imageURL = resolveImageURL(imagePath, relativeTo: baseDirectory)
            guard isContained(imageURL, in: resolvedBaseDirectory) else { continue }
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

    private static func isContained(_ url: URL, in baseDirectory: URL) -> Bool {
        let basePath = baseDirectory.path
        let imagePath = url.resolvingSymlinksInPath().standardizedFileURL.path
        return imagePath.hasPrefix(basePath.hasSuffix("/") ? basePath : "\(basePath)/")
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
