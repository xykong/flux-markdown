import XCTest
import WebKit

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
            3.0,
            accuracy: 0.001
        )
        XCTAssertEqual(
            NativeMagnifyingWebView.targetMagnification(current: 0.3, delta: -1.0),
            0.5,
            accuracy: 0.001
        )
    }

    func testReadingZoomDoesNotMagnifyTheWebView() {
        let view = NativeMagnifyingWebView(frame: .zero, configuration: WKWebViewConfiguration())
        view.readingZoom = 2
        XCTAssertEqual(view.readingZoom, 2)
        XCTAssertEqual(view.pageZoom, 1)
        XCTAssertEqual(view.magnification, 1)
        XCTAssertFalse(view.allowsMagnification)
        view.readingZoom = 10
        XCTAssertEqual(view.readingZoom, 3)
        view.readingZoom = 0.1
        XCTAssertEqual(view.readingZoom, 0.5)
        view.readingZoom = .nan
        XCTAssertEqual(view.readingZoom, 0.5)
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

    func testBothHostsShareReadingZoomGestureOwner() throws {
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
        XCTAssertFalse(quickLookSource.contains(".pageZoom ="))
        XCTAssertFalse(appSource.contains(".pageZoom ="))
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

@MainActor
private final class PinchRecordingWebView: NativeMagnifyingWebView {
    var scripts: [String] = []
    var replies: [((Any?, Error?) -> Void)?] = []
    override func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Void)? = nil) {
        scripts.append(javaScriptString); replies.append(completionHandler)
    }
}

private final class TestMagnificationGesture: NSMagnificationGestureRecognizer {
    var phase: NSGestureRecognizer.State = .began
    override var state: NSGestureRecognizer.State { get { phase } set { phase = newValue } }
    override func location(in view: NSView?) -> NSPoint { NSPoint(x:100,y:100) }
}

extension NativeMagnificationTests {
    func testDiagramReplyLeavesGlobalZoomUnchangedAndBodyReplyDoesNotEcho() {
        let view = PinchRecordingWebView(frame:NSRect(x:0,y:0,width:500,height:500), configuration:WKWebViewConfiguration())
        view.readingZoom = 2
        view.scripts.removeAll(); view.replies.removeAll()
        let gesture=TestMagnificationGesture()
        gesture.magnification = 0
        view.perform(NSSelectorFromString("handleNativeMagnification:"),with:gesture)
        gesture.phase = .changed;gesture.magnification = 0.5
        view.perform(NSSelectorFromString("handleNativeMagnification:"),with:gesture)
        XCTAssertEqual(view.scripts.count,2)
        XCTAssertTrue(view.scripts.allSatisfy { $0.hasPrefix("window.requestPinchZoom") })
        view.replies[0]?(NSNumber(value:1.1),nil) // Obsolete response must not win.
        XCTAssertEqual(view.readingZoom,2)
        view.replies[1]?(NSNull(),nil) // A diagram owns this gesture.
        XCTAssertEqual(view.readingZoom,2)
        gesture.magnification = 0.25
        view.perform(NSSelectorFromString("handleNativeMagnification:"),with:gesture)
        view.replies[2]?(NSNumber(value:2.5),nil)
        XCTAssertEqual(view.readingZoom,2.5)
        XCTAssertEqual(view.scripts.count,3) // Renderer state is absorbed, not sent back.
        XCTAssertEqual(view.pageZoom,1)
        XCTAssertEqual(view.magnification,1)
    }
}
