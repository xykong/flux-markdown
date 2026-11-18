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
    /// Follow may stay below the preview limit until long-running appends are measured.
    static let followLimit = 2 * 1024 * 1024

    static func readLimit(for url: URL, following: Bool) -> Int {
        if url.pathExtension.lowercased() == "tsv" { return PreviewFileReader.previewLimit }
        return following ? min(previewLimit, followLimit) : previewLimit
    }

    /// While following, the window may grow by a quarter before it re-forms at the end.
    static let followWindowCeiling = followLimit + followLimit / 4
    /// While Follow is paused the window stays put; it may grow to this size, then updates wait.
    static let pausedWindowCeiling = 4 * 1024 * 1024

    enum OverLimitStep: Equatable { case hold, reread }

    /// The largest file an append may extend a followed window to before another step is needed.
    static func appendLimit(windowStart: UInt64) -> Int { Int(windowStart) + pausedWindowCeiling }
    static func shouldReform(heldBytes: Int, paused: Bool) -> Bool { !paused && heldBytes > followWindowCeiling }
    /// Past the append limit: wait while paused, otherwise read the end of the file again.
    static func overLimitStep(paused: Bool) -> OverLimitStep { paused ? .hold : .reread }

}

/// Localization keys for the incomplete-preview notice and the tail-window status line.
enum PreviewLimitNotice {
    /// The status line under the incomplete-preview panel, and its Follow counterpart.
    static let headStatus = "Showing the first %1$@ of %2$@; the rest is not shown. Click Follow Changes to see the end."
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

/// Where a complete read ended, so a later poll can read only appended bytes.
struct FollowCursor: Equatable {
    let offset: UInt64
    /// Up to the last 4 KiB before `offset`; a mismatch means the file was rewritten.
    let tail: Data
    let device: UInt64
    let inode: UInt64
    let modification: timespec

    static let tailLength = 4096

    init(offset: UInt64, tail: Data, status: stat) {
        self.offset = offset
        self.tail = Data(tail.suffix(Self.tailLength))
        device = UInt64(status.st_dev)
        inode = UInt64(status.st_ino)
        modification = status.st_mtimespec
    }

    static func == (lhs: FollowCursor, rhs: FollowCursor) -> Bool {
        lhs.offset == rhs.offset && lhs.tail == rhs.tail && lhs.device == rhs.device && lhs.inode == rhs.inode &&
            lhs.modification.tv_sec == rhs.modification.tv_sec && lhs.modification.tv_nsec == rhs.modification.tv_nsec
    }
}

enum FollowAppendResult: Equatable {
    case unchanged
    case appended(String, FollowCursor)
    /// Rewritten, replaced, shrunk or undecodable: read the whole file again.
    case reload
    case limited
}

enum PreviewFileReader {
    struct Snapshot {
        let content: String
        let size: UInt64
        let modificationDate: Date?
        let isTruncated: Bool
        /// Present only for a complete, unwrapped read.
        let cursor: FollowCursor?
        /// For a tail window: where it starts in the file, and how many lines precede it.
        var startByte: UInt64 = 0
        var startLine = 0
    }
    static let previewLimit = 500 * 1024

