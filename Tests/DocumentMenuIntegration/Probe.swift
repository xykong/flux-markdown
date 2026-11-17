import AppKit
import SwiftUI
import UniformTypeIdentifiers

// Exercise SwiftUI's real DocumentGroup menu injection in a disposable app.
private struct ProbeDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    init() {}
    init(configuration: ReadConfiguration) throws {}
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data())
    }
}
private struct ProbeCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Probe New") { NSDocumentController.shared.newDocument(nil) }
            Menu("Probe Recent") { Button(NSLocalizedString("Clear Menu",comment:"")) {} }
        }
    }
}
private func checkMenu(_ stage: String) {
    let main = NSApplication.shared.mainMenu
    DocumentMenuPolicy.reconcile(main)
    let items = main?.items.compactMap(\.submenu).flatMap(\.items) ?? []
    guard items.filter({$0.keyEquivalent == "o" && $0.keyEquivalentModifierMask.contains(.command)}).count == 1,
          items.filter({$0.title == "Probe Recent"}).count == 1,
          items.contains(where: {$0.action == #selector(NSDocumentController.openDocument(_:))}) else {
        fputs("FAIL document menu: \(stage)\n", stderr); exit(1)
    }
    print("PASS SwiftUI document menu: \(stage), one Open and one Recent")
}
@main private struct MenuProbe: App {
    init() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        DocumentMenuPolicy.startObserving()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            checkMenu("welcome")
            NSDocumentController.shared.newDocument(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                checkMenu("document")
                exit(0)
            }
        }
    }
    var body: some Scene {
        WindowGroup { Text("Menu probe") }
        DocumentGroup(newDocument: ProbeDocument()) { _ in Text("Document") }
            .commands { ProbeCommands() }
    }
}
