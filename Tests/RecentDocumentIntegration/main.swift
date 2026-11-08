import AppKit
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let systemOnly = CommandLine.arguments.contains("--system-only")
let history = RecentDocumentHistory()
let controller = NSDocumentController.shared
if !systemOnly { history.migrate(controller.recentDocumentURLs) }
if CommandLine.arguments.contains("--add") {
    let url = URL(fileURLWithPath: CommandLine.arguments.last!)
    controller.noteNewRecentDocumentURL(url)
    if !systemOnly { history.record(url) }
}
if CommandLine.arguments.contains("--clear") { controller.clearRecentDocuments(nil); if !systemOnly { history.clear() } }
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    print("recent-count=\((systemOnly ? controller.recentDocumentURLs : history.urls).count)")
    exit(0)
}
app.run()
