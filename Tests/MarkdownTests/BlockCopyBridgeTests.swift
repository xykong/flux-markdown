import XCTest
import AppKit

final class BlockCopyBridgeTests: XCTestCase {
    func testPreferenceDefaultsOffAndPersistsAcrossReaders() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("preferences.plist")
        let suite = "BlockCopyTests." + UUID().uuidString
        let local = UserDefaults(suiteName: suite)!
        defer { local.removePersistentDomain(forName: suite) }
        let first = AppearancePreference(sharedStore: SharedPreferenceStore(fileURL: file), localStore: local, migrateFromAppGroup: false)
        XCTAssertFalse(first.showCopyButtons)
        first.showCopyButtons = true
        first.flushSharedPreferences()
        let second = AppearancePreference(sharedStore: SharedPreferenceStore(fileURL: file, alwaysReload: true), localStore: local, migrateFromAppGroup: false)
        XCTAssertTrue(second.showCopyButtons)
        first.showCopyButtons = false
        first.flushSharedPreferences()
        XCTAssertFalse(second.showCopyButtons)
    }

    func testValidationRejectsStaleMalformedOversizedRequests() {
        let valid: [String: Any] = ["id": "1", "generation": "document", "text": "\t中文 😀\n"]
        XCTAssertNotNil(BlockCopyBridge.request(valid, generation: "document", enabled: true))
        XCTAssertNil(BlockCopyBridge.request(valid, generation: "other", enabled: true))
        XCTAssertNil(BlockCopyBridge.request(valid, generation: "document", enabled: false))
        var invalid = valid; invalid["extra"] = "unexpected"
        XCTAssertNil(BlockCopyBridge.request(invalid, generation: "document", enabled: true))
        invalid = valid; invalid["id"] = "'); alert(1)"
        XCTAssertNil(BlockCopyBridge.request(invalid, generation: "document", enabled: true))
        invalid = valid; invalid["text"] = String(repeating: "中", count: 1_400_000)
        XCTAssertNil(BlockCopyBridge.request(invalid, generation: "document", enabled: true))
    }

    func testReplayDoesNotWriteTwiceAndNewDocumentResetsSequence() {
        let bridge = BlockCopyBridge()
        let request = BlockCopyBridge.Request(id: "3", generation: "one", text: "private")
        XCTAssertTrue(bridge.acceptSequence(request))
        XCTAssertFalse(bridge.acceptSequence(request))
        XCTAssertFalse(bridge.acceptSequence(.init(id: "2", generation: "one", text: "private")))
        XCTAssertTrue(bridge.acceptSequence(.init(id: "1", generation: "two", text: "private")))
    }

    func testIndependentPasteboardReadbackPreservesUnicodeWhitespace() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let expected = "\t中文 <x> 😀\n\n  end\n"
        XCTAssertTrue(BlockCopyBridge.write(expected, to: board))
        XCTAssertEqual(board.string(forType: .string), expected)
    }
}
