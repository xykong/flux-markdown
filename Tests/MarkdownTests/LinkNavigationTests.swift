import XCTest

final class LinkNavigationTests: XCTestCase {

    // MARK: - resolveLocalURL(href:relativeTo:) tests

    func testResolvesPercentEncodedSpacesInRelativeHref() {
        let baseFileURL = URL(fileURLWithPath: "/Users/me/docs/index.md")
        let href = "file%20with%20spaces.md"

        let result = LinkNavigation.resolveLocalURL(href: href, relativeTo: baseFileURL)

        XCTAssertNotNil(result, "Should resolve a valid percent-encoded relative href")
        XCTAssertEqual(result?.path, "/Users/me/docs/file with spaces.md",
                       "Percent-encoded spaces (%20) must be decoded to actual spaces in the path")
    }

    func testResolvesPercentEncodedSpacesInDirectoryComponent() {
        let baseFileURL = URL(fileURLWithPath: "/Users/me/docs/index.md")
        let href = "my%20folder/notes.md"

        let result = LinkNavigation.resolveLocalURL(href: href, relativeTo: baseFileURL)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.path, "/Users/me/docs/my folder/notes.md",
                       "Percent-encoded spaces in directory components must be decoded")
    }

    func testResolvesPlainRelativeHref() {
        let baseFileURL = URL(fileURLWithPath: "/Users/me/docs/index.md")
        let href = "notes.md"

        let result = LinkNavigation.resolveLocalURL(href: href, relativeTo: baseFileURL)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.path, "/Users/me/docs/notes.md")
    }

    func testResolvesRelativeHrefWithDotSlash() {
        let baseFileURL = URL(fileURLWithPath: "/Users/me/docs/index.md")
        let href = "./subdir/notes.md"

        let result = LinkNavigation.resolveLocalURL(href: href, relativeTo: baseFileURL)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.path, "/Users/me/docs/subdir/notes.md")
    }

    func testResolvesRelativeHrefWithParentDir() {
        let baseFileURL = URL(fileURLWithPath: "/Users/me/docs/subdir/index.md")
        let href = "../other.md"

        let result = LinkNavigation.resolveLocalURL(href: href, relativeTo: baseFileURL)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.path, "/Users/me/docs/other.md")
    }

    func testResolvesAbsoluteHref() {
        let baseFileURL = URL(fileURLWithPath: "/Users/me/docs/index.md")
        let href = "/tmp/absolute.md"

        let result = LinkNavigation.resolveLocalURL(href: href, relativeTo: baseFileURL)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.path, "/tmp/absolute.md")
    }

    func testReturnsNilForPureAnchorHref() {
        let baseFileURL = URL(fileURLWithPath: "/Users/me/docs/index.md")
        let href = "#section"

        let result = LinkNavigation.resolveLocalURL(href: href, relativeTo: baseFileURL)

        XCTAssertNil(result, "A pure anchor href should return nil (JS handles it)")
    }

    func testReturnsNilForEmptyHref() {
        let baseFileURL = URL(fileURLWithPath: "/Users/me/docs/index.md")
        let href = ""

        let result = LinkNavigation.resolveLocalURL(href: href, relativeTo: baseFileURL)

        XCTAssertNil(result, "Empty href should return nil")
    }

    func testResolvesFileURLScheme() {
        let baseFileURL = URL(fileURLWithPath: "/Users/me/docs/index.md")
        let href = "file:///Users/me/other/notes.md"

        let result = LinkNavigation.resolveLocalURL(href: href, relativeTo: baseFileURL)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.path, "/Users/me/other/notes.md")
    }

    func testExtractsFragmentFromPercentEncodedHref() {
        let baseFileURL = URL(fileURLWithPath: "/Users/me/docs/index.md")
        let href = "my%20notes.md#introduction"

        let target = LinkNavigation.resolveLocalLink(href: href, relativeTo: baseFileURL)

        XCTAssertNotNil(target?.url)
        XCTAssertEqual(target?.url.path, "/Users/me/docs/my notes.md",
                       "Path with %20 and fragment must decode correctly")
        XCTAssertEqual(target?.fragment, "introduction")
    }

    func testExtractsFragmentFromPlainHref() {
        let baseFileURL = URL(fileURLWithPath: "/Users/me/docs/index.md")
        let href = "notes.md#section-one"

        let target = LinkNavigation.resolveLocalLink(href: href, relativeTo: baseFileURL)

        XCTAssertNotNil(target?.url)
        XCTAssertEqual(target?.url.path, "/Users/me/docs/notes.md")
        XCTAssertEqual(target?.fragment, "section-one")
    }

    func testExtractsNilFragmentWhenNoAnchor() {
        let baseFileURL = URL(fileURLWithPath: "/Users/me/docs/index.md")
        let href = "my%20notes.md"

        let target = LinkNavigation.resolveLocalLink(href: href, relativeTo: baseFileURL)

        XCTAssertNotNil(target?.url)
        XCTAssertEqual(target?.url.path, "/Users/me/docs/my notes.md")
        XCTAssertNil(target?.fragment)
    }

    // MARK: - Multiple encoded characters

    func testResolvesMultiplePercentEncodedCharacters() {
        let baseFileURL = URL(fileURLWithPath: "/Users/me/docs/index.md")
        let href = "file%20name%20%28version%201%29.md"

        let result = LinkNavigation.resolveLocalURL(href: href, relativeTo: baseFileURL)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.path, "/Users/me/docs/file name (version 1).md",
                       "All percent-encoded characters must be decoded")
    }

    func testResolvesChineseChracterInPercentEncodedHref() {
        let baseFileURL = URL(fileURLWithPath: "/Users/me/docs/index.md")
        let href = "%E8%AE%BE%E8%AE%A1%E6%96%87%E6%A1%A3.md"

        let result = LinkNavigation.resolveLocalURL(href: href, relativeTo: baseFileURL)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.path, "/Users/me/docs/设计文档.md",
                       "Percent-encoded non-ASCII characters must be decoded correctly")
    }
}
