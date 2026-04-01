import XCTest

@MainActor
final class ScrollPositionTests: XCTestCase {
    
    var preference: AppearancePreference!
    
    override func setUp() {
        super.setUp()
        preference = AppearancePreference.shared
        preference.clearScrollPositions()
    }
    
    override func tearDown() {
        preference.clearScrollPositions()
        super.tearDown()
    }
    
    func testSetAndGetScrollPosition() {
        let path = "/Users/test/README.md"
        let scrollY = 1250.5
        
        preference.setScrollPosition(for: path, value: scrollY)
        
        let retrieved = preference.getScrollPosition(for: path)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved!, scrollY, accuracy: 0.01)
    }
    
    func testGetNonExistentPath() {
        let retrieved = preference.getScrollPosition(for: "/non/existent/path.md")
        XCTAssertNil(retrieved)
    }
    
    func testUpdateExistingPosition() {
        let path = "/Users/test/README.md"
        
        preference.setScrollPosition(for: path, value: 100.0)
        preference.setScrollPosition(for: path, value: 200.0)
        
        let retrieved = preference.getScrollPosition(for: path)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved!, 200.0, accuracy: 0.01)
    }
    
    func testMultipleFiles() {
        preference.setScrollPosition(for: "/path/A.md", value: 100.0)
        preference.setScrollPosition(for: "/path/B.md", value: 200.0)
        preference.setScrollPosition(for: "/path/C.md", value: 300.0)
        
        XCTAssertEqual(preference.getScrollPosition(for: "/path/A.md")!, 100.0, accuracy: 0.01)
        XCTAssertEqual(preference.getScrollPosition(for: "/path/B.md")!, 200.0, accuracy: 0.01)
        XCTAssertEqual(preference.getScrollPosition(for: "/path/C.md")!, 300.0, accuracy: 0.01)
    }
    
    func testLRUOrderingNewFilesAtFront() {
        preference.setScrollPosition(for: "/path/A.md", value: 100.0)
        preference.setScrollPosition(for: "/path/B.md", value: 200.0)
        preference.setScrollPosition(for: "/path/C.md", value: 300.0)
        
        XCTAssertEqual(preference.getScrollPosition(for: "/path/C.md")!, 300.0, accuracy: 0.01)
        XCTAssertEqual(preference.getScrollPosition(for: "/path/B.md")!, 200.0, accuracy: 0.01)
        XCTAssertEqual(preference.getScrollPosition(for: "/path/A.md")!, 100.0, accuracy: 0.01)
    }
    
    func testUpdateMovesToFront() {
        preference.setScrollPosition(for: "/path/A.md", value: 100.0)
        preference.setScrollPosition(for: "/path/B.md", value: 200.0)
        preference.setScrollPosition(for: "/path/C.md", value: 300.0)
        
        preference.setScrollPosition(for: "/path/A.md", value: 500.0)
        
        XCTAssertEqual(preference.getScrollPosition(for: "/path/A.md")!, 500.0, accuracy: 0.01)
    }
    
    func testMaxLimitEnforced() {
        for i in 0..<150 {
            preference.setScrollPosition(for: "/path/file\(i).md", value: Double(i * 100))
        }
        
        XCTAssertEqual(preference.getScrollPosition(for: "/path/file149.md")!, 14900.0, accuracy: 0.01)
        XCTAssertEqual(preference.getScrollPosition(for: "/path/file50.md")!, 5000.0, accuracy: 0.01)
        
        XCTAssertNil(preference.getScrollPosition(for: "/path/file0.md"))
        XCTAssertNil(preference.getScrollPosition(for: "/path/file49.md"))
    }
    
    func testClearAllPositions() {
        preference.setScrollPosition(for: "/path/A.md", value: 100.0)
        preference.setScrollPosition(for: "/path/B.md", value: 200.0)
        
        preference.clearScrollPositions()
        
        XCTAssertNil(preference.getScrollPosition(for: "/path/A.md"))
        XCTAssertNil(preference.getScrollPosition(for: "/path/B.md"))
    }
    
    func testZeroScrollYIsStored() {
        let path = "/Users/test/README.md"
        
        preference.setScrollPosition(for: path, value: 0.0)
        
        let retrieved = preference.getScrollPosition(for: path)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved!, 0.0, accuracy: 0.01)
    }
    
    func testNegativeScrollYIsStored() {
        let path = "/Users/test/README.md"
        
        preference.setScrollPosition(for: path, value: -50.0)
        
        let retrieved = preference.getScrollPosition(for: path)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved!, -50.0, accuracy: 0.01)
    }
    
    func testSpecialCharactersInPath() {
        let paths = [
            "/Users/test/文档/README.md",
            "/Users/test/📝 Notes.md",
            "/Users/test/File with spaces.md",
            "/Users/test/File'with\"quotes.md"
        ]
        
        for (index, path) in paths.enumerated() {
            let scrollY = Double(index * 100)
            preference.setScrollPosition(for: path, value: scrollY)
            
            let retrieved = preference.getScrollPosition(for: path)
            XCTAssertNotNil(retrieved, "Failed for path: \(path)")
            XCTAssertEqual(retrieved!, scrollY, accuracy: 0.01, "Failed for path: \(path)")
        }
    }
    
    func testPersistenceAcrossInstances() {
        let path = "/Users/test/README.md"
        let scrollY = 1234.5
        
        preference.setScrollPosition(for: path, value: scrollY)
        
        let newPreference = AppearancePreference.shared
        let retrieved = newPreference.getScrollPosition(for: path)
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved!, scrollY, accuracy: 0.01)
    }
}
