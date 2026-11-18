import XCTest

final class PreviewFileReaderTests: XCTestCase {
    func testTSVBoundedDecodePreservesUTF8AndReportsExactBoundary() throws {
        let data = Data("a\tb\r\n中tail".utf8)
        let prefix = try PreviewFileReader.decode(data, limit: 7)
        XCTAssertEqual(prefix.content, "a\tb\r\n")
        XCTAssertTrue(prefix.isTruncated)
        XCTAssertFalse(try PreviewFileReader.decode(data, limit: data.count).isTruncated)
    }

    func testTruncationPreservesMultibytePrefix() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".md")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("hello中tail".utf8).write(to: url)
        let result = try PreviewFileReader.read(url, limit: 6)
        XCTAssertTrue(result.content.hasPrefix("hello"))
        XCTAssertTrue(result.isTruncated)
        XCTAssertFalse(result.content.contains("Preview truncated"))
        XCTAssertFalse(result.content.contains("Encoding Error"))
    }
    func testTruncationFlagClearsWhenFileFitsAndDoesNotMutateSource() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".md")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("```text\nabcdef".utf8).write(to: url)
        let original = try Data(contentsOf: url)
        XCTAssertTrue(try PreviewFileReader.read(url, limit: 10).isTruncated)
        XCTAssertFalse(try PreviewFileReader.read(url, limit: original.count).isTruncated)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
    func testMalformedUTF8FailsRatherThanSilentlyReplacingBytes() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data([0xff, 0x61]).write(to: url)
        XCTAssertThrowsError(try PreviewFileReader.read(url, limit: 100))
    }
    func testLocalImagesHaveBoundedReads() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("huge.png")
        try Data(repeating: 0, count: 33).write(to: url)
        XCTAssertThrowsError(try BoundedFileReader.read(url, maxBytes: 32))
        XCTAssertEqual(try BoundedFileReader.read(url, maxBytes: 33).count, 33)
    }
}

final class FollowFileSnapshotTests: XCTestCase {
    func testAppendReplacementAndLimitSnapshots() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("follow.md")
        try Data("before".utf8).write(to: url)
        let original = try PreviewFileReader.read(url, limit: 20)
        let writer = try FileHandle(forWritingTo: url)
        try writer.seekToEnd(); try writer.write(contentsOf: Data(" after".utf8)); try writer.close()
        let appended = try PreviewFileReader.read(url, limit: 20)
        XCTAssertTrue(appended.content.hasPrefix(original.content))
        XCTAssertEqual(appended.content, "before after")
        try Data("replacement".utf8).write(to: url, options: .atomic)
        XCTAssertEqual(try PreviewFileReader.read(url, limit: 20).content, "replacement")
        try Data(repeating: 65, count: 21).write(to: url)
        XCTAssertTrue(try PreviewFileReader.read(url, limit: 20).isTruncated)
    }
}

