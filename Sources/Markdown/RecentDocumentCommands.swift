import SwiftUI
import AppKit

/// SwiftUI owns its document controller. Keep durable history in the app menu
/// rather than replacing SwiftUI's private controller and breaking DocumentGroup.
struct RecentDocumentCommands: Commands {
    @ObservedObject private var history = RecentDocumentHistory.shared

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(NSLocalizedString("New Document", comment: "File menu")) {
                NSDocumentController.shared.newDocument(nil)
            }.keyboardShortcut("n")
            Button(NSLocalizedString("Open…", comment: "File menu")) {
                NSDocumentController.shared.openDocument(nil)
            }.keyboardShortcut("o")
            Menu(NSLocalizedString("Open Recent", comment: "File menu")) {
                ForEach(history.urls, id: \.self) { url in
                    Button(url.lastPathComponent) { open(url) }
                        .help(url.path)
                }
                Divider()
                Button(NSLocalizedString("Clear Menu", comment: "Recent documents menu")) {
                    history.clear()
                    NSDocumentController.shared.clearRecentDocuments(nil)
                }.disabled(history.urls.isEmpty)
            }
        }
    }

    private func open(_ url: URL) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
            if let error {
                let incident = ErrorFeedback.capture(.fileRead, error: error)
                ErrorFeedback.present(incident, recoveryTitle: "Choose Another File", recovery: {
                    NSDocumentController.shared.openDocument(nil)
                })
            } else { history.record(url) }
        }
    }
}
