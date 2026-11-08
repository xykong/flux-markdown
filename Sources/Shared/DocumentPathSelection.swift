import AppKit
import Combine

/// Track the native key window, including when WKWebView owns first responder.
/// SwiftUI FocusedValue alone does not cover AppKit-backed document focus on macOS 11.
final class DocumentPathSelection: ObservableObject {
    static let shared = DocumentPathSelection()
    @Published private(set) var url: URL?
    private weak var selectedWindow: NSWindow?
    private let urls = NSMapTable<NSWindow, NSURL>(keyOptions: .weakMemory, valueOptions: .strongMemory)
    private var observers: [NSObjectProtocol] = []

    init(observeWindows: Bool = true) {
        guard observeWindows else { return }
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] note in
            self?.select(note.object as? NSWindow)
        })
        for name in [NSWindow.didResignKeyNotification, NSWindow.willCloseNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let self, let window = note.object as? NSWindow, self.selectedWindow === window else { return }
                self.select(nil)
            })
        }
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    func register(_ url: URL?, for window: NSWindow) {
        if let url, url.isFileURL { urls.setObject(url as NSURL, forKey: window) }
        else { urls.removeObject(forKey: window) }
        if window.isKeyWindow || selectedWindow === window { select(window) }
    }

    func select(_ window: NSWindow?) {
        selectedWindow = window
        let next = window.flatMap { urls.object(forKey: $0) as URL? }
        if url != next { url = next }
    }
}