final class ProductionPreviewBoundaryTests: XCTestCase {
    func testActualAppDocumentLimitBelowAtAndAbove() throws {
        let limit = BoundedFileReader.documentLimit
        XCTAssertEqual(limit, 33_554_432)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".md")
        defer { try? FileManager.default.removeItem(at: url) }
        for count in [limit - 1, limit, limit + 1] {
            var source = Data(repeating: 65, count: count - "中文 😀".utf8.count)
            source.append(Data("中文 😀".utf8))
            try source.write(to: url)
            if count > limit {
                XCTAssertThrowsError(try BoundedFileReader.read(url, maxBytes: limit))
            } else {
                let result = try BoundedFileReader.read(url, maxBytes: limit)
                XCTAssertEqual(result, source)
                XCTAssertTrue(try XCTUnwrap(String(data: result, encoding: .utf8)).hasSuffix("中文 😀"))
            }
            XCTAssertEqual(try Data(contentsOf: url), source, "Bounded reads must preserve the original file")
        }
    }
    func testActualPreviewLimitBelowAtAndAbove() throws {
        let limit = PreviewFileReader.previewLimit
        XCTAssertEqual(limit, 512_000)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".md")
        defer { try? FileManager.default.removeItem(at: url) }
        for count in [0, limit - 1, limit, limit + 1] {
            try Data(repeating: 65, count: count).write(to: url)
            let snapshot = try PreviewFileReader.read(url)
            XCTAssertEqual(snapshot.content.utf8.count, min(count, limit), "size \(count)")
            XCTAssertEqual(snapshot.isTruncated, count > limit, "size \(count)")
            XCTAssertEqual(snapshot.size, UInt64(count))
        }
    }
    func testEveryMultibyteCutAtActualPreviewBoundary() throws {
        let limit = PreviewFileReader.previewLimit
        for scalar in ["é", "中", "😀"] {
            for retainedBytes in 1..<scalar.utf8.count {
                let prefix = String(repeating: "a", count: limit - retainedBytes)
                let input = Data((prefix + scalar + "tail").utf8)
                let result = try PreviewFileReader.decode(input)
                XCTAssertTrue(result.isTruncated)
                XCTAssertEqual(result.content, prefix)
            }
        }
        var malformed = Data(repeating: 65, count: limit + 1)
        malformed[100] = 0xff
        XCTAssertThrowsError(try PreviewFileReader.decode(malformed))
    }
    func testInputPartitionsMissingDirectoryEmptyAndMalformed() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try PreviewFileReader.read(root))
        let file = root.appendingPathComponent("input.md")
        XCTAssertThrowsError(try PreviewFileReader.read(file))
        try Data().write(to: file)
        XCTAssertEqual(try PreviewFileReader.read(file).content, "")
        try Data([0xff]).write(to: file)
        XCTAssertThrowsError(try PreviewFileReader.read(file))
    }
}

final class MarkdownPreviewPolicyTests: XCTestCase {
    private func temporaryFile(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + name)
    }

    func testMarkdownLimitsAreTwoMebibytesAndTSVKeepsItsOwn() {
        XCTAssertEqual(MarkdownPreviewPolicy.previewLimit, 2_097_152)
        XCTAssertEqual(MarkdownPreviewPolicy.followLimit, 2_097_152)
        XCTAssertEqual(MarkdownPreviewPolicy.readLimit(for: URL(fileURLWithPath: "/a/notes.md"), following: false), 2_097_152)
        XCTAssertEqual(MarkdownPreviewPolicy.readLimit(for: URL(fileURLWithPath: "/a/notes.md"), following: true), 2_097_152)
        XCTAssertEqual(MarkdownPreviewPolicy.readLimit(for: URL(fileURLWithPath: "/a/table.TSV"), following: false), 512_000)
        XCTAssertEqual(BoundedFileReader.documentLimit, 33_554_432, "The app keeps its own limit")
    }

    func testLimitsAreWholeMebibytes() {
        XCTAssertEqual(MarkdownPreviewPolicy.previewLimit % 1_048_576, 0)
        XCTAssertEqual(MarkdownPreviewPolicy.followLimit % 1_048_576, 0)
    }

    func testMarkdownPreviewLimitBelowAtAndAbove() throws {
        let limit = MarkdownPreviewPolicy.previewLimit
        let url = temporaryFile("limit.md")
        defer { try? FileManager.default.removeItem(at: url) }
        for count in [limit - 1, limit, limit + 1] {
            try Data(repeating: 65, count: count).write(to: url)
            let snapshot = try PreviewFileReader.read(url, limit: MarkdownPreviewPolicy.readLimit(for: url, following: false))
            XCTAssertEqual(snapshot.content.utf8.count, min(count, limit), "size \(count)")
            XCTAssertEqual(snapshot.isTruncated, count > limit, "size \(count)")
            XCTAssertEqual(snapshot.cursor == nil, count > limit, "Only a complete read can be followed by appends")
        }
    }

    func testEveryMultibyteCutAtMarkdownPreviewBoundary() throws {
        let limit = MarkdownPreviewPolicy.previewLimit
        for scalar in ["é", "中", "😀"] {
            for retainedBytes in 1..<scalar.utf8.count {
                let prefix = String(repeating: "a", count: limit - retainedBytes)
                let result = try PreviewFileReader.decode(Data((prefix + scalar + "tail").utf8), limit: limit)
                XCTAssertTrue(result.isTruncated)
                XCTAssertEqual(result.content, prefix)
            }
        }
    }

    func testEveryLocalizationNamesTheLimitAndPointsToFollow() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let notices = [
            PreviewLimitNotice.headStatus: ["%1$@", "%2$@"],
            PreviewLimitNotice.tailStatus: ["%1$@", "%2$@"],
        ]
        for target in ["Markdown", "MarkdownPreview"] {
            for language in ["en", "zh-Hans", "de", "fr", "es", "ar"] {
                let data = try Data(contentsOf: root.appendingPathComponent("Sources/\(target)/\(language).lproj/Localizable.strings"))
                let strings = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
                // The Follow button lives in the extension; both bundles name it the same way.
                let extensionData = try Data(contentsOf: root.appendingPathComponent("Sources/MarkdownPreview/\(language).lproj/Localizable.strings"))
                let extensionStrings = try XCTUnwrap(PropertyListSerialization.propertyList(from: extensionData, format: nil) as? [String: String])
                let follow = try XCTUnwrap(extensionStrings["Follow Changes"], "MarkdownPreview/\(language)")
                for (key, placeholders) in notices {
                    let value = try XCTUnwrap(strings[key], "\(target)/\(language): \(key)")
                    for placeholder in placeholders {
                        XCTAssertEqual(value.components(separatedBy: placeholder).count, 2, "\(target)/\(language): \(key)")
                    }
                    if key.contains("Follow Changes") { XCTAssertTrue(value.contains(follow), "\(target)/\(language) must name the Follow button") }
                }
                XCTAssertFalse(strings.keys.contains { $0.contains("500 KiB") || $0.hasPrefix("Preview limited to") || $0.hasPrefix("Click Follow Changes to see the end of the file") },
                               "\(target)/\(language) keeps a stale notice")
            }
        }
    }

    func testFollowWindowCeiling() {
        XCTAssertEqual(MarkdownPreviewPolicy.followWindowCeiling, 2_621_440, "The window may grow by a quarter before it re-forms")
    }
}