    static func read(_ url: URL, limit: Int = previewLimit) throws -> Snapshot {
        var metadataURL = url
        metadataURL.removeAllCachedResourceValues()
        let values = try metadataURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey])
        guard values.isRegularFile == true else { throw CocoaError(.fileReadUnsupportedScheme) }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let data = try file.read(upToCount: limit + 1) ?? Data()
        let preview = try decode(data, limit: limit)
        var content = preview.content
        let wrapped = url.pathExtension.lowercased() == "mmd"
        if wrapped { content = "```mermaid\n\(content)\n```" }
        var status = stat()
        let cursor = !preview.isTruncated && !wrapped && fstat(file.fileDescriptor, &status) == 0
            ? FollowCursor(offset: UInt64(data.count), tail: data, status: status) : nil
        return Snapshot(content: content, size: UInt64(values.fileSize ?? data.count), modificationDate: values.contentModificationDate, isTruncated: preview.isTruncated, cursor: cursor)
    }

    /// Reads the end of a file, at most `window` bytes, starting at a line that is
    /// outside a top-level fenced code block and follows a blank line. Without such
    /// a line it starts at the first line outside a fence after the cut, then at the
    /// first line after the cut, then at the first character boundary after it.
    static func readTail(_ url: URL, window: Int) throws -> Snapshot {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var status = stat()
        guard fstat(file.fileDescriptor, &status) == 0 else { throw CocoaError(.fileReadUnknown) }
        guard status.st_mode & S_IFMT == S_IFREG else { throw CocoaError(.fileReadUnsupportedScheme) }
        let size = UInt64(status.st_size)
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
        guard let (text, used) = completePrefix(data) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        let cursor = FollowCursor(offset: chosen.byte + UInt64(used), tail: data.prefix(used), status: status)
        return Snapshot(content: text, size: size, modificationDate: Date(timeIntervalSince1970: TimeInterval(status.st_mtimespec.tv_sec)),
                        isTruncated: false, cursor: cursor, startByte: chosen.byte, startLine: chosen.line)
    }

    /// Moves a held tail window forward to at most `window` bytes, using only the text
    /// already held: it starts outside a fence, so no file read is needed. Returns nil
    /// when the text already fits or no line starts after the cut.
    static func reformWindow(_ text: String, startByte: UInt64, startLine: Int, window: Int) -> (text: String, startByte: UInt64, startLine: Int)? {
        let bytes = Data(text.utf8)
        guard bytes.count > window else { return nil }
        var finder = WindowStartFinder(cut: UInt64(bytes.count - window), size: UInt64(bytes.count))
        var scanner = MarkdownLineScanner()
        _ = bytes.withUnsafeBytes { raw in scanner.feed(raw) { finder.lineEnded(next: $0, wasBlank: $1, lines: $2, inFence: $3) } }
        guard let start = finder.start else { return nil }
        return (String(decoding: bytes.suffix(from: Int(start.byte)), as: UTF8.self), startByte + start.byte, startLine + start.line)
    }

    /// Reads only bytes added after `cursor`, after checking that the bytes before it are unchanged.
    static func readAppend(_ url: URL, after cursor: FollowCursor, limit: Int) throws -> FollowAppendResult {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var status = stat()
        guard fstat(file.fileDescriptor, &status) == 0 else { throw CocoaError(.fileReadUnknown) }
        guard status.st_mode & S_IFMT == S_IFREG else { throw CocoaError(.fileReadUnsupportedScheme) }
        guard UInt64(status.st_dev) == cursor.device, UInt64(status.st_ino) == cursor.inode else { return .reload }
        let size = UInt64(status.st_size)
        guard size >= cursor.offset else { return .reload }
        guard size <= UInt64(limit) else { return .limited }
        try file.seek(toOffset: cursor.offset - UInt64(cursor.tail.count))
        guard (try file.read(upToCount: cursor.tail.count) ?? Data()) == cursor.tail else { return .reload }
        if size == cursor.offset {
            let unchanged = status.st_mtimespec.tv_sec == cursor.modification.tv_sec && status.st_mtimespec.tv_nsec == cursor.modification.tv_nsec
            return unchanged ? .unchanged : .reload
        }
        let added = try file.read(upToCount: Int(size - cursor.offset)) ?? Data()
        // A writer may not have finished the final character yet; read it next time.
        guard let (text, used) = completePrefix(added) else { return .reload }
        if used == 0 { return .unchanged }
        return .appended(text, FollowCursor(offset: cursor.offset + UInt64(used), tail: cursor.tail + added.prefix(used), status: status))
    }

    static func decode(_ input: Data, limit: Int = previewLimit) throws -> (content: String, isTruncated: Bool) {
        let truncated = input.count > limit
        let data = Data(input.prefix(limit))
        let decoded = truncated ? completePrefix(data)?.text : String(data: data, encoding: .utf8)
        guard let content = decoded else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        return (content, truncated)
    }

    /// Decodes UTF-8, leaving out only an incomplete final character. A valid
    /// character has at most four bytes; malformed bytes are never concealed.
    private static func completePrefix(_ data: Data) -> (text: String, used: Int)? {
        if let text = String(data: data, encoding: .utf8) { return (text, data.count) }
        for removed in 1...min(3, data.count) {
            let prefix = data.dropLast(removed)
            let tail = Array(data.suffix(removed))
            let lead = tail.first ?? 0
            let expected = lead >= 0xC2 && lead <= 0xDF ? 2 : lead >= 0xE0 && lead <= 0xEF ? 3 : lead >= 0xF0 && lead <= 0xF4 ? 4 : 0
            if expected > removed && tail.dropFirst().allSatisfy({ $0 >= 0x80 && $0 <= 0xBF }),
               let text = String(data: prefix, encoding: .utf8) {
                return (text, prefix.count)
            }
        }
        return nil
    }
}
