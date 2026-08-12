import AppKit
import XCTest

final class QuickLookSystemAppearanceTests: XCTestCase {
    func testSystemModeUsesGlobalLightStyleWhenStyleKeyIsAbsent() {
        XCTAssertEqual(
            PreviewViewController.resolvedTheme(
                mode: .system,
                systemInterfaceStyle: nil
            ),
            "light"
        )
    }

    func testSystemModeTracksGlobalDarkStyle() {
        XCTAssertEqual(
            PreviewViewController.resolvedTheme(
                mode: .system,
                systemInterfaceStyle: "Dark"
            ),
            "dark"
        )
    }

    func testExplicitModesIgnoreGlobalSystemStyle() {
        XCTAssertEqual(
            PreviewViewController.resolvedTheme(
                mode: .light,
                systemInterfaceStyle: "Dark"
            ),
            "light"
        )
        XCTAssertEqual(
            PreviewViewController.resolvedTheme(
                mode: .dark,
                systemInterfaceStyle: nil
            ),
            "dark"
        )
    }

    func testSystemStyleMatchingIsCaseInsensitive() {
        XCTAssertEqual(
            PreviewViewController.resolvedTheme(
                mode: .system,
                systemInterfaceStyle: "dark"
            ),
            "dark"
        )
    }

    func testQuickLookAppliesResolvedAppearanceToWebView() throws {
        let source = try String(
            contentsOf: projectRoot()
                .appendingPathComponent("Sources/MarkdownPreview/PreviewViewController.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("self.webView?.appearance = appearance"))
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