final class TailWindowReaderTests: XCTestCase {
    private var directory: URL!
    private var url: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent("stream.md")
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: directory) }

    private func write(_ text: String) throws { try Data(text.utf8).write(to: url) }
    private func lines(before byte: UInt64, in text: String) -> Int {
        Data(text.utf8).prefix(Int(byte)).filter { $0 == 0x0A }.count
    }

    func testFileWithinTheWindowIsReadWhole() throws {
        for size in [99, 100] {
            let text = String(repeating: "a\n", count: size / 2) + (size % 2 == 1 ? "b" : "")
            try write(text)
            let snapshot = try PreviewFileReader.readTail(url, window: 100)
            XCTAssertEqual(snapshot.content, text, "size \(size)")
            XCTAssertEqual(snapshot.startByte, 0); XCTAssertEqual(snapshot.startLine, 0)
            XCTAssertFalse(snapshot.isTruncated)
            XCTAssertEqual(snapshot.cursor?.offset, UInt64(size))
        }
    }

    func testOneByteOverTheWindowStartsAtTheNextSafeLine() throws {
        let text = "intro\n\n" + String(repeating: "para\n\n", count: 20)   // 7 + 120 bytes
        try write(text)
        let snapshot = try PreviewFileReader.readTail(url, window: text.utf8.count - 1)
        XCTAssertEqual(snapshot.startByte, 7)
        XCTAssertEqual(snapshot.startLine, 2)
        XCTAssertTrue(snapshot.content.hasPrefix("para\n"))
        XCTAssertEqual(snapshot.cursor?.offset, UInt64(text.utf8.count))
    }

    func testWindowNeverStartsInsideAFencedBlock() throws {
        let fence = "```text\n" + String(repeating: "code line\n\n", count: 30) + "```\n\n"
        let text = "# Start\n\n" + fence + "after the fence\n\nlast\n"
        try write(text)
        // A cut in the middle of the fence, where blank lines inside it look safe.
        let snapshot = try PreviewFileReader.readTail(url, window: text.utf8.count - 100)
        XCTAssertTrue(snapshot.content.hasPrefix("after the fence\n"), snapshot.content)
        XCTAssertEqual(snapshot.startLine, lines(before: snapshot.startByte, in: text))
    }

    func testFenceRules() throws {
        let cases: [(String, String)] = [
            ("~~~\n\nx\n\n~~~\n\n", "tilde fence"),
            ("````md\n\n```\n\nstill code\n\n````\n\n", "a shorter run does not close"),
            ("```\n\n``` not a close\n\n```\n\n", "a run with text after it does not close"),
            ("   ```\n\ncode\n\n   ```\n\n", "three leading spaces still fence"),
        ]
        for (fence, name) in cases {
            let text = "top\n\n" + fence + "TAIL\n"
            try write(text)
            let snapshot = try PreviewFileReader.readTail(url, window: text.utf8.count - 7)
            XCTAssertEqual(snapshot.content, "TAIL\n", name)
        }
        let indented = "top\n\n    ```\n\ninside four spaces\n"
        try write(indented)
        let snapshot = try PreviewFileReader.readTail(url, window: indented.utf8.count - 7)
        XCTAssertEqual(snapshot.content, "inside four spaces\n", "four spaces are indented code, not a fence")
    }

    func testFallbackWithoutABlankLineAndInsideAnUnclosedFence() throws {
        let noBlank = "a\nb\nc\nd\n"
        try write(noBlank)
        XCTAssertEqual(try PreviewFileReader.readTail(url, window: 5).content, "c\nd\n", "first line outside a fence")
        let unclosed = "```\nx\n\ny\n\nz\n"
        try write(unclosed)
        let snapshot = try PreviewFileReader.readTail(url, window: 6)
        XCTAssertEqual(snapshot.startByte, 6, "inside an unclosed fence: the first line after the cut")
        XCTAssertEqual(snapshot.content, "\ny\n\nz\n")
    }

    func testEveryUTF8CutInsideOneLongLine() throws {
        for scalar in ["é", "中", "😀"] {
            let text = String(repeating: scalar, count: 40)
            try write(text)
            for window in (text.utf8.count - 3 * scalar.utf8.count)..<(text.utf8.count - 2 * scalar.utf8.count) {
                let snapshot = try PreviewFileReader.readTail(url, window: window)
                XCTAssertTrue(text.hasSuffix(snapshot.content), "\(scalar) window \(window)")
                XCTAssertLessThanOrEqual(snapshot.content.utf8.count, window)
                XCTAssertGreaterThan(snapshot.content.utf8.count, window - scalar.utf8.count)
            }
        }
    }

    func testIncompleteFinalCharacterWaitsAndAppendsContinue() throws {
        try Data(Data("intro\n\nbody\n".utf8) + Data(Array("😀".utf8).prefix(2))).write(to: url)
        let snapshot = try PreviewFileReader.readTail(url, window: 8)
        XCTAssertEqual(snapshot.content, "body\n")
        let cursor = try XCTUnwrap(snapshot.cursor)
        XCTAssertEqual(cursor.offset, 12)
        let writer = try FileHandle(forWritingTo: url)
        try writer.seekToEnd(); try writer.write(contentsOf: Data(Array("😀".utf8).suffix(2)) + Data("!".utf8)); try writer.close()
        guard case .appended(let text, _) = try PreviewFileReader.readAppend(url, after: cursor, limit: 1_000) else { return XCTFail("expected append") }
        XCTAssertEqual(text, "😀!")
    }

    func testShrinkAndRewriteReloadTheTail() throws {
        try write("one\n\ntwo\n\nthree\n")
        let first = try PreviewFileReader.readTail(url, window: 8)
        try write("new\n\nend\n")
        XCTAssertEqual(try PreviewFileReader.readAppend(url, after: XCTUnwrap(first.cursor), limit: 1_000), .reload)
        XCTAssertEqual(try PreviewFileReader.readTail(url, window: 8).content, "end\n")
    }

    func testMalformedBytesInTheWindowFail() throws {
        try Data(Data("ok\n\n".utf8) + Data([0x61, 0xff, 0x62, 0x0A])).write(to: url)
        XCTAssertThrowsError(try PreviewFileReader.readTail(url, window: 4))
    }
}

