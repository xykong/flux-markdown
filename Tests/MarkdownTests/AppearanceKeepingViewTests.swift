import AppKit
import XCTest

final class AppearanceKeepingViewTests: XCTestCase {
    private func settle() { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }

    func testRootViewRestoresTheSelectedAppearanceAfterTheHostChangesIt() {
        let root = AppearanceKeepingView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        root.selectedAppearance = NSAppearance(named: .aqua)
        root.appearance = NSAppearance(named: .aqua)
        root.appearance = NSAppearance(named: .vibrantDark) // what Quick Look full screen does
        root.viewDidChangeEffectiveAppearance()
        settle()
        XCTAssertEqual(root.appearance?.name, .aqua)
        XCTAssertEqual(root.effectiveAppearance.name, .aqua)
    }

    func testWithoutASelectedAppearanceTheHostAppearanceStays() {
        let root = AppearanceKeepingView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        root.appearance = NSAppearance(named: .darkAqua)
        root.viewDidChangeEffectiveAppearance()
        settle()
        XCTAssertEqual(root.appearance?.name, .darkAqua)
    }

    func testRootViewDoesNotMoveWindowOnMouseDown() {
        let root = AppearanceKeepingView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertFalse(root.mouseDownCanMoveWindow)
    }
}
