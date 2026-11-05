import AppKit
import QuickLookUI

/// Uses the system-selected QuickLook provider, not a direct renderer WKWebView.
/// No primary-screen fallback; foreground activation requires an explicit policy.
@main
struct QuickLookHost {
    static func main() {
        guard CommandLine.arguments.count == 2 else {
            fputs("Usage: Issue64QuickLookHost /absolute/fixture.md\n", stderr); exit(2)
        }
        let app = NSApplication.shared
        let delegate = PreviewDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

private final class PreviewDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var preview: QLPreviewView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let policy = TestWindowPolicy(environment: ProcessInfo.processInfo.environment),
              policy != .ciForeground else {
            fputs("System-host validation requires a secondary-display policy\n", stderr); exit(2)
        }
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 800),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        guard let frame = policy.frame(size: window.frame.size, screens: NSScreen.screens.map({ $0.visibleFrame })) else {
            fputs("Required secondary display unavailable or too small\n", stderr); exit(2)
        }
        window.setFrame(frame, display: false)
        window.title = "Issue64 Secondary QuickLook Validation"
        window.delegate = self
        window.isReleasedWhenClosed = false
        guard let preview = QLPreviewView(frame: window.contentView!.bounds, style: .normal) else { exit(2) }
        self.preview = preview
        preview.autoresizingMask = [.width, .height]
        window.contentView = preview
        preview.previewItem = URL(fileURLWithPath: CommandLine.arguments[1]) as NSURL
        if policy.allowsFocus {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            window.orderBack(nil)
        }
        print("System QuickLook secondary frame: \(window.frame)")
        fflush(stdout)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1200) { NSApp.terminate(nil) }
    }

    func windowWillClose(_ notification: Notification) {
        preview.close()
        NSApp.terminate(nil)
    }
}
