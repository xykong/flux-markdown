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
    func testArabicResourcesCoverCurrentEnglishKeys() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        for target in ["Markdown", "MarkdownPreview"] {
            func strings(_ language: String) throws -> [String: String] {
                let data = try Data(contentsOf: root.appendingPathComponent("Sources/\(target)/\(language).lproj/Localizable.strings"))
                return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
            }
            let english = try strings("en"), arabic = try strings("ar")
            for key in english.keys {
                XCTAssertFalse(arabic[key]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "\(target)/ar: \(key)")
            }
        }
    }
}
