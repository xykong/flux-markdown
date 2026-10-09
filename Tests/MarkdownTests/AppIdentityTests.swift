import XCTest

final class AppIdentityTests: XCTestCase {

    func testForkVersionIsDetected() {
        XCTAssertTrue(AppIdentity.isFork(displayVersion: "1.34.495-xluffy.1"))
    }

    func testNumericVersionIsNotFork() {
        XCTAssertFalse(AppIdentity.isFork(displayVersion: "1.34.495"))
    }

    func testMissingVersionIsNotFork() {
        XCTAssertFalse(AppIdentity.isFork(displayVersion: nil))
        XCTAssertFalse(AppIdentity.isFork(displayVersion: "   "))
    }

    func testEditionLabelNamesForkAndUpstream() {
        XCTAssertEqual(
            AppIdentity.editionLabel(displayVersion: "1.34.495-xluffy.1"),
            "Unofficial xluffy fork"
        )
        XCTAssertEqual(
            AppIdentity.editionLabel(displayVersion: "1.34.495"),
            "Upstream release"
        )
    }

    func testSummaryTellsForkBuildFromUpstream() {
        XCTAssertTrue(
            AppIdentity.summary(displayVersion: "1.34.495-xluffy.1").contains("xluffy fork")
        )
        XCTAssertTrue(
            AppIdentity.summary(displayVersion: "1.34.495").contains("upstream")
        )
    }
}
