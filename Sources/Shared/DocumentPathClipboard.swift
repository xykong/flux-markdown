import AppKit

enum DocumentPathClipboard {
    /// Plain filesystem path, not a percent-encoded URL or shell command.
    static func copy(_ url: URL, to pasteboard: NSPasteboard = .general) -> Bool {
        guard url.isFileURL else { return false }
        pasteboard.clearContents()
        return pasteboard.setString(url.path, forType: .string)
    }
}