final class FollowAppendReaderTests: XCTestCase {
    private var directory: URL!
    private var url: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent("follow.md")
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: directory) }

    private func append(_ data: Data) throws {
        let writer = try FileHandle(forWritingTo: url)
        try writer.seekToEnd(); try writer.write(contentsOf: data); try writer.close()
    }
    private func cursor() throws -> FollowCursor {
        try XCTUnwrap(PreviewFileReader.read(url, limit: 1_000_000).cursor)
    }

    func testReadsOnlyAppendedTextAndAdvances() throws {
        try Data("# Log\n\nfirst\n".utf8).write(to: url)
        let start = try cursor()
        XCTAssertEqual(try PreviewFileReader.readAppend(url, after: start, limit: 1_000), .unchanged)
        try append(Data("second\n".utf8))
        guard case .appended(let text, let next) = try PreviewFileReader.readAppend(url, after: start, limit: 1_000) else { return XCTFail("expected append") }
        XCTAssertEqual(text, "second\n")
        XCTAssertEqual(next.offset, start.offset + 7)
        XCTAssertEqual(try PreviewFileReader.readAppend(url, after: next, limit: 1_000), .unchanged)
        try append(Data("third".utf8))
        guard case .appended(let third, _) = try PreviewFileReader.readAppend(url, after: next, limit: 1_000) else { return XCTFail("expected append") }
        XCTAssertEqual(third, "third")
    }

    func testIncompleteCharacterWaitsForItsRemainingBytes() throws {
        try Data("start ".utf8).write(to: url)
        let start = try cursor()
        let emoji = Array("😀".utf8)
        try append(Data("a".utf8) + Data(emoji.prefix(2)))
        guard case .appended(let first, let middle) = try PreviewFileReader.readAppend(url, after: start, limit: 1_000) else { return XCTFail("expected append") }
        XCTAssertEqual(first, "a")
        XCTAssertEqual(try PreviewFileReader.readAppend(url, after: middle, limit: 1_000), .unchanged, "Only part of a character was written")
        try append(Data(emoji.suffix(2)) + Data("b".utf8))
        guard case .appended(let rest, _) = try PreviewFileReader.readAppend(url, after: middle, limit: 1_000) else { return XCTFail("expected append") }
        XCTAssertEqual(rest, "😀b")
    }

    func testRewritesShrinksReplacementsAndMalformedBytesNeedAFullRead() throws {
        try Data("0123456789\nabcdef\n".utf8).write(to: url)
        var start = try cursor()
        try Data("0123456789\nABCDEF\n".utf8).write(to: url, options: .atomic)
        XCTAssertEqual(try PreviewFileReader.readAppend(url, after: start, limit: 1_000), .reload, "Replaced file")

        start = try cursor()
        let handle = try FileHandle(forWritingTo: url)
        try handle.seek(toOffset: 12); try handle.write(contentsOf: Data("X".utf8)); try handle.close()
        XCTAssertEqual(try PreviewFileReader.readAppend(url, after: start, limit: 1_000), .reload, "Rewritten in place")

        start = try cursor()
        let truncating = try FileHandle(forWritingTo: url)
        try truncating.truncate(atOffset: 4); try truncating.close()
        XCTAssertEqual(try PreviewFileReader.readAppend(url, after: start, limit: 1_000), .reload, "Shrunk")

        start = try cursor()
        try append(Data([0x61, 0xff, 0x62]))
        XCTAssertEqual(try PreviewFileReader.readAppend(url, after: start, limit: 1_000), .reload, "Malformed bytes are reported by a full read")
    }

    func testFollowLimitBelowAtAndAbove() throws {
        try Data(repeating: 65, count: 10).write(to: url)
        let start = try cursor()
        try append(Data(repeating: 66, count: 10))
        for limit in [21, 20] {
            guard case .appended(let text, _) = try PreviewFileReader.readAppend(url, after: start, limit: limit) else { return XCTFail("limit \(limit)") }
            XCTAssertEqual(text, String(repeating: "B", count: 10))
        }
        XCTAssertEqual(try PreviewFileReader.readAppend(url, after: start, limit: 19), .limited)
    }

    func testMermaidFilesAndTruncatedReadsCannotAppend() throws {
        let mermaid = directory.appendingPathComponent("chart.mmd")
        try Data("graph TD; A-->B\n".utf8).write(to: mermaid)
        XCTAssertNil(try PreviewFileReader.read(mermaid, limit: 1_000).cursor)
        try Data(repeating: 65, count: 11).write(to: url)
        XCTAssertNil(try PreviewFileReader.read(url, limit: 10).cursor)
    }
}

