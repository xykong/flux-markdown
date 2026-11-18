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
