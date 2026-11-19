import XCTest
import AppKit

final class SelectionCopyBridgeTests: XCTestCase {
    func testOnlyVisibleExpandedMarkdownPreviewIsEnabled() {
        XCTAssertTrue(SelectionCopyBridge.enabled(expanded: true, visible: true, fileExtension: "md"))
        XCTAssertFalse(SelectionCopyBridge.enabled(expanded: false, visible: true, fileExtension: "md"))
        XCTAssertFalse(SelectionCopyBridge.enabled(expanded: true, visible: false, fileExtension: "md"))
        XCTAssertFalse(SelectionCopyBridge.enabled(expanded: true, visible: true, fileExtension: nil))
        for format in ["tsv", "mmd", "html", ""] {
            XCTAssertFalse(SelectionCopyBridge.enabled(expanded: true, visible: true, fileExtension: format))
        }
    }
}
