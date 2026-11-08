import XCTest

final class MarkdownImageDataCollectorTests: XCTestCase {

    func testSVGOnlyCollectionLeavesRasterImagesOnTheLocalScheme() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100%\" viewBox=\"0 0 586.5 1088\"><text>A</text></svg>"
        try Data(svg.utf8).write(to: root.appendingPathComponent("diagram.svg"))
        try Data([0x89,0x50,0x4e,0x47]).write(to: root.appendingPathComponent("image.png"))
        let images = MarkdownImageDataCollector.collectImageData(
            from: root.appendingPathComponent("test.md"),
            content: "![A](diagram.svg)\n![B](image.png)", fileExtensions: ["svg"])
        XCTAssertNotNil(images["diagram.svg"])
        XCTAssertNil(images["image.png"])
        XCTAssertEqual(images.count, 2, "Only the SVG and its ./ alias are included")
    }

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

    func testCollectsParentDirectoryHTMLImageAsDataURL() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let requirements = root.appendingPathComponent("requirements", isDirectory: true)
        let assets = root.appendingPathComponent("assets", isDirectory: true)
        try FileManager.default.createDirectory(at: requirements, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let imageURL = assets.appendingPathComponent("avatar.png")
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        try png.write(to: imageURL)

        let markdownURL = requirements.appendingPathComponent("avatars.md")
        let source = "../assets/avatar.png"
        let markdown = #"<img src="../assets/avatar.png" width="160" alt="Avatar">"#

        let imageData = MarkdownImageDataCollector.collectImageData(
            from: markdownURL,
            content: markdown
        )

        let dataURL = try XCTUnwrap(imageData[source])
        XCTAssertTrue(dataURL.hasPrefix("data:image/png;base64,"))
    }

    func testExtractsOnlyExplicitLocalImageReferences() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let requirements = root.appendingPathComponent("requirements", isDirectory: true)
        let assets = root.appendingPathComponent("assets", isDirectory: true)
        try FileManager.default.createDirectory(at: requirements, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let referencedURL = assets.appendingPathComponent("referenced.png")
        let unreferencedURL = assets.appendingPathComponent("unreferenced.png")
        try Data([0x89, 0x50]).write(to: referencedURL)
        try Data([0x89, 0x50]).write(to: unreferencedURL)

        let markdownURL = requirements.appendingPathComponent("avatars.md")
        let markdown = """
        <img src='../assets/referenced.png' alt='Referenced'>
        <img src="https://example.com/network.png" alt="Network">
        """

        let references = MarkdownImageDataCollector.referencedLocalImageURLs(
            from: markdownURL,
            content: markdown
        )

        XCTAssertEqual(references, Set([referencedURL.resolvingSymlinksInPath().standardizedFileURL]))
        XCTAssertFalse(references.contains(unreferencedURL.resolvingSymlinksInPath().standardizedFileURL))
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

    func testSkipsUnknownFileTypes() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let notes = root.appendingPathComponent("notes", isDirectory: true)
        try FileManager.default.createDirectory(at: notes, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "unknown".write(
            to: notes.appendingPathComponent("data.txt"),
            atomically: true,
            encoding: .utf8
        )

        let markdownURL = notes.appendingPathComponent("note.md")
        let markdown = """
        ![Unknown](data.txt)
        """

        let imageData = MarkdownImageDataCollector.collectImageData(
            from: markdownURL,
            content: markdown
        )

        XCTAssertTrue(imageData.isEmpty)
    }

    func testSkipsSymlinkedImageReference() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let notes = root.appendingPathComponent("notes", isDirectory: true)
        let outside = root.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.createDirectory(at: notes, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let outsideImage = outside.appendingPathComponent("secret.png")
        try Data([0x89, 0x50]).write(to: outsideImage)
        try FileManager.default.createSymbolicLink(
            at: notes.appendingPathComponent("linked.png"),
            withDestinationURL: outsideImage
        )

        let markdownURL = notes.appendingPathComponent("note.md")
        let markdown = "![Linked](linked.png)"

        let imageData = MarkdownImageDataCollector.collectImageData(
            from: markdownURL,
            content: markdown
        )
        let references = MarkdownImageDataCollector.referencedLocalImageURLs(
            from: markdownURL,
            content: markdown
        )

        XCTAssertTrue(imageData.isEmpty)
        XCTAssertTrue(references.isEmpty)
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

extension MarkdownImageDataCollectorTests {
    func testReferenceImagesAndParenthesizedNamesShareResourceBudget() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let image = root.appendingPathComponent("photo (1).png")
        try Data([1, 2, 3]).write(to: image)
        let markdown = "![one][pic]\n![two](<photo (1).png>)\n\n[pic]: <photo (1).png>"
        let document = root.appendingPathComponent("test.md")
        XCTAssertEqual(MarkdownImageDataCollector.referencedLocalImageURLs(from: document, content: markdown), [image])
        XCTAssertNotNil(MarkdownImageDataCollector.collectImageData(from: document, content: markdown)["photo (1).png"])
        let large = root.appendingPathComponent("large.png")
        try Data(repeating: 0, count: 2 * 1024 * 1024 + 1).write(to: large)
        XCTAssertEqual(MarkdownImageDataCollector.referencedLocalImageURLs(from: document, content: "![large](large.png)"), [large])
    }
}

final class LocalResourceDiagnosticsTests: XCTestCase {
    func testReadFailuresAreClassifiedWithoutPaths() {
        XCTAssertEqual(LocalResourceDiagnostics.category(CocoaError(.fileReadNoPermission)), "permission-denied")
        XCTAssertEqual(LocalResourceDiagnostics.category(CocoaError(.fileReadNoSuchFile)), "missing-file")
        XCTAssertEqual(LocalResourceDiagnostics.category(CocoaError(.fileReadTooLarge)), "resource-limit")
        XCTAssertEqual(LocalResourceDiagnostics.category(NSError(domain: NSPOSIXErrorDomain, code: 13)), "permission-denied")
    }
}
