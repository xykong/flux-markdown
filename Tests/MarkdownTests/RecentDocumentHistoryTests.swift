import XCTest

final class RecentDocumentHistoryTests: XCTestCase {
    func testRestartMigrationAndExplicitClear() {
        let name = "RecentHistoryTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let a = URL(fileURLWithPath: "/unavailable/中文 a.md")
        let b = URL(fileURLWithPath: "/unavailable/b.md")
        let history = RecentDocumentHistory(defaults: defaults, limit: 2)
        history.migrate([a, b])
        XCTAssertEqual(history.urls, [a, b])
        history.record(b)
        XCTAssertEqual(RecentDocumentHistory(defaults: defaults).urls, [b, a])
        history.record(URL(fileURLWithPath: "/unavailable/c.md"))
        XCTAssertEqual(history.urls.count, 2)
        history.clear()
        let restarted = RecentDocumentHistory(defaults: defaults)
        restarted.migrate([a, b])
        XCTAssertTrue(restarted.urls.isEmpty, "Explicit clear must not resurrect system entries")
    }

    func testOnlyFileURLsAndStandardizedDeduplication() {
        let name = "RecentHistoryTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let history = RecentDocumentHistory(defaults: defaults)
        history.record(URL(string: "https://example.com/document.md")!)
        XCTAssertTrue(history.urls.isEmpty)
        history.record(URL(fileURLWithPath: "/tmp/folder/../file.md"))
        history.record(URL(fileURLWithPath: "/tmp/file.md"))
        XCTAssertEqual(history.urls, [URL(fileURLWithPath: "/tmp/file.md")])
    }
}
