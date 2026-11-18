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
    func testRewriteBeforeAnUnchangedTailThenAppendRefreshesHeadAndFollow() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".md")
        defer { try? FileManager.default.removeItem(at: url) }
        let initial = "OLD\n" + String(repeating: "x", count: 8192)
        try Data(initial.utf8).write(to: url)
        let before = try PreviewFileReader.read(url)
        XCTAssertEqual(try PreviewFileReader.revision(at: url), before.revision)

        let writer = try FileHandle(forWritingTo: url)
        defer { try? writer.close() }
        try writer.write(contentsOf: Data("NEW".utf8))
        try writer.seekToEnd()
        try writer.write(contentsOf: Data("\nAPPENDED\n".utf8))

        let head = try PreviewFileReader.read(url)
        let tail = try PreviewFileReader.readTail(url, window: 16_384)
        XCTAssertNotEqual(head.revision, before.revision)
        XCTAssertEqual(head.revision, tail.revision)
        XCTAssertTrue(head.content.hasPrefix("NEW"))
        XCTAssertEqual(head.content, tail.content)
        XCTAssertTrue(tail.content.hasSuffix("APPENDED\n"))
    }

    func testSameSizeReplacementWithCopiedModificationDateChangesRevision() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".md")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("old".utf8).write(to: url)
        let before = try PreviewFileReader.revision(at: url)
        let timestamp = try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        try Data("new".utf8).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.modificationDate: try XCTUnwrap(timestamp)], ofItemAtPath: url.path)
        XCTAssertNotEqual(try PreviewFileReader.revision(at: url), before)
    }

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
        XCTAssertEqual(MarkdownPreviewPolicy.readLimit(for: URL(fileURLWithPath: "/a/notes.md")), 2_097_152)
        XCTAssertEqual(MarkdownPreviewPolicy.readLimit(for: URL(fileURLWithPath: "/a/table.TSV")), 512_000)
        XCTAssertEqual(BoundedFileReader.documentLimit, 33_554_432, "The app keeps its own limit")
    }

    func testLimitsAreWholeMebibytes() {
        XCTAssertEqual(MarkdownPreviewPolicy.previewLimit % 1_048_576, 0)
    }

    func testMarkdownPreviewLimitBelowAtAndAbove() throws {
        let limit = MarkdownPreviewPolicy.previewLimit
        let url = temporaryFile("limit.md")
        defer { try? FileManager.default.removeItem(at: url) }
        for count in [limit - 1, limit, limit + 1] {
            try Data(repeating: 65, count: count).write(to: url)
            let snapshot = try PreviewFileReader.read(url, limit: MarkdownPreviewPolicy.readLimit(for: url))
            XCTAssertEqual(snapshot.content.utf8.count, min(count, limit), "size \(count)")
            XCTAssertEqual(snapshot.isTruncated, count > limit, "size \(count)")
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
            PreviewLimitNotice.limitedHeadStatus: ["%1$@", "%2$@"],
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
            XCTAssertEqual(snapshot.size, UInt64(size))
        }
    }

    func testOneByteOverTheWindowStartsAtTheNextSafeLine() throws {
        let text = "intro\n\n" + String(repeating: "para\n\n", count: 20)   // 7 + 120 bytes
        try write(text)
        let snapshot = try PreviewFileReader.readTail(url, window: text.utf8.count - 1)
        XCTAssertEqual(snapshot.startByte, 7)
        XCTAssertEqual(snapshot.startLine, 2)
        XCTAssertTrue(snapshot.content.hasPrefix("para\n"))
        XCTAssertEqual(snapshot.size, UInt64(text.utf8.count))
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
        XCTAssertEqual(snapshot.size, 14)
        let writer = try FileHandle(forWritingTo: url)
        try writer.seekToEnd(); try writer.write(contentsOf: Data(Array("😀".utf8).suffix(2)) + Data("!".utf8)); try writer.close()
        let updated = try PreviewFileReader.readTail(url, window: 32)
        XCTAssertTrue(updated.content.hasSuffix("body\n😀!"))
        XCTAssertNotEqual(updated.revision, snapshot.revision)
    }

    func testShrinkAndRewriteReloadTheTail() throws {
        try write("one\n\ntwo\n\nthree\n")
        let first = try PreviewFileReader.readTail(url, window: 8)
        try write("new\n\nend\n")
        let updated = try PreviewFileReader.readTail(url, window: 8)
        XCTAssertNotEqual(updated.revision, first.revision)
        XCTAssertEqual(updated.content, "end\n")
    }

    func testEditsBeforeAnUnchangedWindowUpdateItsSourceLine() throws {
        try write("line one\nline two\n\nlast\n")
        let before = try PreviewFileReader.readTail(url, window: 5)
        try write("line one line two\n\nlast\n")
        let after = try PreviewFileReader.readTail(url, window: 5)
        XCTAssertEqual(before.content, "last\n")
        XCTAssertEqual(after.content, before.content)
        XCTAssertEqual(after.startByte, before.startByte)
        XCTAssertEqual(after.startLine, before.startLine - 1)
        XCTAssertNotEqual(after.revision, before.revision)
    }

    func testMalformedBytesInTheWindowFail() throws {
        try Data(Data("ok\n\n".utf8) + Data([0x61, 0xff, 0x62, 0x0A])).write(to: url)
        XCTAssertThrowsError(try PreviewFileReader.readTail(url, window: 4))
    }
}
