import Foundation

/// Read at most maxBytes + 1, so a changed file cannot bypass a prior stat limit.
enum BoundedFileReader {
    static let documentLimit = 32 * 1024 * 1024
    static func read(_ url: URL, maxBytes: Int) throws -> Data {
        var metadataURL = url
        metadataURL.removeAllCachedResourceValues()
        let values = try metadataURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, (values.fileSize ?? 0) <= maxBytes else {
            throw CocoaError(.fileReadTooLarge)
        }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let data = try file.read(upToCount: maxBytes + 1) ?? Data()
        guard data.count <= maxBytes else { throw CocoaError(.fileReadTooLarge) }
        return data
    }
}

/// Quick Look Markdown read limits. TSV keeps its own bounded preview and the
/// app keeps `BoundedFileReader.documentLimit`.
enum MarkdownPreviewPolicy {
    static let previewLimit = 2 * 1024 * 1024
    static func readLimit(for url: URL) -> Int {
        url.pathExtension.lowercased() == "tsv" ? PreviewFileReader.previewLimit : previewLimit
    }

}

/// Localization keys for the incomplete-preview notice and the tail-window status line.
enum PreviewLimitNotice {
    /// The status line under the incomplete-preview panel, and its Follow counterpart.
    static let headStatus = "Showing the first %1$@ of %2$@; the rest is not shown. Click Follow Changes to see the end."
    static let limitedHeadStatus = "Showing the first %1$@ of %2$@."
    static let tailStatus = "Showing the last %1$@ of %2$@."
}

/// Chooses where a window that must start at or after `cut` begins: a line outside a
/// top-level fence that follows a blank line; otherwise the first line outside a fence
/// after the cut; otherwise the first line after the cut.
struct WindowStartFinder {
    let cut: UInt64
    let size: UInt64
    private(set) var safe: (byte: UInt64, line: Int)?
    private(set) var outsideFence: (byte: UInt64, line: Int)?
    private(set) var afterCut: (byte: UInt64, line: Int)?
    private(set) var linesBeforeCut = 0

    var start: (byte: UInt64, line: Int)? { safe ?? outsideFence ?? afterCut }

    /// Use as `MarkdownLineScanner.feed`'s callback; returns true once a safe line is found.
    mutating func lineEnded(next: UInt64, wasBlank: Bool, lines: Int, inFence: Bool) -> Bool {
        if next <= cut { linesBeforeCut = lines }
        guard next >= cut, next < size else { return false }
        if afterCut == nil { afterCut = (next, lines) }
        guard !inFence else { return false }
        if outsideFence == nil { outsideFence = (next, lines) }
        if wasBlank { safe = (next, lines); return true }
        return false
    }
}

/// Counts lines and tracks top-level fenced code blocks in bytes fed in chunks.
/// Fences inside list items or block quotes are not recognised.
struct MarkdownLineScanner {
    private(set) var offset: UInt64 = 0
    private(set) var line = 0
    private(set) var inFence = false
    private var fenceByte: UInt8 = 0
    private var fenceLength = 0
    // Current line: 0 leading spaces, 1 in a ` or ~ run, 2 after the run, 3 no fence marker.
    private var phase: UInt8 = 0
    private var leading = 0
    private var markerByte: UInt8 = 0
    private var run = 0
    private var trailing = false
    private var blank = true

    /// Feeds bytes. After each newline, `lineEnded` receives the next line's start,
    /// whether the ended line was blank, the lines completed and whether a fence is
    /// open after it; returning true stops the scan.
    mutating func feed(_ bytes: UnsafeRawBufferPointer, lineEnded: (_ next: UInt64, _ wasBlank: Bool, _ lines: Int, _ inFence: Bool) -> Bool) -> Bool {
        guard let base = bytes.baseAddress else { return false }
        let start = offset
        var index = 0
        while index < bytes.count {
            // Once a line is known not to matter, jump to its end.
            if !blank && (phase == 3 || (phase == 2 && trailing)) {
                guard let newline = memchr(base + index, 0x0A, bytes.count - index) else { break }
                index = base.distance(to: UnsafeRawPointer(newline))
            }
            let byte = bytes[index]
            index += 1
            if byte == 0x0A {
                if run >= 3 {
                    if !inFence { inFence = true; fenceByte = markerByte; fenceLength = run }
                    else if markerByte == fenceByte && run >= fenceLength && !trailing { inFence = false }
                }
                let wasBlank = blank
                line += 1
                phase = 0; leading = 0; markerByte = 0; run = 0; trailing = false; blank = true
                offset = start + UInt64(index)
                if lineEnded(offset, wasBlank, line, inFence) { return true }
                continue
            }
            let space = byte == 0x20 || byte == 0x09 || byte == 0x0D
            if !space { blank = false }
            switch phase {
            case 0:
                if byte == 0x20 && leading < 3 { leading += 1 }
                else if byte == 0x60 || byte == 0x7E { phase = 1; markerByte = byte; run = 1 }
                else { phase = 3 }
            case 1:
                if byte == markerByte { run += 1 } else { phase = 2; if !space { trailing = true } }
            case 2:
                if !space { trailing = true }
            default:
                break
            }
        }
        offset = start + UInt64(bytes.count)
        return false
    }
}

/// Identity and timestamps used to skip reading unchanged preview files.
struct PreviewFileRevision: Equatable {
    private let device: dev_t
    private let inode: ino_t
    let size: UInt64
    private let modified: timespec
    private let changed: timespec

