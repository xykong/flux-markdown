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
        AppearancePreference.shared.flushSharedPreferences()
    }
}

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
            DocumentPreviewScene(file: file, preference: preference, viewMode: $viewMode)
        }
        .commands {
            CommandGroup(after: .saveItem) {
                Button(action: {
                    NotificationCenter.default.post(name: .reloadFile, object: nil)
                }) {
                    Text(NSLocalizedString("Reload File", comment: "Reload file menu item"))
                }
                .keyboardShortcut("r", modifiers: [.command])
                Button(action: {
                    NotificationCenter.default.post(name: .openInExternalEditor, object: nil)
                }) {
                    Text(NSLocalizedString("Open in External Editor", comment: "Open in external editor menu item"))
                }
                .keyboardShortcut("e", modifiers: [.command, .option])
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
                    Text(viewMode == .source
                         ? NSLocalizedString("Show Preview", comment: "Show preview menu item")
                         : NSLocalizedString("Show Source", comment: "Show source menu item"))
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])

                Button(NSLocalizedString("Reset Zoom", comment: "Reset zoom menu item")) {
                    NotificationCenter.default.post(name: .resetZoom, object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()

                Menu(NSLocalizedString("Appearance", comment: "Appearance submenu")) {
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

private struct DocumentPreviewScene: View {
    let file: FileDocumentConfiguration<MarkdownDocument>
    @ObservedObject var preference: AppearancePreference
    @Binding var viewMode: ViewMode

    private let initialContentSize: CGSize

    init(file: FileDocumentConfiguration<MarkdownDocument>, preference: AppearancePreference, viewMode: Binding<ViewMode>) {
        self.file = file
        self.preference = preference
        self._viewMode = viewMode
        let savedFrame = AppearancePreference.shared.hostWindowFrame
        self.initialContentSize = WindowAccessor.initialDocumentContentSize(savedFrame: savedFrame)
    }

    var body: some View {
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
                enableTypst: preference.enableTypst,
                codeHighlightTheme: preference.codeHighlightTheme,
                collapseBlockquotesByDefault: preference.collapseBlockquotesByDefault,
                showLineNumbers: preference.showLineNumbers
            )

            if let version = DisplayVersion.text(in: .main) {
                Text("v\(version)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(Color.secondary.opacity(0.5))
                    .padding(.top, 48)
                    .padding(.trailing, 72)
            }

            HStack(spacing: 8) {
                ToolbarIconButton(
                    systemName: "arrow.clockwise",
                    foregroundColor: Color(NSColor.labelColor),
                    helpText: NSLocalizedString("Reload File (⌘R)", comment: "Reload file tooltip")
                ) {
                    NotificationCenter.default.post(name: .reloadFile, object: nil)
                }

                ToolbarIconButton(
                    systemName: "textformat.size.smaller",
                    foregroundColor: Color(NSColor.labelColor),
                    helpText: NSLocalizedString("Zoom Out", comment: "Zoom out tooltip")
                ) {
                    NotificationCenter.default.post(name: .zoomOut, object: nil)
                }

                ToolbarIconButton(
                    systemName: "arrow.uturn.backward",
                    foregroundColor: Color(NSColor.labelColor),
                    helpText: NSLocalizedString("Reset Zoom (⌘0)", comment: "Reset zoom tooltip")
                ) {
                    NotificationCenter.default.post(name: .resetZoom, object: nil)
                }

                ToolbarIconButton(
                    systemName: "textformat.size.larger",
                    foregroundColor: Color(NSColor.labelColor),
                    helpText: NSLocalizedString("Zoom In", comment: "Zoom in tooltip")
                ) {
                    NotificationCenter.default.post(name: .zoomIn, object: nil)
                }

                ToolbarIconButton(
                    systemName: "questionmark.circle",
                    foregroundColor: Color(NSColor.labelColor),
                    helpText: NSLocalizedString("Show Help", comment: "Show help tooltip")
                ) {
                    NotificationCenter.default.post(name: .toggleHelp, object: nil)
                }

                ToolbarIconButton(
                    systemName: viewMode == .source ? "eye.fill" : "doc.text.fill",
                    foregroundColor: viewMode == .source ? .blue : Color(NSColor.labelColor),
                    helpText: viewMode == .source
                        ? NSLocalizedString("Show Preview", comment: "Show preview tooltip")
                        : NSLocalizedString("Show Source", comment: "Show source tooltip")
                ) {
                    viewMode = (viewMode == .preview) ? .source : .preview
                }

                ToolbarIconButton(
                    systemName: preference.currentMode == .light ? "sun.max.fill" : preference.currentMode == .dark ? "moon.fill" : "circle.lefthalf.filled",
                    foregroundColor: preference.currentMode == .light ? .yellow : Color(NSColor.labelColor),
                    helpText: NSLocalizedString("Toggle Theme (System / Light / Dark)", comment: "Theme toggle tooltip")
                ) {
                    switch preference.currentMode {
                    case .system: preference.currentMode = .light
                    case .light:  preference.currentMode = .dark
                    case .dark:   preference.currentMode = .system
                    }
                }
            }
            .padding([.top, .trailing], 10)
        }
        .onAppear {
            if let fileURL = file.fileURL {
                UpdateRestorationManager.shared.saveLastOpenedFile(url: fileURL)
            }
        }
        .frame(
            minWidth: WindowAccessor.minimumRestorableWindowSize.width,
            idealWidth: initialContentSize.width,
            maxWidth: .infinity,
            minHeight: WindowAccessor.minimumRestorableWindowSize.height,
            idealHeight: initialContentSize.height,
            maxHeight: .infinity
        )
        .environmentObject(preference)
        .background(WindowAccessor())
    }
}

private struct ToolbarIconButton: View {
    let systemName: String
    let foregroundColor: Color
    let helpText: String
    let action: () -> Void

    var body: some View {
        ToolbarIconButtonRepresentable(
            systemName: systemName,
            foregroundColor: foregroundColor,
            helpText: helpText,
            action: action
        )
        .frame(width: 30, height: 30)
    }
}

private struct ToolbarIconButtonRepresentable: NSViewRepresentable {
    let systemName: String
    let foregroundColor: Color
    let helpText: String
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> ToolbarIconNSButton {
        let button = ToolbarIconNSButton(frame: NSRect(x: 0, y: 0, width: 30, height: 30))
        button.target = context.coordinator
        button.action = #selector(Coordinator.performAction)
        button.setButtonType(.momentaryChange)
        button.isBordered = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.imagePosition = .imageOnly
        button.bezelStyle = .regularSquare
        button.toolTip = helpText
        button.setAccessibilityLabel(helpText)
        return button
    }

    func updateNSView(_ button: ToolbarIconNSButton, context: Context) {
        context.coordinator.action = action
        button.toolTip = helpText
        button.setAccessibilityLabel(helpText)
        button.image = NSImage(systemSymbolName: systemName, accessibilityDescription: helpText)
        button.contentTintColor = NSColor(foregroundColor)
        button.needsDisplay = true
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func performAction() {
            action()
        }
    }
}

private final class ToolbarIconNSButton: NSButton {
    override var intrinsicContentSize: NSSize {
        NSSize(width: 30, height: 30)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.withAlphaComponent(0.85).setFill()
        NSBezierPath(ovalIn: bounds).fill()
        super.draw(dirtyRect)
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
