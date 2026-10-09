import AppKit
import SwiftUI

/// The About screen. It names the running build as the xluffy fork or the
/// upstream release, and it shows the fork version.
struct AboutView: View {
    private var displayVersion: String {
        DisplayVersion.text(in: .main) ?? "unknown"
    }

    private var isFork: Bool {
        AppIdentity.isFork(displayVersion: displayVersion)
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)

            Text(AppIdentity.appName)
                .font(.system(size: 22, weight: .bold))

            Text(AppIdentity.editionLabel(displayVersion: displayVersion))
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(
                        isFork
                            ? Color.orange.opacity(0.22)
                            : Color.gray.opacity(0.22)
                    )
                )

            Text("Version \(displayVersion)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)

            Text(AppIdentity.summary(displayVersion: displayVersion))
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Link("Fork repository", destination: AppIdentity.forkRepositoryURL)
                Link("Upstream", destination: AppIdentity.upstreamRepositoryURL)
            }
            .font(.system(size: 12))
        }
        .padding(24)
        .frame(width: 420)
    }
}

/// Shows the About screen in a small window.
final class AboutWindowController: NSWindowController {
    static let shared = AboutWindowController()

    private init() {
        let hosting = NSHostingController(rootView: AboutView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "About FluxMarkdown"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func present() {
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
