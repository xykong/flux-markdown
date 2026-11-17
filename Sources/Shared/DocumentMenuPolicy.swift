import AppKit

/// DocumentGroup owns Open. Keep its command and substitute the durable history
/// menu for the separately injected native recent-documents menu.
enum DocumentMenuPolicy {
    private static var observers: [NSObjectProtocol] = []
    private static var scheduled = false

    static func startObserving() {
        guard observers.isEmpty else { return }
        for name in [NSMenu.didAddItemNotification, NSMenu.didChangeItemNotification] {
            observers.append(NotificationCenter.default.addObserver(forName:name, object:nil, queue:.main) { _ in
                guard !scheduled else { return }
                scheduled = true
                DispatchQueue.main.async {
                    reconcile(NSApp.mainMenu)
                    scheduled = false
                }
            })
        }
        reconcile(NSApp.mainMenu)
    }

    static func reconcile(_ mainMenu: NSMenu?) {
        let clear = #selector(NSDocumentController.clearRecentDocuments(_:))
        for menu in mainMenu?.items.compactMap(\.submenu) ?? [] {
            let customRecent = menu.items.first { item in
                item.submenu?.items.contains(where: {
                    $0.title == NSLocalizedString("Clear Menu", comment: "Recent documents menu") && $0.action != clear
                }) == true
            }
            guard let customRecent else { continue }
            for item in menu.items where item !== customRecent {
                if item.submenu?.items.contains(where: { $0.action == clear }) == true { menu.removeItem(item) }
            }
            if let open = menu.items.first(where: {
                $0.keyEquivalent.lowercased() == "o" && $0.keyEquivalentModifierMask.contains(.command)
            }),
               menu.index(of: customRecent) != menu.index(of: open) + 1 {
                menu.removeItem(customRecent)
                menu.insertItem(customRecent, at: menu.index(of: open) + 1)
            }
            var previousSeparator = false
            for item in menu.items {
                if item.isSeparatorItem && previousSeparator { menu.removeItem(item) }
                previousSeparator = item.isSeparatorItem
            }
        }
    }
}
