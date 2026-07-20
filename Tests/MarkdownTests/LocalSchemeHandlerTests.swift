import XCTest

final class LocalSchemeHandlerTests: XCTestCase {

    func testResolveFilePathStripsQueryParameters() {
        let handler = LocalSchemeHandler()
        let url = URL(string: "local-md:///Users/me/docs/image.png?v=42")!
        let resolved = handler.resolveFilePath(from: url)
        XCTAssertEqual(resolved, "/Users/me/docs/image.png")
    }

    func testResolveFilePathPreservesPathWithoutQuery() {
        let handler = LocalSchemeHandler()
        let url = URL(string: "local-md:///Users/me/docs/image.png")!
        let resolved = handler.resolveFilePath(from: url)
        XCTAssertEqual(resolved, "/Users/me/docs/image.png")
    }

    func testResolveFilePathHandlesHostBasedURL() {
        let handler = LocalSchemeHandler()
        let url = URL(string: "local-md://Users/me/docs/image.png?v=1")!
        let resolved = handler.resolveFilePath(from: url)
        XCTAssertEqual(resolved, "/Users/me/docs/image.png")
    }

    func testResolveContainedFileURLAllowsFilesInsideBaseDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let assets = root.appendingPathComponent("assets", isDirectory: true)
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let imageURL = assets.appendingPathComponent("image.png")
        try Data([0x89, 0x50]).write(to: imageURL)

        let handler = LocalSchemeHandler()
        handler.baseDirectory = root

        let url = URL(string: "local-md://\(imageURL.path)")!
        let resolved = try XCTUnwrap(handler.resolveContainedFileURL(from: url))
        XCTAssertEqual(resolved.standardizedFileURL.path, imageURL.standardizedFileURL.path)
    }

    func testResolveContainedFileURLRejectsParentDirectoryTraversal() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let notes = root.appendingPathComponent("notes", isDirectory: true)
        try FileManager.default.createDirectory(at: notes, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let handler = LocalSchemeHandler()
        handler.baseDirectory = notes

        let url = URL(string: "local-md://\(notes.path)/../secret.png")!
        XCTAssertNil(handler.resolveContainedFileURL(from: url))
    }

    func testResolveContainedFileURLAllowsExplicitlyReferencedParentImageOnly() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let notes = root.appendingPathComponent("notes", isDirectory: true)
        let assets = root.appendingPathComponent("assets", isDirectory: true)
        try FileManager.default.createDirectory(at: notes, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let referencedImage = assets.appendingPathComponent("referenced.png")
        let unreferencedImage = assets.appendingPathComponent("unreferenced.png")
        try Data([0x89, 0x50]).write(to: referencedImage)
        try Data([0x89, 0x50]).write(to: unreferencedImage)

        let handler = LocalSchemeHandler()
        handler.baseDirectory = notes
        handler.allowedFileURLs = Set([referencedImage])

        let referencedURL = URL(string: "local-md://\(referencedImage.path)")!
        let unreferencedURL = URL(string: "local-md://\(unreferencedImage.path)")!

        XCTAssertEqual(
            handler.resolveContainedFileURL(from: referencedURL)?.standardizedFileURL,
            referencedImage.standardizedFileURL
        )
        XCTAssertNil(handler.resolveContainedFileURL(from: unreferencedURL))
    }

    func testResolveContainedFileURLRejectsEncodedParentDirectoryTraversal() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let notes = root.appendingPathComponent("notes", isDirectory: true)
        try FileManager.default.createDirectory(at: notes, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let handler = LocalSchemeHandler()
        handler.baseDirectory = notes

        let url = URL(string: "local-md://\(notes.path)/%2e%2e/secret.png")!
        XCTAssertNil(handler.resolveContainedFileURL(from: url))
    }

    func testResolveContainedFileURLRejectsSymlinkEscape() throws {
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

        let handler = LocalSchemeHandler()
        handler.baseDirectory = notes

        let url = URL(string: "local-md://\(notes.path)/linked.png")!
        XCTAssertNil(handler.resolveContainedFileURL(from: url))
    }

    func testBuildResponseIncludesCacheControlHeader() {
        let handler = LocalSchemeHandler()
        let url = URL(string: "local-md:///Users/me/docs/image.png?v=42")!
        let data = Data([0x89, 0x50, 0x4E, 0x47])
        let response = handler.buildResponse(for: url, data: data)

        guard let httpResponse = response as? HTTPURLResponse else {
            XCTFail("Expected HTTPURLResponse")
            return
        }

        XCTAssertEqual(httpResponse.value(forHTTPHeaderField: "Cache-Control"), "no-cache, no-store, must-revalidate")
    }

    func testBuildResponseSetsMimeType() {
        let handler = LocalSchemeHandler()
        let pngURL = URL(string: "local-md:///image.png")!
        let jpgURL = URL(string: "local-md:///photo.jpg")!
        let svgURL = URL(string: "local-md:///icon.svg")!

        let pngResp = handler.buildResponse(for: pngURL, data: Data()) as? HTTPURLResponse
        let jpgResp = handler.buildResponse(for: jpgURL, data: Data()) as? HTTPURLResponse
        let svgResp = handler.buildResponse(for: svgURL, data: Data()) as? HTTPURLResponse

        XCTAssertEqual(pngResp?.mimeType, "image/png")
        XCTAssertEqual(jpgResp?.mimeType, "image/jpeg")
        XCTAssertEqual(svgResp?.mimeType, "image/svg+xml")
    }
}
