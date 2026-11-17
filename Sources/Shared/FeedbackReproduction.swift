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
            // Use the system ZIP implementation rather than maintain a custom archive format.
            let work = FileManager.default.temporaryDirectory.appendingPathComponent("FluxMarkdown-reproduction-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            defer { try? FileManager.default.removeItem(at: work) }
            let input = work.appendingPathComponent("input")
            try FileManager.default.createDirectory(at: input, withIntermediateDirectories: false)
            for entry in entries {
                let parts = entry.name.split(separator: "/", omittingEmptySubsequences: false)
                guard !parts.isEmpty, parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }), !entry.name.contains("\\") else { throw CocoaError(.fileWriteInvalidFileName) }
                let file = input.appendingPathComponent(entry.name)
                try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                try entry.data.write(to: file, options: .atomic)
            }
            let output = work.appendingPathComponent("package.zip")
            let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-c", "-k", "--norsrc", "--noextattr", "--noqtn", input.path, output.path]
            process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
            try process.run()
            let deadline = Date().addingTimeInterval(20)
            while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
            if process.isRunning { process.terminate(); throw CocoaError(.fileWriteUnknown) }
            guard process.terminationStatus == 0 else { throw CocoaError(.fileWriteUnknown) }
            let archive = try BoundedFileReader.read(output, maxBytes: 25 * 1024 * 1024 - 1)
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
        let manifest: [String: Any] = ["schema": 1, "incident": incident.uuidString, "mode": mode, "provenance": provenance, "resourcesProvenance": "selected-at-report-time",
                                        "files": entries.map { ["name": $0.name, "bytes": $0.data.count] }, "notIncludedReferences": missing]
        let metadata = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        guard total + metadata.count <= inputLimit else { throw CocoaError(.fileReadTooLarge) }
        entries.append(Entry(name: "manifest.json", data: metadata))
        return Package(entries: entries, missing: missing)
    }
}

/// Ephemeral native context; never persisted with the diagnostic incident.
struct FeedbackMaterialContext {
    let document: String?
    let sample: String?
    let originalURL: URL?
    let provenance: String
    var displayName: String? = nil
    private static func withReferenceContext(_ fragment: String, document: String) -> String {
        guard let refs = try? NSRegularExpression(pattern: #"\\(?:eqref|ref)\{([^{}]+)\}"#),
              let formulas = try? NSRegularExpression(pattern: #"(?s)\$\$.*?\$\$|\\\[.*?\\\]|\\\(.*?\\\)|\$[^$\n]+\$|(?m)^```(?:math|latex|tex)[^\n]*\n.*?^```"#) else { return fragment }
        let matches = refs.matches(in: fragment, range: NSRange(fragment.startIndex..., in: fragment))
        let labels = Set(matches.compactMap { Range($0.range(at: 1), in: fragment).map { String(fragment[$0]) } })
        var result = fragment
        for match in formulas.matches(in: document, range: NSRange(document.startIndex..., in: document)) {
            guard let range = Range(match.range, in: document) else { continue }
            let formula = String(document[range])
            guard labels.contains(where: { formula.contains("\\label{" + $0 + "}") }), !result.contains(formula) else { continue }
            if result.utf8.count + formula.utf8.count + 2 <= 6000 { result += "\n\n" + formula }
        }
        return result
    }
    static func captured(document: String, url: URL?, first: Int?, last: Int?) -> Self {
        var sample: String?
        if let first, let last, first > 0, first <= 1_000_000, last >= first, last <= 1_000_000, last - first < 100 {
            let lines = document.components(separatedBy: "\n")
            if last <= lines.count {
                let value = lines[(first-1)..<last].joined(separator: "\n")
                if value.utf8.count <= 6000 { sample = FeedbackMaterialContext.withReferenceContext(value, document: document) }
            }
        }
        return Self(document: document.utf8.count <= FeedbackReproduction.inputLimit ? document : nil,
                    sample: sample, originalURL: url, provenance: "captured-render-input")
    }
}
