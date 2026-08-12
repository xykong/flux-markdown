import XCTest

@MainActor
final class NativeMagnificationTests: XCTestCase {
    func testMagnificationDeltaScalesCurrentValue() {
        XCTAssertEqual(
            NativeMagnifyingWebView.targetMagnification(current: 1.5, delta: 0.2),
            1.8,
            accuracy: 0.001
        )
    }

    func testMagnificationClampsToSupportedRange() {
        XCTAssertEqual(
            NativeMagnifyingWebView.targetMagnification(current: 4.9, delta: 1.0),
            5.0,
            accuracy: 0.001
        )
        XCTAssertEqual(
            NativeMagnifyingWebView.targetMagnification(current: 0.3, delta: -1.0),
            0.25,
            accuracy: 0.001
        )
    }

    func testControlWheelRoutesToNativeScrollInsteadOfWebContentZoom() {
        XCTAssertTrue(
            NativeMagnifyingWebView.shouldRouteControlWheelAsScroll([.control])
        )
        XCTAssertFalse(
            NativeMagnifyingWebView.shouldRouteControlWheelAsScroll([.command])
        )
        XCTAssertFalse(
            NativeMagnifyingWebView.shouldRouteControlWheelAsScroll([.control, .command])
        )
    }

    func testBothHostsUseNativeMagnifyingWebViewWithoutJavaScriptZoomBridges() throws {
        let root = projectRoot()
        let quickLookSource = try String(
            contentsOf: root.appendingPathComponent("Sources/MarkdownPreview/PreviewViewController.swift"),
            encoding: .utf8
        )
        let appSource = try String(
            contentsOf: root.appendingPathComponent("Sources/Markdown/MarkdownWebView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(quickLookSource.contains("class InteractiveWebView: NativeMagnifyingWebView"))
        XCTAssertTrue(appSource.contains("class ResizableWKWebView: NativeMagnifyingWebView"))
        XCTAssertFalse(quickLookSource.contains("name: \"pinchZoom\""))
        XCTAssertFalse(quickLookSource.contains("name: \"gestureZoom\""))
        XCTAssertFalse(appSource.contains("name: \"pinchZoom\""))
        XCTAssertFalse(appSource.contains("name: \"gestureZoom\""))
    }
}

private func projectRoot() -> URL {
    URL(fileURLWithPath: #file)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
