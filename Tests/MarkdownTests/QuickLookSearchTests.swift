import AppKit
import WebKit
import XCTest

@MainActor
final class QuickLookSearchTests: XCTestCase {
    private final class OpenRecorder { var urls: [URL] = [] }
    private final class RecordingWebView: InteractiveWebView {
        var scripts: [String] = []
        override func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Void)? = nil) {
            scripts.append(javaScriptString)
            completionHandler?(nil, nil)
        }
    }

    private func event(_ key: String = "f", flags: NSEvent.ModifierFlags = .command, window: Int = 0) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                        timestamp: 0, windowNumber: window, context: nil,
                        characters: key, charactersIgnoringModifiers: key,
                        isARepeat: false, keyCode: 3)!
    }

    private func controller() -> (PreviewViewController, RecordingWebView, OpenRecorder) {
        let controller = PreviewViewController(nibName: nil, bundle: nil)
        controller.view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let webView = RecordingWebView(frame: controller.view.bounds, configuration: WKWebViewConfiguration())
        controller.webView = webView
        controller.view.addSubview(webView)
        let opened = OpenRecorder()
        controller.currentURL = URL(fileURLWithPath: "/tmp/test.md")
        controller.searchDocumentOpener = { url, completion in opened.urls.append(url); completion(true) }
        return (controller, webView, opened)
    }

    func testControllerFindOpensSearchIdempotently() {
        let (controller, webView, opened) = controller()
        controller.isWebViewLoaded = true
        controller.isSearchReady = true
        XCTAssertTrue(controller.performKeyEquivalent(with: event()))
        XCTAssertTrue(controller.performKeyEquivalent(with: event("F", flags: [.command, .capsLock])))
        XCTAssertEqual(opened.urls.count, 2)
        XCTAssertTrue(opened.urls.allSatisfy { DocumentOpenRequest(url: $0)?.wantsSearch == true })
        XCTAssertTrue(webView.scripts.isEmpty)
    }

    func testWebViewHandlesFindWithoutRelyingOnDOMDelivery() {
        let webView = RecordingWebView(frame: .zero, configuration: WKWebViewConfiguration())
        var calls = 0
        webView.searchShortcutHandler = { calls += 1 }
        XCTAssertTrue(webView.performKeyEquivalent(with: event()))
        XCTAssertEqual(calls, 1)
        XCTAssertFalse(webView.performKeyEquivalent(with: event(flags: [.command, .shift])))
        XCTAssertFalse(webView.performKeyEquivalent(with: event(flags: [])))
        XCTAssertEqual(calls, 1)
    }


    func testEarlyRequestWaitsForFileAndDoesNotDependOnPreviewRenderer() {
        let (controller, webView, opened) = controller()
        controller.currentURL = nil
        XCTAssertTrue(controller.performKeyEquivalent(with: event()))
        XCTAssertTrue(webView.scripts.isEmpty)
        controller.isWebViewLoaded = true
        controller.completePendingSearchRequest()
        XCTAssertTrue(opened.urls.isEmpty)
        controller.currentURL = URL(fileURLWithPath: "/tmp/test.md")
        controller.completePendingSearchRequest()
        XCTAssertEqual(opened.urls.count, 1)
        controller.completePendingSearchRequest()
        XCTAssertEqual(opened.urls.count, 1)
        XCTAssertTrue(webView.scripts.isEmpty)
    }

    func testLocalMonitorConsumesOwnEventAndLeavesOtherWindowsAlone() {
        let (controller, webView, opened) = controller()
        controller.isWebViewLoaded = true
        controller.isSearchReady = true
        let window = NSWindow(contentRect: controller.view.bounds, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = controller.view
        defer { window.orderOut(nil) }
        XCTAssertNotNil(controller.handleMonitoredKeyDownEvent(event(window: window.windowNumber + 100)))
        XCTAssertTrue(webView.scripts.isEmpty)
        XCTAssertNil(controller.handleMonitoredKeyDownEvent(event(window: window.windowNumber)))
        XCTAssertEqual(opened.urls.count, 1)
        XCTAssertTrue(webView.scripts.isEmpty)
    }

    func testWebViewUsesNativeFirstResponderEligibility() {
        let nativeView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let previewView = InteractiveWebView(frame: .zero, configuration: WKWebViewConfiguration())
        XCTAssertEqual(previewView.acceptsFirstResponder, nativeView.acceptsFirstResponder)
    }

    func testPreviewAppearanceDoesNotClaimFirstResponder() {
        let (controller, _, _) = controller()
        let window = NSWindow(contentRect: controller.view.bounds, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = controller.view
        defer { window.orderOut(nil) }
        XCTAssertTrue(window.makeFirstResponder(nil))
        let previousResponder = window.firstResponder
        controller.viewDidAppear()
        let focused = expectation(description: "preview appearance completes")
        DispatchQueue.main.async {
            XCTAssertTrue(window.firstResponder === previousResponder)
            XCTAssertFalse(controller.acceptsFirstResponder)
            focused.fulfill()
        }
        wait(for: [focused], timeout: 2)
    }

    func testPreviewFindHandsOffToAppWithoutOpeningAnUnusableHTMLField() throws {
        let (controller, webView, _) = controller()
        let file = URL(fileURLWithPath: "/tmp/中文 note & test.md")
        controller.currentURL = file
        var opened: [URL] = []
        controller.searchDocumentOpener = { url, completion in opened.append(url); completion(true) }
        controller.makeSearchButton().performClick(nil)
        XCTAssertEqual(opened.count, 1, "Native app handoff does not depend on preview renderer readiness")
        let request = try XCTUnwrap(DocumentOpenRequest(url: try XCTUnwrap(opened.first)))
        XCTAssertEqual(request.fileURL, file)
        XCTAssertTrue(request.wantsSearch)
        XCTAssertTrue(webView.scripts.isEmpty)
    }

    func testDeniedAppLaunchShowsGuidanceAndNeverOpensAnUnusableInput() {
        let (controller, webView, _) = controller()
        var failures = 0
        controller.searchDocumentOpener = { _, completion in completion(false) }
        controller.searchLaunchFailureHandler = { failures += 1 }
        controller.makeSearchButton().performClick(nil)
        XCTAssertEqual(failures, 1)
        XCTAssertTrue(webView.scripts.isEmpty)
    }

    func testStandardFindMenuActionUsesTheSameSearchBridge() {
        let (controller, webView, opened) = controller()
        controller.isWebViewLoaded = true
        controller.isSearchReady = true
        let item = NSMenuItem(title: "Find", action: nil, keyEquivalent: "f")
        item.tag = NSTextFinder.Action.showFindInterface.rawValue
        controller.performTextFinderAction(item)
        XCTAssertEqual(opened.urls.count, 1)
        XCTAssertTrue(webView.scripts.isEmpty)
        var webViewCalls = 0
        webView.searchShortcutHandler = { webViewCalls += 1 }
        webView.performTextFinderAction(item)
        XCTAssertEqual(webViewCalls, 1)
    }

    func testNativeFindButtonWorksWithoutReceivingAKeyboardEvent() {
        let (controller, webView, opened) = controller()
        let button = controller.makeSearchButton()
        button.performClick(nil)
        XCTAssertTrue(webView.scripts.isEmpty)
        controller.isWebViewLoaded = true
        controller.isSearchReady = true
        controller.completePendingSearchRequest()
        XCTAssertEqual(opened.urls.count, 1)
        button.performClick(nil)
        XCTAssertEqual(opened.urls.count, 2)
        XCTAssertTrue(webView.scripts.isEmpty)
    }

    func testNativeFindButtonKeyEquivalentUsesTheSameAction() {
        let (controller, webView, opened) = controller()
        controller.isWebViewLoaded = true
        controller.isSearchReady = true
        let button = controller.makeSearchButton()
        XCTAssertTrue(button.performKeyEquivalent(with: event()))
        XCTAssertEqual(opened.urls.count, 1)
        XCTAssertFalse(button.performKeyEquivalent(with: event(flags: [.command, .shift])))
        XCTAssertEqual(opened.urls.count, 1)
        XCTAssertTrue(webView.scripts.isEmpty)
    }

}
