import XCTest

final class SharedPreferenceStoreTests: XCTestCase {

    private var tempDir: URL!
    private var tempFile: URL!
    private var store: SharedPreferenceStore!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SharedPreferenceStoreTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempFile = tempDir.appendingPathComponent("test-preferences.plist")
        store = SharedPreferenceStore(fileURL: tempFile)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Basic read/write

    func testStringRoundTrip() {
        store.set("dark", forKey: "theme")
        store.synchronize()

        let reloaded = SharedPreferenceStore(fileURL: tempFile)
        XCTAssertEqual(reloaded.string(forKey: "theme"), "dark")
    }

    func testDoubleRoundTrip() {
        store.set(18.5, forKey: "fontSize")
        store.synchronize()

        let reloaded = SharedPreferenceStore(fileURL: tempFile)
        XCTAssertEqual(reloaded.double(forKey: "fontSize"), 18.5, accuracy: 0.01)
    }

    func testBoolRoundTrip() {
        store.set(false, forKey: "enableMermaid")
        store.synchronize()

        let reloaded = SharedPreferenceStore(fileURL: tempFile)
        XCTAssertEqual(reloaded.bool(forKey: "enableMermaid"), false)
    }

    func testMissingKeyDefaults() {
        XCTAssertNil(store.string(forKey: "nonexistent"))
        XCTAssertEqual(store.double(forKey: "nonexistent"), 0)
        XCTAssertEqual(store.bool(forKey: "nonexistent"), false)
        XCTAssertNil(store.object(forKey: "nonexistent"))
        XCTAssertNil(store.dictionary(forKey: "nonexistent"))
        XCTAssertNil(store.array(forKey: "nonexistent"))
    }

    func testRemoveObject() {
        store.set("value", forKey: "key")
        store.removeObject(forKey: "key")
        store.synchronize()

        let reloaded = SharedPreferenceStore(fileURL: tempFile)
        XCTAssertNil(reloaded.string(forKey: "key"))
    }

    func testSetNilRemovesKey() {
        store.set("value" as Any?, forKey: "key")
        store.set(nil as Any?, forKey: "key")
        store.synchronize()

        let reloaded = SharedPreferenceStore(fileURL: tempFile)
        XCTAssertNil(reloaded.object(forKey: "key"))
    }

    // MARK: - Cross-process simulation

    func testCrossProcessRead() {
        // Simulate main app writing
        store.set("dark", forKey: "theme")
        store.set(20.0, forKey: "fontSize")
        store.set(true, forKey: "enableKatex")
        store.synchronize()

        // Simulate extension reading (new instance, same file)
        let extensionStore = SharedPreferenceStore(fileURL: tempFile)
        XCTAssertEqual(extensionStore.string(forKey: "theme"), "dark")
        XCTAssertEqual(extensionStore.double(forKey: "fontSize"), 20.0, accuracy: 0.01)
        XCTAssertEqual(extensionStore.bool(forKey: "enableKatex"), true)
    }

    func testReloadsWhenFileChangesOnDisk() {
        store.set("light", forKey: "theme")
        store.synchronize()

        // Another process writes to the same file
        let otherWriter = SharedPreferenceStore(fileURL: tempFile)
        otherWriter.set("dark", forKey: "theme")
        otherWriter.synchronize()

        // Original store should pick up the change on next read
        XCTAssertEqual(store.string(forKey: "theme"), "dark")
    }

    func testSkipsReloadWhenFileUnchanged() {
        store.set("light", forKey: "theme")
        store.synchronize()

        // Modify cache directly (simulates in-memory-only write from sandboxed extension)
        store.set("dark", forKey: "theme")

        // Since file hasn't changed on disk, reading back should show in-memory value
        // (no reload triggered because modification date hasn't changed)
        XCTAssertEqual(store.string(forKey: "theme"), "dark")
    }

    // MARK: - File doesn't exist yet

    func testWorksWhenFileDoesNotExist() {
        let missingFile = tempDir.appendingPathComponent("does-not-exist.plist")
        let emptyStore = SharedPreferenceStore(fileURL: missingFile)

        XCTAssertNil(emptyStore.string(forKey: "anything"))
        XCTAssertEqual(emptyStore.double(forKey: "anything"), 0)
    }

    func testCreatesFileOnFirstSynchronize() {
        let newFile = tempDir.appendingPathComponent("new-prefs.plist")
        XCTAssertFalse(FileManager.default.fileExists(atPath: newFile.path))

        let newStore = SharedPreferenceStore(fileURL: newFile)
        newStore.set("test", forKey: "key")
        let success = newStore.synchronize()

        XCTAssertTrue(success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: newFile.path))
    }

    // MARK: - Synchronize return value

    func testSynchronizeReturnsTrueOnSuccess() {
        store.set("value", forKey: "key")
        XCTAssertTrue(store.synchronize())
    }

    func testSynchronizeReturnsFalseForReadOnlyLocation() {
        // Create a store pointing to a non-writable location
        let readOnlyFile = URL(fileURLWithPath: "/System/non-writable.plist")
        let readOnlyStore = SharedPreferenceStore(fileURL: readOnlyFile)
        readOnlyStore.set("value", forKey: "key")
        XCTAssertFalse(readOnlyStore.synchronize())
    }
}