final class SlidingWindowTests: XCTestCase {
    func testPolicyReformsPastTheCeilingAndHoldsWhilePaused() {
        XCTAssertEqual(MarkdownPreviewPolicy.pausedWindowCeiling, 4 * 1024 * 1024)
        XCTAssertEqual(MarkdownPreviewPolicy.appendLimit(windowStart: 100), 100 + 4 * 1024 * 1024)
        let ceiling = MarkdownPreviewPolicy.followWindowCeiling
        XCTAssertFalse(MarkdownPreviewPolicy.shouldReform(heldBytes: ceiling, paused: false))
        XCTAssertTrue(MarkdownPreviewPolicy.shouldReform(heldBytes: ceiling + 1, paused: false))
        XCTAssertFalse(MarkdownPreviewPolicy.shouldReform(heldBytes: ceiling + 1, paused: true), "a paused window never moves")
        XCTAssertEqual(MarkdownPreviewPolicy.overLimitStep(paused: true), .hold)
        XCTAssertEqual(MarkdownPreviewPolicy.overLimitStep(paused: false), .reread)
    }

    func testReformStartsAtASafeLineAndKeepsFileLineNumbers() throws {
        let held = "intro\n\n```text\n" + String(repeating: "code\n\n", count: 20) + "```\n\nafter\n\nend\n"
        let reformed = try XCTUnwrap(PreviewFileReader.reformWindow(held, startByte: 1_000, startLine: 50, window: 30))
        XCTAssertEqual(reformed.text, "after\n\nend\n", "never inside the fence")
        let skipped = held.utf8.count - reformed.text.utf8.count
        XCTAssertEqual(reformed.startByte, 1_000 + UInt64(skipped))
        XCTAssertEqual(reformed.startLine, 50 + held.utf8.prefix(skipped).filter { $0 == 0x0A }.count)
        XCTAssertNil(PreviewFileReader.reformWindow("short\n", startByte: 0, startLine: 0, window: 100), "already within the window")
    }

