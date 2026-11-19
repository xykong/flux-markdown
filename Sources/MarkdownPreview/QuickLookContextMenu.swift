import AppKit

/// Changes to WebKit's selection menu in the Quick Look extension only.
enum QuickLookContextMenu {
    static let webKitCopyIdentifier = NSUserInterfaceItemIdentifier("WKMenuItemIdentifierCopy")
    static let speechIdentifier = NSUserInterfaceItemIdentifier("WKMenuItemIdentifierSpeechMenu")
    static let copyAsMarkdownIdentifier = NSUserInterfaceItemIdentifier("FluxMenuItemCopyAsMarkdown")

    /// Adds Copy as Markdown right after WebKit's Copy, which WebKit shows only for a selection.
    @discardableResult
    static func insertCopyAsMarkdown(into menu: NSMenu, target: AnyObject, action: Selector) -> NSMenuItem? {
        guard menu.items.allSatisfy({ $0.identifier != copyAsMarkdownIdentifier }),
              let copyIndex = menu.items.firstIndex(where: { $0.identifier == webKitCopyIdentifier }) else { return nil }
        let item = NSMenuItem(title: NSLocalizedString("Copy as Markdown", comment: "Quick Look context menu"), action: action, keyEquivalent: "")
        item.identifier = copyAsMarkdownIdentifier
        item.target = target
        menu.insertItem(item, at: copyIndex + 1)
        return item
    }

    /// After any submenu of this menu opens, Quick Look sends later clicks to the preview
    /// without a position and stops sending drags and scrolls, until the preview closes.
    /// Speech's items (Start Speaking, Stop Speaking) therefore replace its submenu.
    static func flattenSpeech(in menu: NSMenu) {
        guard let index = menu.items.firstIndex(where: { $0.identifier == speechIdentifier }),
              let submenu = menu.items[index].submenu else { return }
        let items = submenu.items
        items.forEach(submenu.removeItem)
        menu.removeItem(at: index)
        for (offset, item) in items.enumerated() { menu.insertItem(item, at: index + offset) }
    }
}
