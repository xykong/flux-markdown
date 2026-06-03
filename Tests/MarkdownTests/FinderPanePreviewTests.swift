import XCTest

final class FinderPanePreviewTests: XCTestCase {
    private var tempDir: URL!
    private var tempFile: URL!
    private var localDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FinderPanePreviewTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempFile = tempDir.appendingPathComponent("test-preferences.plist")
        suiteName = "com.xykong.Markdown.Tests.FinderPanePreviewTests.\(UUID().uuidString)"
        localDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        localDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: tempDir)
        localDefaults = nil
        suiteName = nil
        tempFile = nil
        tempDir = nil
        super.tearDown()
    }

    private func makePreference() -> AppearancePreference {
        AppearancePreference(
            sharedStore: SharedPreferenceStore(fileURL: tempFile),
            localStore: localDefaults,
            migrateFromAppGroup: false
        )
    }
    
    func testFinderPaneFontSizeDefaultIs13() {
        let pref = makePreference()
        XCTAssertEqual(pref.finderPaneFontSize, 13)
    }
    
    func testFinderPaneFontSizePersistsRoundTrip() {
        let pref = makePreference()
        let original = pref.finderPaneFontSize
        defer { pref.finderPaneFontSize = original }
        
        pref.finderPaneFontSize = 18
        XCTAssertEqual(pref.finderPaneFontSize, 18)
    }
}
