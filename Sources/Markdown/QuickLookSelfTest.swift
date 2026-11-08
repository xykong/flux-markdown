import AppKit
import QuickLookUI

/// User-initiated actual QuickLook preview. No default editor changes, cache deletion or content collection.
final class QuickLookSelfTest {
    static let shared = QuickLookSelfTest()
    private var window: NSWindow?
    private var preview: QLPreviewView?
    private var directory: URL?
    private var token = ""
    private var generation = UUID()
    private var completion: ((Bool) -> Void)?
    private var attempts = 0

    func start(probeToken: UUID = UUID(), completion: @escaping (Bool) -> Void) {
        guard self.completion == nil else { completion(false); return }
        self.completion = completion
        generation = UUID(); token = probeToken.uuidString; attempts = 0
        do {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("FluxMarkdown-QuickLook-\(token)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            self.directory = directory
            let file = directory.appendingPathComponent("\(QuickLookProbeEvidence.prefix)\(token).md")
            try QuickLookProbeEvidence.fixture.write(to: file, atomically: true, encoding: .utf8)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                                  styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = NSLocalizedString("Test Quick Look", comment: "QuickLook self-test")
            window.isReleasedWhenClosed = false
            guard let preview = QLPreviewView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), style: .normal) else {
                finish(false); return
            }
            self.window = window; self.preview = preview
            preview.autoresizingMask = [.width, .height]
            window.contentView = preview
            preview.previewItem = file as NSURL
            window.center(); window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            poll()
        } catch { finish(false) }
    }

    private func poll() {
        let generation = self.generation, token = self.token
        let extensionURL = Bundle.main.bundleURL.appendingPathComponent("Contents/PlugIns/MarkdownPreview.appex")
        guard let bundle = Bundle(url: extensionURL), let executableURL = bundle.executableURL,
              let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String else {
            finish(false); return
        }
        attempts += 1
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
            let result = QuickLookRegistration.run("/usr/bin/log", ["show", "--last", "1m", "--style", "json", "--predicate",
                "subsystem == 'com.markdownquicklook.app' AND eventMessage CONTAINS '\(token)'"])
            let success = result.status == 0 && QuickLookProbeEvidence.rendered(in: result.output, token: token, version: version, build: build, executableURL: executableURL)
            DispatchQueue.main.async {
                guard generation == self.generation, self.completion != nil else { return }
                if success { self.finish(true) }
                else if self.attempts >= 8 || self.window?.isVisible != true { self.finish(false) }
                else { self.poll() }
            }
        }
    }

    private func finish(_ passed: Bool) {
        let completion = self.completion; self.completion = nil
        generation = UUID()
        preview?.close(); preview = nil
        window?.close(); window = nil
        if let directory { try? FileManager.default.removeItem(at: directory) }
        directory = nil
        UserDefaults.standard.set(passed ? "rendered" : "unconfirmed", forKey: "quickLookLastProbeResult")
        UserDefaults.standard.set(Date(), forKey: "quickLookLastProbeDate")
        UserDefaults.standard.set(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString"), forKey: "quickLookLastProbeVersion")
        completion?(passed)
    }

    func show() {
        start { passed in
            if !passed {
                ErrorFeedback.present(ErrorFeedback.capture(.quickLook), recoveryTitle: "Try Again", recovery: { self.show() })
                return
            }
            let alert = NSAlert()
            alert.messageText = NSLocalizedString(passed ? "Quick Look preview verified" : "Quick Look preview not confirmed", comment: "QuickLook probe result")
            alert.informativeText = NSLocalizedString(passed ? "The installed extension rendered the test document. Your default editor was preserved." : "The test did not confirm a rendered preview. Include Quick Look diagnostics when reporting this issue.", comment: "QuickLook probe guidance")
            alert.runModal()
        }
    }
}