    /// Three MiB appended in small writes: the held window never passes the ceiling
    /// and always equals the file from its start byte, with the file's line number.
    func testLongStreamOfAppendsKeepsABoundedWindowThatMatchesTheFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".md")
        defer { try? FileManager.default.removeItem(at: url) }
        func block(_ i: Int) -> String { "## Turn \(i)\n\ntext \(i) " + String(repeating: "x", count: 900) + "\n\n```text\nlog \(i)\n\nmore\n```\n\n" }
        var initial = ""
        var i = 0
        while initial.utf8.count < 1_048_576 { initial += block(i); i += 1 }
        try Data(initial.utf8).write(to: url)
        let first = try PreviewFileReader.readTail(url, window: MarkdownPreviewPolicy.followLimit)
        var held = first.content, start = first.startByte, line = first.startLine
        var cursor = try XCTUnwrap(first.cursor)
        var appended = 0, reforms = 0
        while appended < 3 * 1_048_576 {
            var chunk = ""
            while chunk.utf8.count < 64 * 1024 { chunk += block(i); i += 1 }
            let writer = try FileHandle(forWritingTo: url)
            try writer.seekToEnd(); try writer.write(contentsOf: Data(chunk.utf8)); try writer.close()
            appended += chunk.utf8.count
            guard case .appended(let text, let next) = try PreviewFileReader.readAppend(url, after: cursor, limit: MarkdownPreviewPolicy.appendLimit(windowStart: start)) else { return XCTFail("expected append") }
            held += text; cursor = next
            if MarkdownPreviewPolicy.shouldReform(heldBytes: held.utf8.count, paused: false),
               let reformed = PreviewFileReader.reformWindow(held, startByte: start, startLine: line, window: MarkdownPreviewPolicy.followLimit) {
                held = reformed.text; start = reformed.startByte; line = reformed.startLine; reforms += 1
            }
            XCTAssertLessThanOrEqual(held.utf8.count, MarkdownPreviewPolicy.followWindowCeiling)
        }
        XCTAssertGreaterThan(reforms, 0)
        let file = try Data(contentsOf: url)
        XCTAssertEqual(Data(held.utf8), file.suffix(from: Int(start)))
        XCTAssertEqual(line, file.prefix(Int(start)).filter { $0 == 0x0A }.count)
        let before = String(decoding: file.prefix(Int(start)), as: UTF8.self)
        XCTAssertEqual(before.split(separator: "\n", omittingEmptySubsequences: false).filter { $0.hasPrefix("```") }.count % 2, 0,
                       "a re-formed window never starts inside a fence")
    }
}
