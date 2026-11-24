import AppKit
import WebKit
import XCTest

@MainActor
final class QuickLookGestureArbitrationTests: XCTestCase {
    func testDoubleClickRecognizerCannotPreventWebViewPan() throws {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let recognizer = QuickLookDoubleClickGestureRecognizer()
        // WebKit exposes a pan recognizer on newer macOS releases, but not on
        // every supported OS. Test arbitration unconditionally, plus every
        // native WebKit pan recognizer that this runtime actually exposes.
        let pans = [NSPanGestureRecognizer()] + webView.gestureRecognizers.compactMap { $0 as? NSPanGestureRecognizer }
        for panRecognizer in pans {
            XCTAssertFalse(
                recognizer.canPrevent(panRecognizer),
                "Quick Look double-click interception must not block WebKit scrollbar dragging"
            )
        }
    }

    func testWebViewPanCanCancelPendingDoubleClickRecognition() {
        let recognizer = QuickLookDoubleClickGestureRecognizer()
        let panRecognizer = NSPanGestureRecognizer()

        XCTAssertTrue(
            panRecognizer.canPrevent(recognizer),
            "A real drag must cancel pending double-click recognition"
        )
    }

    func testDoubleClickConfigurationKeepsPrimaryDragEventsImmediate() {
        let recognizer = QuickLookDoubleClickGestureRecognizer()
        recognizer.numberOfClicksRequired = 2
        recognizer.delaysPrimaryMouseButtonEvents = false

        XCTAssertEqual(recognizer.numberOfClicksRequired, 2)
        XCTAssertFalse(recognizer.delaysPrimaryMouseButtonEvents)
    }

    func testQuickLookInstallsNonBlockingDoubleClickRecognizer() throws {
        let source = try String(
            contentsOf: projectRoot()
                .appendingPathComponent("Sources/MarkdownPreview/PreviewViewController.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(
            source.contains("let doubleClickGesture = QuickLookDoubleClickGestureRecognizer("),
            "Quick Look must install the recognizer whose arbitration preserves WebKit pan gestures"
        )
    }

    func testDoubleClickRecognizerPreservesWebViewSelectionRecognizersButBlocksHost() {
        let hostView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let webView = InteractiveWebView(frame: hostView.bounds, configuration: WKWebViewConfiguration())
        let innerView = NSView(frame: webView.bounds)
        webView.addSubview(innerView)
        hostView.addSubview(webView)

        let recognizer = QuickLookDoubleClickGestureRecognizer()
        let siblingClick = NSClickGestureRecognizer()
        let innerPress = NSPressGestureRecognizer()
        let hostClick = NSClickGestureRecognizer()

        webView.addGestureRecognizer(recognizer)
        webView.addGestureRecognizer(siblingClick)
        innerView.addGestureRecognizer(innerPress)
        hostView.addGestureRecognizer(hostClick)

        XCTAssertFalse(
            recognizer.canPrevent(siblingClick),
            "Quick Look double-click guard must not prevent WebView word/paragraph selection clicks"
        )
        XCTAssertFalse(
            recognizer.canPrevent(innerPress),
            "Quick Look double-click guard must not prevent descendant WebView recognizers"
        )
        XCTAssertTrue(
            recognizer.canPrevent(hostClick),
            "Quick Look double-click guard must still prevent host-level double-click-to-open"
        )
        XCTAssertFalse(
            webView.mouseDownCanMoveWindow,
            "Dragging inside InteractiveWebView must select text rather than move the Quick Look panel"
        )
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
