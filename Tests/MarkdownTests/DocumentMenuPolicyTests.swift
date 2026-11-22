import XCTest
import AppKit

final class DocumentMenuPolicyTests: XCTestCase {
    func testKeepsNativeOpenAndDurableHistoryInOrder() {
        let main = NSMenu(), file = NSMenu()
        let fileItem=NSMenuItem();fileItem.submenu=file;main.addItem(fileItem)
        let customRecent=NSMenuItem(title:"Durable history",action:nil,keyEquivalent:"")
        customRecent.submenu=NSMenu()
        customRecent.submenu?.addItem(NSMenuItem(title:NSLocalizedString("Clear Menu",comment:""),action:Selector(("menuAction:")),keyEquivalent:""))
        file.addItem(customRecent);file.addItem(.separator())
        let open=NSMenuItem(title:"Ouvrir",action:#selector(NSDocumentController.openDocument(_:)),keyEquivalent:"o")
        file.addItem(open)
        let recent=NSMenuItem();recent.submenu=NSMenu()
        recent.submenu?.addItem(NSMenuItem(title:"Clear",action:#selector(NSDocumentController.clearRecentDocuments(_:)),keyEquivalent:""))
        file.addItem(recent);file.addItem(.separator())
        let save=NSMenuItem(title:"Save",action:#selector(NSDocument.save(_:)),keyEquivalent:"s");file.addItem(save)
        DocumentMenuPolicy.reconcile(main)
        XCTAssertTrue(file.items.contains(open));XCTAssertTrue(file.items.contains(save))
        XCTAssertFalse(file.items.contains(recent))
        XCTAssertTrue(file.items[file.index(of:open)+1] === customRecent)
        let count=file.items.count
        DocumentMenuPolicy.reconcile(main)
        XCTAssertEqual(file.items.count,count)
        file.removeItem(customRecent);file.addItem(recent)
        DocumentMenuPolicy.reconcile(main)
        XCTAssertTrue(file.items.contains(recent))
    }
}
