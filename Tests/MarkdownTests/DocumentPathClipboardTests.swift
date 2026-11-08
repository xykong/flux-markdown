import XCTest
import AppKit

final class DocumentPathClipboardTests: XCTestCase {
    func testUnicodeSpaceAndShellCharactersAreCopiedLiterally() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let path = "/tmp/中文 folder/a ' $`#.md"
        XCTAssertTrue(DocumentPathClipboard.copy(URL(fileURLWithPath: path), to: board))
        XCTAssertEqual(board.string(forType: .string), path)
        XCTAssertFalse(DocumentPathClipboard.copy(URL(string: "https://example.com")!, to: board))
        XCTAssertEqual(board.string(forType: .string), path)
    }
    func testNativeWindowSelectionDoesNotCopyAnotherDocumentsPath() {
        let selection = DocumentPathSelection(observeWindows: false)
        let first = NSWindow(), second = NSWindow(), settings = NSWindow()
        let a = URL(fileURLWithPath: "/tmp/a.md"), b = URL(fileURLWithPath: "/tmp/b.md")
        selection.register(a, for: first); selection.register(b, for: second)
        selection.select(first); XCTAssertEqual(selection.url, a)
        selection.select(second); XCTAssertEqual(selection.url, b)
        selection.select(settings); XCTAssertNil(selection.url)
        selection.select(first); selection.register(nil, for: first)
        XCTAssertNil(selection.url, "Unsaved documents must disable copying")
        selection.select(nil); XCTAssertNil(selection.url)
    }
}
