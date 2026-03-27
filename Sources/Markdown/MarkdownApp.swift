import SwiftUI
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate {
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: UpdateDelegate.shared,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("✅ Sparkle updater controller initialized")

        if CommandLine.arguments.contains("--register-only") {
            NSApplication.shared.terminate(nil)
        }

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        UpdateRestorationManager.shared.restoreLastOpenedFile()
    }

    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            print("❌ Invalid URL event")
            return
        }

        print("🔵 Received URL: \(urlString)")

        if url.scheme == "markdownpreview",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let path = components.queryItems?.first(where: { $0.name == "path" })?.value {
            let fileURL = URL(fileURLWithPath: path)
            print("🔵 Opening file: \(fileURL.path)")
            NSDocumentController.shared.openDocument(withContentsOf: fileURL, display: true) { _, _, error in
                if let error = error {
                    print("❌ Failed to open document: \(error.localizedDescription)")
                } else {
                    print("✅ Successfully opened document")
                }
            }
        }
    }

    func application(_ application: NSApplication, openFile filename: String) -> Bool {
        let fileURL = URL(fileURLWithPath: filename)
        UpdateRestorationManager.shared.saveLastOpenedFile(url: fileURL)
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Flush any debounced preference writes before exit
        AppearancePreference.shared.flushSharedPreferences()
    }
}

@main
struct MarkdownApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var preference = AppearancePreference.shared

    @State private var viewMode: ViewMode = .preview

    var body: some Scene {
        WindowGroup {
            WelcomeView()
        }
        .windowStyle(.titleBar)

        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ZStack(alignment: .topTrailing) {
                MarkdownWebView(
                    content: file.document.text,
                    fileURL: file.fileURL,
                    appearanceMode: preference.currentMode,
                    viewMode: viewMode,
                    baseFontSize: preference.baseFontSize,
                    enableMermaid: preference.enableMermaid,
                    enableKatex: preference.enableKatex,
                    enableEmoji: preference.enableEmoji,
                    codeHighlightTheme: preference.codeHighlightTheme
                )

                HStack(spacing: 8) {
                    Button(action: {
                        NotificationCenter.default.post(name: .toggleHelp, object: nil)
                    }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.secondary)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(Color.black.opacity(0.1))
                    .clipShape(Circle())
                    .help("Show Help")

                    Button(action: {
                        viewMode = (viewMode == .preview) ? .source : .preview
                    }) {
                        Image(systemName: viewMode == .source ? "eye.fill" : "doc.text.fill")
                            .foregroundColor(viewMode == .source ? .blue : .secondary)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(Color.black.opacity(0.1))
                    .clipShape(Circle())
                    .help(viewMode == .source ? "Show Preview" : "Show Source")

                    Button(action: {
                        let current = preference.currentMode
                        preference.currentMode = (current == .dark) ? .light : .dark
                    }) {
                        Image(systemName: preference.currentMode == .dark ? "sun.max.fill" : "moon.fill")
                            .foregroundColor(preference.currentMode == .dark ? .yellow : .secondary)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(Color.black.opacity(0.1))
                    .clipShape(Circle())
                    .help(preference.currentMode == .dark ? "Light Mode" : "Dark Mode")
                }
                .padding([.top, .trailing], 10)
            }
            .onAppear {
                if let fileURL = file.fileURL {
                    UpdateRestorationManager.shared.saveLastOpenedFile(url: fileURL)
                }
            }
            .frame(minWidth: 800, idealWidth: 1000, maxWidth: .infinity,
                   minHeight: 600, idealHeight: 800, maxHeight: .infinity)
            .environmentObject(preference)
            .background(WindowAccessor())
        }
        .commands {
            CommandGroup(after: .saveItem) {
                Divider()
                Button(action: {
                    NotificationCenter.default.post(name: .exportHTML, object: nil)
                }) {
                    Text(NSLocalizedString("Export as HTML…", comment: "Export HTML menu item"))
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                
                Button(action: {
                    NotificationCenter.default.post(name: .exportPDF, object: nil)
                }) {
                    Text(NSLocalizedString("Export as PDF…", comment: "Export PDF menu item"))
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
            
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updaterController: appDelegate.updaterController)
            }

            CommandGroup(after: .textEditing) {
                Divider()
                Button(action: {
                    NotificationCenter.default.post(name: .toggleSearch, object: nil)
                }) {
                    Text(NSLocalizedString("Find...", comment: "Search menu item"))
                }
                .keyboardShortcut("f", modifiers: [.command])
            }

            CommandGroup(replacing: .help) {
                Button(NSLocalizedString("FluxMarkdown Help", comment: "Help menu item")) {
                    if let url = URL(string: "https://github.com/xykong/flux-markdown/blob/master/docs/user/HELP.md") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .keyboardShortcut("?", modifiers: [.command])
                
                Divider()
                
                Button(NSLocalizedString("README", comment: "README menu item")) {
                    if let url = URL(string: "https://github.com/xykong/flux-markdown#readme") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Button(NSLocalizedString("Report an Issue", comment: "Report issue menu item")) {
                    if let url = URL(string: "https://github.com/xykong/flux-markdown/issues") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Divider()
                
                Button(NSLocalizedString("Release Notes", comment: "Release notes menu item")) {
                    if let url = URL(string: "https://github.com/xykong/flux-markdown/releases") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            CommandGroup(after: .toolbar) {
                Button(action: {
                    viewMode = (viewMode == .preview) ? .source : .preview
                }) {
                    Text(viewMode == .source ? "Show Preview" : "Show Source")
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])

                Divider()

                Menu("Appearance") {
                    ForEach(AppearanceMode.allCases) { mode in
                        Button(action: {
                            preference.currentMode = mode
                        }) {
                            HStack {
                                Text(mode.displayName)
                                if preference.currentMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        }

        Settings {
            SettingsView()
        }
    }
}

struct CheckForUpdatesView: View {
    let updaterController: SPUStandardUpdaterController

    var body: some View {
        Button(NSLocalizedString("Check for Updates...", comment: "Check for updates menu item")) {
            print("🔍 [DEBUG] Triggering update check...")
            NSApp.sendAction(#selector(SPUStandardUpdaterController.checkForUpdates(_:)), to: updaterController, from: nil)
        }
        .keyboardShortcut("u", modifiers: [.command])
        Divider()
    }
}
