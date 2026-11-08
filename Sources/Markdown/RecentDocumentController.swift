import AppKit

/// Created before SwiftUI initializes NSDocumentController.shared.
/// AppKit still owns document opening, menu construction and error presentation.
final class RecentDocumentController: NSDocumentController {
    private let history = RecentDocumentHistory()

    override init() {
        super.init()
        restoreHistory()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        restoreHistory()
    }

    private func restoreHistory() {
        history.migrate(super.recentDocumentURLs)
        // Re-seed the system menu after a signing-identity change. Reversing
        // preserves MRU order because AppKit inserts each entry at the front.
        for url in history.urls.reversed() { super.noteNewRecentDocumentURL(url) }
    }

    override var recentDocumentURLs: [URL] { history.urls }

    override func noteNewRecentDocumentURL(_ url: URL) {
        history.record(url)
        super.noteNewRecentDocumentURL(url)
    }

    override func clearRecentDocuments(_ sender: Any?) {
        history.clear()
        super.clearRecentDocuments(sender)
    }
}
