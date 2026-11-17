import Foundation

/// User-selected material only. Never placed in diagnostic history or URLs.
enum FeedbackReproduction {
    static let inputLimit = 20 * 1024 * 1024
    struct Entry { let name: String; let data: Data }
    struct Snapshot { let source: String }
    struct Package {
        let entries: [Entry]
        let missing: [String]
        func writeZIP(to url: URL) throws {
            var archive = Data(), central = Data()
            for entry in entries {
                let name = Data(entry.name.utf8), offset = UInt32(archive.count), size = UInt32(entry.data.count)
                let crc = FeedbackReproduction.crc32(entry.data)
                archive.le(UInt32(0x04034b50)); archive.le(UInt16(20)); archive.le(UInt16(0x800)); archive.le(UInt16(0))
                archive.le(UInt16(0)); archive.le(UInt16(0x21)); archive.le(crc); archive.le(size); archive.le(size)
                archive.le(UInt16(name.count)); archive.le(UInt16(0)); archive.append(name); archive.append(entry.data)
                central.le(UInt32(0x02014b50)); central.le(UInt16(20)); central.le(UInt16(20)); central.le(UInt16(0x800)); central.le(UInt16(0))
                central.le(UInt16(0)); central.le(UInt16(0x21)); central.le(crc); central.le(size); central.le(size)
                central.le(UInt16(name.count)); central.le(UInt16(0)); central.le(UInt16(0)); central.le(UInt16(0)); central.le(UInt16(0))
                central.le(UInt32(0)); central.le(offset); central.append(name)
            }
            let centralOffset = UInt32(archive.count); archive.append(central)
            archive.le(UInt32(0x06054b50)); archive.le(UInt16(0)); archive.le(UInt16(0)); archive.le(UInt16(entries.count)); archive.le(UInt16(entries.count))
            archive.le(UInt32(central.count)); archive.le(centralOffset); archive.le(UInt16(0))
            guard archive.count < 25 * 1024 * 1024 else { throw CocoaError(.fileWriteFileExists) }
            try archive.write(to: url, options: .atomic)
        }
    }
    static func document(_ url: URL) throws -> Snapshot {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw CocoaError(.fileReadNoPermission) }
        let data = try BoundedFileReader.read(url, maxBytes: inputLimit)
        guard let source = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        return Snapshot(source: source)
    }
    /// Includes explicit inline, HTML and reference-definition image destinations.
    /// Conservative parser: unsupported forms remain listed in the document, never guessed by directory scanning.
    static func references(_ source: String) -> [String] {
        let patterns = [#"!\[[^\]\r\n]*\]\(\s*<?([^\s<>\)]+)>?(?:\s+[^\)]*)?\)"#,
                        #"(?mi)^\s{0,3}\[[^\]\r\n]+\]:\s*<?([^\s<>]+)>?"#,
                        #"(?i)<img\b[^>]*\bsrc\s*=\s*["']([^"']+)["']"#]
        var found = Set<String>()
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
                if let range = Range(match.range(at: 1), in: source) { found.insert(String(source[range])) }
            }
        }
        return found.sorted()
    }
    static func relativeName(_ reference: String) -> String? {
        guard let decoded = reference.removingPercentEncoding, !decoded.isEmpty, !decoded.hasPrefix("/"), !decoded.contains(":"), !decoded.contains("\\"), !decoded.contains("\0"), !decoded.contains("#"), !decoded.contains("?") else { return nil }
        let parts = decoded.split(separator: "/", omittingEmptySubsequences: false).filter { $0 != "." }
        guard !parts.isEmpty, parts.allSatisfy({ !$0.isEmpty && $0 != ".." }), decoded.utf8.count < 1024 else { return nil }
        let result = parts.joined(separator: "/")
        guard !["document.md", "sample.md", "diagnostics.txt", "manifest.json"].contains(result) else { return nil }
        return result
    }
    static func prepare(source: String, mode: String, diagnostics: String, incident: UUID, originalURL: URL? = nil, resources: [URL] = [], provenance: String = "selected-at-report-time") throws -> Package {
        guard ["sample", "document"].contains(mode), resources.count <= 96 else { throw CocoaError(.fileReadTooLarge) }
        var entries = [Entry(name: mode == "document" ? "document.md" : "sample.md", data: Data(source.utf8)), Entry(name: "diagnostics.txt", data: Data(diagnostics.utf8))]
        var total = entries.reduce(0) { $0 + $1.data.count }
        guard total <= inputLimit else { throw CocoaError(.fileReadTooLarge) }
        let refs = references(source)
        let base = originalURL?.deletingLastPathComponent().standardizedFileURL
        var included = Set<String>()
        for url in resources {
            guard let base, url.isFileURL,
                  let reference = refs.first(where: { ref in relativeName(ref).map { base.appendingPathComponent($0).standardizedFileURL == url.standardizedFileURL } ?? false }),
                  let name = relativeName(reference), !included.contains(name),
                  url.standardizedFileURL.resolvingSymlinksInPath() == url.standardizedFileURL,
                  url.standardizedFileURL.path.hasPrefix(base.path + "/") else { throw CocoaError(.fileReadNoPermission) }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { throw CocoaError(.fileReadNoPermission) }
            let data = try BoundedFileReader.read(url, maxBytes: inputLimit - total)
            total += data.count; entries.append(Entry(name: name, data: data)); included.insert(name)
        }
        let missing = refs.filter { ref in relativeName(ref).map { !included.contains($0) } ?? true }
        let manifest: [String: Any] = ["schema": 1, "incident": incident.uuidString, "mode": mode, "provenance": provenance,
                                        "files": entries.map { ["name": $0.name, "bytes": $0.data.count] }, "notIncludedReferences": missing]
        let metadata = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        guard total + metadata.count <= inputLimit else { throw CocoaError(.fileReadTooLarge) }
        entries.append(Entry(name: "manifest.json", data: metadata))
        return Package(entries: entries, missing: missing)
    }
    private static let crcTable: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 { value = (value & 1) != 0 ? 0xedb88320 ^ (value >> 1) : value >> 1 }
        return value
    }
    private static func crc32(_ data: Data) -> UInt32 {
        var crc = UInt32.max
        for byte in data { crc = crcTable[Int((crc ^ UInt32(byte)) & 0xff)] ^ (crc >> 8) }
        return crc ^ UInt32.max
    }
}
private extension Data {
    mutating func le<T: FixedWidthInteger>(_ value: T) { var little = value.littleEndian; Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) } }
}

/// Ephemeral native context; never persisted with the diagnostic incident.
struct FeedbackMaterialContext {
    let document: String?
    let sample: String?
    let originalURL: URL?
    let provenance: String
    static func captured(document: String, url: URL?, first: Int?, last: Int?) -> Self {
        var sample: String?
        if let first, let last, first > 0, last >= first, last - first < 100 {
            let lines = document.components(separatedBy: "\n")
            if last <= lines.count {
                let value = lines[(first-1)..<last].joined(separator: "\n")
                if value.utf8.count <= 6000 { sample = value }
            }
        }
        return Self(document: document.utf8.count <= FeedbackReproduction.inputLimit ? document : nil,
                    sample: sample, originalURL: url, provenance: "captured-render-input")
    }
}
