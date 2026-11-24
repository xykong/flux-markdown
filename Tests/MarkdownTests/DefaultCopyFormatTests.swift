import XCTest

final class DefaultCopyFormatTests: XCTestCase {
    func testDefaultsValidationAndSharedPersistence() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("preferences.plist")
        let domain = "DefaultCopyFormatTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let store = SharedPreferenceStore(fileURL: file)
        let first = AppearancePreference(sharedStore: store, localStore: defaults, migrateFromAppGroup: false)
        XCTAssertEqual(first.defaultCopyFormat, .richText)
        first.defaultCopyFormat = .markdown
        first.flushSharedPreferences()
        let reloaded = AppearancePreference(sharedStore: SharedPreferenceStore(fileURL: file, alwaysReload: true), localStore: defaults, migrateFromAppGroup: false)
        XCTAssertEqual(reloaded.defaultCopyFormat, .markdown)
        first.defaultCopyFormat = .plainText
        first.flushSharedPreferences()
        XCTAssertEqual(reloaded.defaultCopyFormat, .plainText)
        store.set("invalid", forKey: "defaultCopyFormat")
        store.synchronize()
        XCTAssertEqual(reloaded.defaultCopyFormat, .richText)
        XCTAssertEqual(DiagnosticSettings.value("markdown", key: "defaultCopyFormat"), "markdown")
        XCTAssertEqual(DiagnosticSettings.value("plain-text", key: "defaultCopyFormat"), "plain-text")
        XCTAssertEqual(DiagnosticSettings.value("invalid", key: "defaultCopyFormat"), "invalid")
    }
}
