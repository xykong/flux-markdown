import XCTest
import SwiftUI

final class InterfaceLayoutDirectionTests: XCTestCase {
    func testArabicForcesRightToLeft() {
        XCTAssertEqual(InterfaceLayoutDirection.override(for: "ar"), .rightToLeft)
    }

    func testExplicitLeftToRightLanguagesForceLeftToRight() {
        for language in ["en", "de", "fr", "zh"] {
            XCTAssertEqual(InterfaceLayoutDirection.override(for: language), .leftToRight, language)
        }
    }

    func testSystemKeepsTheResolvedDirection() {
        XCTAssertNil(InterfaceLayoutDirection.override(for: "system"))
    }
}
