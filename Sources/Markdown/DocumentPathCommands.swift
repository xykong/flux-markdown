import SwiftUI
import AppKit

struct DocumentPathCommands: Commands {
    @ObservedObject private var selection = DocumentPathSelection.shared
    private var url: URL? { selection.url }

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Button(NSLocalizedString("Copy Document Path", comment: "Copy absolute document path")) {
                guard let url, url.isFileURL else { return }
                copy(url)
            }
            .keyboardShortcut("c", modifiers: [.command, .option])
            .disabled(url?.isFileURL != true)
        }
    }

    private func copy(_ url: URL) {
        guard DocumentPathClipboard.copy(url) else {
            let incident = ErrorFeedback.capture(.copy)
            ErrorFeedback.present(incident, recoveryTitle: "Try Again", recovery: { copy(url) })
            return
        }
    }
}

struct DocumentPathContext: NSViewRepresentable {
    let url: URL?
    final class ContextView: NSView {
        var url: URL?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            refresh()
        }
        func refresh() {
            guard let window else { return }
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window, self.window === window else { return }
                DocumentPathSelection.shared.register(self.url, for: window)
            }
        }
    }
    func makeNSView(context: Context) -> ContextView {
        let view = ContextView(); view.url = url; return view
    }
    func updateNSView(_ view: ContextView, context: Context) { view.url = url; view.refresh() }
}
