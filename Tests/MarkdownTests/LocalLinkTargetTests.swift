import XCTest

/// Editor-style `path:line[:column]` link targets (issue #71).
final class LocalLinkTargetTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("local-link-target-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    private var documentURL: URL { directory.appendingPathComponent("doc.md") }

    @discardableResult
    private func makeFile(_ name: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "content\n".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Plain local links keep working

    func testResolvesExistingFileWithoutSuffix() throws {
        let file = try makeFile("Foo.java")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "Foo.java", relativeTo: documentURL))

        XCTAssertEqual(target.url.path, file.path)
        XCTAssertNil(target.line)
        XCTAssertNil(target.fragment)
    }

    func testKeepsAnchorFragmentForMarkdownTarget() throws {
        try makeFile("notes.md")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "notes.md#section", relativeTo: documentURL))

        XCTAssertEqual(target.url.lastPathComponent, "notes.md")
        XCTAssertEqual(target.fragment, "section")
        XCTAssertNil(target.line)
    }

    // MARK: - Line suffix support

    func testStripsEditorLineSuffixWhenBaseFileExists() throws {
        let file = try makeFile("Foo.java")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "Foo.java:57", relativeTo: documentURL))

        XCTAssertEqual(target.url.path, file.path, "The `:57` suffix must not become part of the file name")
        XCTAssertEqual(target.line, 57)
    }

    func testStripsLineAndColumnSuffix() throws {
        let file = try makeFile("Foo.java")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "Foo.java:57:12", relativeTo: documentURL))

        XCTAssertEqual(target.url.path, file.path)
        XCTAssertEqual(target.line, 57, "The first number is the line; the second is the column")
    }

    func testStripsSuffixForPercentEncodedAbsoluteHref() throws {
        let file = try makeFile("设计/文件.java")
        let href = file.path
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)! + ":57"

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: href, relativeTo: documentURL))

        XCTAssertEqual(target.url.path, file.path)
        XCTAssertEqual(target.line, 57)
    }

    func testStripsSuffixForMarkdownTargetAndKeepsFragment() throws {
        try makeFile("notes.md")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "./notes.md:12#section", relativeTo: documentURL))

        XCTAssertEqual(target.url.lastPathComponent, "notes.md")
        XCTAssertEqual(target.line, 12)
        XCTAssertEqual(target.fragment, "section")
    }

    // MARK: - Precision: only strip when the literal target is missing and the base exists

    func testPrefersLiteralFileThatReallyContainsTheSuffix() throws {
        let literal = try makeFile("Foo.java:57")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "Foo.java:57", relativeTo: documentURL))

        XCTAssertEqual(target.url.path, literal.path)
        XCTAssertNil(target.line)
    }

    func testKeepsRawTargetWhenNeitherLiteralNorBaseFileExists() {
        let target = LinkNavigation.resolveLocalLink(href: "Missing.java:57", relativeTo: documentURL)

        XCTAssertEqual(target?.url.lastPathComponent, "Missing.java:57",
                       "An unresolved target must stay untouched so the failure can be reported")
        XCTAssertNil(target?.line)
    }

    func testKeepsRawTargetForNonNumericSuffix() throws {
        try makeFile("Foo.java")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "Foo.java:beta", relativeTo: documentURL))

        XCTAssertEqual(target.url.lastPathComponent, "Foo.java:beta")
        XCTAssertNil(target.line)
    }

    func testKeepsRawTargetForZeroLine() throws {
        try makeFile("Foo.java")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "Foo.java:0", relativeTo: documentURL))

        XCTAssertEqual(target.url.lastPathComponent, "Foo.java:0")
        XCTAssertNil(target.line)
    }

    func testKeepsRawTargetForNonNumericColumn() throws {
        try makeFile("Foo.java")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "Foo.java:57:beta", relativeTo: documentURL))

        XCTAssertEqual(target.url.lastPathComponent, "Foo.java:57:beta")
        XCTAssertNil(target.line)
    }

    func testKeepsRawTargetForOverlongNumber() throws {
        try makeFile("Foo.java")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "Foo.java:12345678", relativeTo: documentURL))

        XCTAssertNil(target.line, "Absurd line numbers must not be treated as source references")
    }

    func testDirectoryOnlyTargetIsNotStripped() throws {
        try makeFile("folder/notes.md")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "folder:12", relativeTo: documentURL))

        XCTAssertNil(target.line, "A bare directory name must not be split into a file reference")
    }

    // MARK: - What clicking decides

    func testMarkdownLineSuffixNavigatesToSourceLineInsideFluxMarkdown() throws {
        try makeFile("notes.md")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "notes.md:12", relativeTo: documentURL))

        XCTAssertEqual(LinkNavigation.action(for: target), .openFluxMarkdown(.line(12)))
    }

    func testMarkdownAnchorStillNavigatesToTheHeading() throws {
        try makeFile("notes.md")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "notes.md#section", relativeTo: documentURL))

        XCTAssertEqual(LinkNavigation.action(for: target), .openFluxMarkdown(.anchor("section")))
    }

    func testMarkdownTargetWithoutPositionOpensTheDocument() throws {
        try makeFile("notes.md")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "notes.md", relativeTo: documentURL))

        XCTAssertEqual(LinkNavigation.action(for: target), .openFluxMarkdown(nil))
    }

    func testSourceFileLineSuffixOpensTheFileExternally() throws {
        try makeFile("Foo.java")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "Foo.java:57", relativeTo: documentURL))

        XCTAssertEqual(LinkNavigation.action(for: target), .openExternally)
    }

    func testTSVTargetIsHandledAsADocument() throws {
        try makeFile("data.tsv")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "data.tsv:3", relativeTo: documentURL))

        XCTAssertEqual(LinkNavigation.action(for: target), .openFluxMarkdown(.line(3)))
    }

    // MARK: - Clipboard text for failed destinations

    func testClipboardTextUsesPlainPathForLocalFiles() {
        let url = URL(fileURLWithPath: "/Users/me/docs/设计 文档.java")

        XCTAssertEqual(LinkNavigation.clipboardText(for: url), "/Users/me/docs/设计 文档.java")
    }

    func testClipboardTextUsesFullURLForRemoteDestinations() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/a?b=c"))

        XCTAssertEqual(LinkNavigation.clipboardText(for: url), "https://example.com/a?b=c")
    }
}
