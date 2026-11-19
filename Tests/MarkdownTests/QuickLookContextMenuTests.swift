import AppKit
import XCTest

final class QuickLookContextMenuTests: XCTestCase {
    private final class Target: NSObject { @objc func act(_ sender: Any?) {} }

    private func item(_ identifier: NSUserInterfaceItemIdentifier?) -> NSMenuItem {
        let item = NSMenuItem(title: identifier?.rawValue ?? "Other", action: nil, keyEquivalent: "")
        item.identifier = identifier
        return item
    }

    private func webKitMenu(withCopy: Bool) -> NSMenu {
        let menu = NSMenu()
        if withCopy { menu.addItem(item(QuickLookContextMenu.webKitCopyIdentifier)) }
        menu.addItem(item(nil))
        return menu
    }

    func testCopyAsMarkdownFollowsWebKitCopyOnce() {
        let menu = webKitMenu(withCopy: true), target = Target()
        XCTAssertNotNil(QuickLookContextMenu.insertCopyAsMarkdown(into: menu, target: target, action: #selector(Target.act(_:))))
        XCTAssertNil(QuickLookContextMenu.insertCopyAsMarkdown(into: menu, target: target, action: #selector(Target.act(_:))))
        XCTAssertEqual(menu.items.map(\.identifier), [QuickLookContextMenu.webKitCopyIdentifier, QuickLookContextMenu.copyAsMarkdownIdentifier, nil])
        XCTAssertEqual(menu.items[1].keyEquivalent, "")
    }

    func testNoCopyAsMarkdownWithoutSelection() {
        let menu = webKitMenu(withCopy: false)
        XCTAssertNil(QuickLookContextMenu.insertCopyAsMarkdown(into: menu, target: Target(), action: #selector(Target.act(_:))))
        XCTAssertEqual(menu.items.count, 1)
    }

    func testSpeechItemsReplaceTheSpeechSubmenuInPlace() {
        let target = Target()
        let start = NSMenuItem(title: "Start Speaking", action: #selector(Target.act(_:)), keyEquivalent: "")
        let stop = NSMenuItem(title: "Stop Speaking", action: #selector(Target.act(_:)), keyEquivalent: "")
        start.target = target
        let speech = item(QuickLookContextMenu.speechIdentifier)
        speech.submenu = NSMenu()
        speech.submenu?.addItem(start)
        speech.submenu?.addItem(stop)
        let menu = NSMenu()
        menu.addItem(item(QuickLookContextMenu.webKitCopyIdentifier))
        menu.addItem(.separator())
        menu.addItem(speech)
        menu.addItem(item(nil))

        QuickLookContextMenu.flattenSpeech(in: menu)

        XCTAssertEqual(menu.items.map { $0.isSeparatorItem ? "-" : $0.title },
                       [QuickLookContextMenu.webKitCopyIdentifier.rawValue, "-", "Start Speaking", "Stop Speaking", "Other"])
        XCTAssertTrue(menu.items.allSatisfy { !$0.hasSubmenu })
        XCTAssertTrue(menu.items[2] === start && menu.items[2].target === target)
        XCTAssertEqual(menu.items[2].action, #selector(Target.act(_:)))
    }

    func testMenuWithoutSpeechIsUnchanged() {
        let menu = webKitMenu(withCopy: true)
        QuickLookContextMenu.flattenSpeech(in: menu)
        XCTAssertEqual(menu.items.map(\.identifier), [QuickLookContextMenu.webKitCopyIdentifier, nil])
    }
}
