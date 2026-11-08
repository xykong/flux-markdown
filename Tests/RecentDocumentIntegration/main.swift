import AppKit
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
if !CommandLine.arguments.contains("--system-only") { _ = RecentDocumentController() }
let controller = NSDocumentController.shared
if CommandLine.arguments.contains("--add") {
    controller.noteNewRecentDocumentURL(URL(fileURLWithPath: CommandLine.arguments.last!))
}
if CommandLine.arguments.contains("--clear") { controller.clearRecentDocuments(nil) }
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    print("recent-count=\(controller.recentDocumentURLs.count)")
    exit(0)
}
app.run()
