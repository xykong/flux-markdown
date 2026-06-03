import XCTest

final class MarkdownImageDataCollectorTests: XCTestCase {

    func testCollectsRelativeMarkdownImageAsDataURL() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let assets = root.appendingPathComponent("assets", isDirectory: true)
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let imageURL = assets.appendingPathComponent("red.svg")
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\"><text>LOCAL IMAGE OK</text></svg>"
        try svg.data(using: .utf8)!.write(to: imageURL)

        let markdownURL = root.appendingPathComponent("note.md")
        let markdown = "![Local relative SVG](assets/red.svg)"
        try markdown.write(to: markdownURL, atomically: true, encoding: .utf8)

        let imageData = MarkdownImageDataCollector.collectImageData(
            from: markdownURL,
            content: markdown
        )

        let dataURL = try XCTUnwrap(imageData["assets/red.svg"])
        XCTAssertTrue(dataURL.hasPrefix("data:image/svg+xml;base64,"))

        let encoded = String(dataURL.dropFirst("data:image/svg+xml;base64,".count))
        let decoded = try XCTUnwrap(Data(base64Encoded: encoded))
        XCTAssertEqual(String(data: decoded, encoding: .utf8), svg)
    }

    func testSkipsNetworkEmbeddedAndAbsoluteImageReferences() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let markdownURL = root.appendingPathComponent("note.md")
        let markdown = """
        ![Network](https://example.com/image.png)
        ![Embedded](data:image/png;base64,abc)
        ![Absolute](/Users/me/image.png)
        ![File](file:///Users/me/image.png)
        """

        let imageData = MarkdownImageDataCollector.collectImageData(
            from: markdownURL,
            content: markdown
        )

        XCTAssertTrue(imageData.isEmpty)
    }

    func testSkipsParentDirectoryTraversalAndUnknownFileTypes() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let notes = root.appendingPathComponent("notes", isDirectory: true)
        try FileManager.default.createDirectory(at: notes, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "secret".write(
            to: root.appendingPathComponent("secret.png"),
            atomically: true,
            encoding: .utf8
        )
        try "unknown".write(
            to: notes.appendingPathComponent("data.txt"),
            atomically: true,
            encoding: .utf8
        )

        let markdownURL = notes.appendingPathComponent("note.md")
        let markdown = """
        ![Traversal](../secret.png)
        ![EncodedTraversal](%2e%2e/secret.png)
        ![Unknown](data.txt)
        """

        let imageData = MarkdownImageDataCollector.collectImageData(
            from: markdownURL,
            content: markdown
        )

        XCTAssertTrue(imageData.isEmpty)
    }

    func testSkipsImagesLargerThanPerImageLimit() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let imageURL = root.appendingPathComponent("large.png")
        try Data(repeating: 0xAB, count: 9).write(to: imageURL)

        let markdownURL = root.appendingPathComponent("note.md")
        let markdown = "![Large](large.png)"

        let imageData = MarkdownImageDataCollector.collectImageData(
            from: markdownURL,
            content: markdown,
            limits: MarkdownImageDataCollector.Limits(
                maxImageCount: 10,
                maxImageBytes: 8,
                maxTotalBytes: 100
            )
        )

        XCTAssertTrue(imageData.isEmpty)
    }

    func testStopsBeforeExceedingImageCountLimit() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data([1]).write(to: root.appendingPathComponent("one.png"))
        try Data([2]).write(to: root.appendingPathComponent("two.png"))

        let markdownURL = root.appendingPathComponent("note.md")
        let markdown = """
        ![One](one.png)
        ![Two](two.png)
        """

        let imageData = MarkdownImageDataCollector.collectImageData(
            from: markdownURL,
            content: markdown,
            limits: MarkdownImageDataCollector.Limits(
                maxImageCount: 1,
                maxImageBytes: 8,
                maxTotalBytes: 100
            )
        )

        XCTAssertNotNil(imageData["one.png"])
        XCTAssertNil(imageData["two.png"])
    }

    func testSkipsImagesThatWouldExceedTotalByteLimit() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data(repeating: 0x01, count: 5).write(to: root.appendingPathComponent("one.png"))
        try Data(repeating: 0x02, count: 5).write(to: root.appendingPathComponent("two.png"))

        let markdownURL = root.appendingPathComponent("note.md")
        let markdown = """
        ![One](one.png)
        ![Two](two.png)
        """

        let imageData = MarkdownImageDataCollector.collectImageData(
            from: markdownURL,
            content: markdown,
            limits: MarkdownImageDataCollector.Limits(
                maxImageCount: 10,
                maxImageBytes: 8,
                maxTotalBytes: 8
            )
        )

        XCTAssertNotNil(imageData["one.png"])
        XCTAssertNil(imageData["two.png"])
    }

    func testSkipsImageLargerThanTotalLimitEvenWhenPerImageLimitAllowsIt() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data(repeating: 0x01, count: 9).write(to: root.appendingPathComponent("too-large.png"))

        let markdownURL = root.appendingPathComponent("note.md")
        let markdown = "![TooLarge](too-large.png)"

        let imageData = MarkdownImageDataCollector.collectImageData(
            from: markdownURL,
            content: markdown,
            limits: MarkdownImageDataCollector.Limits(
                maxImageCount: 10,
                maxImageBytes: 100,
                maxTotalBytes: 8
            )
        )

        XCTAssertTrue(imageData.isEmpty)
    }
}
