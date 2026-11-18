import XCTest
import AppKit
final class QuickLookFollowStateTests: XCTestCase {
    func testStopRestoresNormalBudget() {
        var state = QuickLookFollowState(); state.start()
        XCTAssertEqual(state.interval, 0.5)
        state.stop()
        XCTAssertEqual(state.interval, 2)
        state.reset(); XCTAssertFalse(state.enabled)
    }
    func testMetadataAndReadFailureShareBoundedRecovery() {
        var state = QuickLookFollowState(); state.start()
        XCTAssertFalse(state.failedAttempt()); XCTAssertFalse(state.failedAttempt())
        XCTAssertTrue(state.failedAttempt()); XCTAssertFalse(state.enabled)
        XCTAssertTrue(state.suspended); XCTAssertEqual(state.interval, 2)
        XCTAssertFalse(state.failedAttempt())
        state.succeeded(); XCTAssertFalse(state.suspended)
        state.start(); XCTAssertFalse(state.failedAttempt())
    }
    func testClickResumesPausedFollowAndDoubleClickStops() {
        var state = QuickLookFollowState()
        XCTAssertEqual(state.buttonLook, .off)
        XCTAssertEqual(state.buttonClick(clickCount: 1), .start)
        state.start()
        XCTAssertEqual(state.buttonLook, .following)
        XCTAssertEqual(state.buttonClick(clickCount: 1), .stop)
        state.paused = true
        XCTAssertEqual(state.buttonLook, .paused)
        XCTAssertEqual(state.buttonClick(clickCount: 1), .resume)
        XCTAssertEqual(state.buttonClick(clickCount: 2), .stop, "A double click stops a paused Follow")
        state.linesWaiting = true
        state.start()
        XCTAssertFalse(state.linesWaiting); XCTAssertFalse(state.paused)
        state.paused = true; state.linesWaiting = true
        state.stop()
        XCTAssertEqual(state.buttonLook, .off); XCTAssertFalse(state.linesWaiting)
    }
}

final class QuickLookFollowButtonTests: XCTestCase {
    func testFollowButtonStaysPressedAndReleasesWhenStopped() {
        let controller = PreviewViewController()
        controller.currentURL = URL(fileURLWithPath: "/private/tmp/flux-follow-button-test.md")
        controller.loadView()
        controller.viewDidLoad()
        defer { controller.viewWillDisappear() }
        let button = controller.view.subviews.compactMap { $0 as? CircularToolbarButton }
            .first { $0.accessibilityLabel() == "Follow Changes" }
        XCTAssertNotNil(button)
        XCTAssertEqual(button?.state, .off)
        button?.performClick(nil)
        XCTAssertEqual(button?.state, .on)
        button?.performClick(nil)
        XCTAssertEqual(button?.state, .off)
    }
    func testPausedIconDrawsOrangeOnAnOffCircularButton() {
        guard #available(macOS 12.0, *) else { return } // palette symbols need macOS 12
        func orangePixels(_ image: NSImage?) -> Int {
            let button = NSButton(frame: NSRect(x: 0, y: 0, width: 30, height: 30))
            button.setButtonType(.momentaryPushIn); button.bezelStyle = .circular; button.isBordered = true
            button.imagePosition = .imageOnly; button.appearance = NSAppearance(named: .aqua)
            button.image = image; button.contentTintColor = .systemOrange; button.state = .off
            guard let rep = button.bitmapImageRepForCachingDisplay(in: button.bounds) else { return 0 }
            button.cacheDisplay(in: button.bounds, to: rep)
            var count = 0
            for x in 0..<rep.pixelsWide { for y in 0..<rep.pixelsHigh {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), c.alphaComponent > 0.5 else { continue }
                if c.redComponent > 0.8, c.greenComponent > 0.35, c.greenComponent < 0.75, c.blueComponent < 0.3 { count += 1 }
            }}
            return count
        }
        let symbol = NSImage(systemSymbolName: "arrow.down.to.line", accessibilityDescription: nil)
        // Pixel counts depend on the screen scale (CI runners draw at 1x), so compare
        // with the same symbol drawn from the tint alone instead of a fixed count.
        XCTAssertGreaterThan(orangePixels(FollowButtonIcon.paused(symbol)), orangePixels(symbol))
    }
}

final class QuickLookEarlyCleanupTests: XCTestCase {
    func testEarlyAndRepeatedDisappearanceWithoutWebViewIsSafe() {
        let controller = PreviewViewController()
        controller.loadView() // Reproduces the captured test-run crash before renderer creation.
        controller.currentURL = URL(fileURLWithPath: "/private/tmp/early-cleanup.md")
        XCTAssertNil(controller.webView)
        controller.viewWillDisappear()
        controller.viewWillDisappear()
        XCTAssertNil(controller.webView)
    }
}