    fileprivate init(_ status: stat) throws {
        guard status.st_mode & S_IFMT == S_IFREG else { throw CocoaError(.fileReadUnsupportedScheme) }
        device = status.st_dev
        inode = status.st_ino
        size = UInt64(status.st_size)
        modified = status.st_mtimespec
        changed = status.st_ctimespec
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.device == rhs.device && lhs.inode == rhs.inode && lhs.size == rhs.size &&
            lhs.modified.tv_sec == rhs.modified.tv_sec && lhs.modified.tv_nsec == rhs.modified.tv_nsec &&
            lhs.changed.tv_sec == rhs.changed.tv_sec && lhs.changed.tv_nsec == rhs.changed.tv_nsec
    }
}

enum PreviewFileReader {
    struct Snapshot {
        let content: String
        let isTruncated: Bool
        let revision: PreviewFileRevision
        var size: UInt64 { revision.size }
        /// For a tail window: where it starts in the file, and how many lines precede it.
        var startByte: UInt64 = 0
        var startLine = 0
    }
    static let previewLimit = 500 * 1024

    static func revision(at url: URL) throws -> PreviewFileRevision {
        var status = stat()
        let result = url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return Int32(-1) }
            return stat(path, &status)
        }
        guard result == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        return try PreviewFileRevision(status)
    }

    private static func revision(of file: FileHandle) throws -> PreviewFileRevision {
        var status = stat()
        guard fstat(file.fileDescriptor, &status) == 0 else { throw CocoaError(.fileReadUnknown) }
        return try PreviewFileRevision(status)
    }

    static func read(_ url: URL, limit: Int = previewLimit) throws -> Snapshot {
        _ = try revision(at: url)
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let revision = try revision(of: file)
        let data = try file.read(upToCount: limit + 1) ?? Data()
        let preview = try decode(data, limit: limit)
        let content = url.pathExtension.lowercased() == "mmd" ? "```mermaid\n\(preview.content)\n```" : preview.content
        return Snapshot(content: content, isTruncated: preview.isTruncated, revision: revision)
    }

    /// Reads the end of a file, at most `window` bytes, starting at a line that is
    /// outside a top-level fenced code block and follows a blank line. Without such
    /// a line it starts at the first line outside a fence after the cut, then at the
    /// first line after the cut, then at the first character boundary after it.
    static func readTail(_ url: URL, window: Int) throws -> Snapshot {
        _ = try revision(at: url)
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let revision = try revision(of: file)
        let size = revision.size
        let cut = size > UInt64(window) ? size - UInt64(window) : 0
        var finder = WindowStartFinder(cut: cut, size: size)
        var scanner = MarkdownLineScanner()
        var scanned: UInt64 = 0
        while cut > 0, finder.safe == nil, scanned < size {
            // Drain each chunk at once; otherwise a 1 GiB scan holds every chunk until the read returns.
            let more = try autoreleasepool { () throws -> Bool in
                guard let chunk = try file.read(upToCount: Int(min(4 * 1024 * 1024, size - scanned))), !chunk.isEmpty else { return false }
                scanned += UInt64(chunk.count)
                _ = chunk.withUnsafeBytes { bytes in
                    scanner.feed(bytes) { finder.lineEnded(next: $0, wasBlank: $1, lines: $2, inFence: $3) }
                }
                return true
            }
            if !more { break }
        }
        var chosen: (byte: UInt64, line: Int) = cut == 0 ? (0, 0) : finder.start ?? (cut, -1)
        if chosen.line < 0 {
            // One line spans the cut: begin at the next UTF-8 character boundary.
            try file.seek(toOffset: cut)
            let probe = try file.read(upToCount: 4) ?? Data()
            let skip = probe.prefix { $0 >= 0x80 && $0 <= 0xBF }.count
            chosen = (cut + UInt64(skip), finder.linesBeforeCut)
        }
        try file.seek(toOffset: chosen.byte)
        let data = try file.read(upToCount: Int(size - chosen.byte)) ?? Data()
        guard let decoded = completePrefix(data) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        return Snapshot(content: decoded, isTruncated: false, revision: revision, startByte: chosen.byte, startLine: chosen.line)
    }

    static func decode(_ input: Data, limit: Int = previewLimit) throws -> (content: String, isTruncated: Bool) {
        let truncated = input.count > limit
        let data = Data(input.prefix(limit))
        let decoded = truncated ? completePrefix(data) : String(data: data, encoding: .utf8)
        guard let content = decoded else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        return (content, truncated)
    }

    /// Decodes UTF-8, leaving out only an incomplete final character. A valid
    /// character has at most four bytes; malformed bytes are never concealed.
    private static func completePrefix(_ data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8) { return text }
        for removed in 1...min(3, data.count) {
            let prefix = data.dropLast(removed)
            let tail = Array(data.suffix(removed))
            let lead = tail.first ?? 0
            let expected = lead >= 0xC2 && lead <= 0xDF ? 2 : lead >= 0xE0 && lead <= 0xEF ? 3 : lead >= 0xF0 && lead <= 0xF4 ? 4 : 0
            if expected > removed && tail.dropFirst().allSatisfy({ $0 >= 0x80 && $0 <= 0xBF }),
               let text = String(data: prefix, encoding: .utf8) {
                return text
            }
        }
        return nil
    }
}
