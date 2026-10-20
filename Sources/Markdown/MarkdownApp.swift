import SwiftUI
import AppKit
import Sparkle
import os.log

class AppDelegate: NSObject, NSApplicationDelegate {
    let updaterController = AppUpdaterController()

    private var preferenceObservationTimer: Timer?

    func applicationDidBecomeActive(_ notification: Notification) {
        AppearancePreference.shared.observePreferenceChanges()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Register before launch events are delivered, including a URL that
        // starts the application rather than targeting an existing process.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        ErrorFeedback.supplementProvider = { incident, completion in
            DispatchQueue.global(qos: .utility).async {
                let summary = QuickLookRegistration.diagnosticSummary()
                var fields: [String: String] = [:]
                for line in summary.components(separatedBy: "\n") where line.hasPrefix("- ") {
                    let parts = line.dropFirst(2).components(separatedBy: ": ")
                    if parts.count == 2 { fields[parts[0]] = parts[1] }
                }
                var enriched = incident
                enriched.quickLookCheck = IncidentQuickLookCheck(date: Date(), fields: IncidentQuickLookCheck.sanitize(fields))
                completion(enriched)
            }
        }
        _ = StarReminderStore.shared
        NotificationCenter.default.addObserver(forName: Notification.Name("FluxMarkdown.TestQuickLook"), object: nil, queue: .main) { _ in
            QuickLookSelfTest.shared.show()
        }
        preferenceObservationTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            AppearancePreference.shared.observePreferenceChanges()
        }
        print("✅ Sparkle updater controller initialized")

        if CommandLine.arguments.contains("--register-only") {
            NSApplication.shared.terminate(nil)
        }

        UpdateRestorationManager.shared.restoreLastOpenedFile()
    }

    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            print("❌ Invalid URL event")
            return
        }

        if ErrorFeedback.receive(url) { return }

        guard let request = DocumentOpenRequest(url: url) else { return }
        os_log("Document URL request received; position=%{public}@ placement=%{public}d", type: .info,
               request.position == nil ? "none" : "explicit", request.windowPlacement == nil ? 0 : 1)
        let id = request.position.map { DocumentPositionStore.shared.set($0, for: request.fileURL) }
        let searchID = request.wantsSearch ? DocumentPositionStore.searchRequests.set(.search, for: request.fileURL) : nil
        let placementID = request.windowPlacement.map { DocumentWindowPlacementStore.shared.set($0, for: request.fileURL) }
        NSDocumentController.shared.openDocument(withContentsOf: request.fileURL, display: true) { document, alreadyOpen, error in
            if error != nil {
                if let id { DocumentPositionStore.shared.discard(for: request.fileURL, id: id) }
                if let searchID { DocumentPositionStore.searchRequests.discard(for: request.fileURL, id: searchID) }
                if let placementID { DocumentWindowPlacementStore.shared.discard(for: request.fileURL, id: placementID) }
                return
            }
            if alreadyOpen, let window = document?.windowControllers.first?.window {
                WindowAccessor.applyPendingSearchPlacement(to: window, for: request.fileURL)
            }
            NotificationCenter.default.post(name: DocumentPositionStore.notification, object: request.fileURL)
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
                
                Button(NSLocalizedString("Repair Quick Look…", comment: "QuickLook recovery menu")) {
                    QuickLookRepairController.shared.show()
                }
                Button(NSLocalizedString("Report an Issue", comment: "Report issue menu item")) {
                    FeedbackWindowController.shared.show()
                }
                Button(ErrorFeedback.text("Review Last Error…")) { ErrorFeedback.showLatest() }
                Button(ErrorFeedback.text("Clear Error History")) { ErrorFeedback.clearHistory() }
                Button(NSLocalizedString("Suggest a Feature…", comment: "Feature feedback menu")) {
                    if !NSWorkspace.shared.open(FeedbackIssueLink.feature) {
                        FeedbackWindowController.shared.showFeatureFallback()
                    }
                }
                
                Divider()
                
                Button(NSLocalizedString("Test Quick Look", comment: "QuickLook self-test")) { QuickLookSelfTest.shared.show() }

                Button(action: GitHubStar.showRepository) {
                    Label(NSLocalizedString("Star on GitHub", comment: "Support project"), systemImage: "star")
                }

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

                Button(NSLocalizedString("Zoom In", comment: "Zoom in menu item")) {
                    NotificationCenter.default.post(name: .zoomIn, object: nil)
                }
                .keyboardShortcut("=", modifiers: .command)

                Button(NSLocalizedString("Zoom Out", comment: "Zoom out menu item")) {
                    NotificationCenter.default.post(name: .zoomOut, object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)

                Divider()

                Menu(NSLocalizedString("Appearance", comment: "Appearance submenu")) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Button(action: {
                            preference.setAppearance(mode, source: .toolbar)
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
    @StateObject private var starReminder = StarReminderSession()
    @State private var toolbarToast: ToolbarToastState?
    @State private var nativeToolbarTrailingInset: CGFloat = 10

    private let initialContentSize: CGSize
    private let reloadSuccessToastMessage = NSLocalizedString("Document reloaded", comment: "Reload success toast")
    private let reloadFailureToastMessage = NSLocalizedString("Reload failed", comment: "Reload failure toast")
    private let resetZoomToastMessage = NSLocalizedString("Zoom reset", comment: "Reset zoom toast")

    init(file: FileDocumentConfiguration<MarkdownDocument>, preference: AppearancePreference, viewMode: Binding<ViewMode>) {
        self.file = file
        self.preference = preference
        self._viewMode = viewMode
        let savedFrame = AppearancePreference.shared.hostWindowFrame
        self.initialContentSize = WindowAccessor.initialDocumentContentSize(savedFrame: savedFrame)
    }

    var body: some View {
        VStack(spacing: 0) {
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
                showLineNumbers: preference.showLineNumbers,
                contentsSide: preference.contentsSide,
                starReminder: starReminder
            )

            if let version = DisplayVersion.text(in: .main) {
                Text("v\(version)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(Color.secondary.opacity(0.5))
                    .padding(.top, 48)
                    .padding(.trailing, 72)
            }

            HStack(spacing: 8) {
                CircularToolbarIconButton(
                    systemName: "arrow.clockwise",
                    foregroundColor: Color(NSColor.labelColor),
                    helpText: NSLocalizedString("Reload File (⌘R)", comment: "Reload file tooltip"),
                    appearance: preference.currentMode.nsAppearance
                ) {
                    showToolbarToast(reloadSuccessToastMessage)
                    NotificationCenter.default.post(name: .reloadFile, object: nil)
                }

                CircularToolbarIconButton(
                    systemName: "textformat.size.smaller",
                    foregroundColor: Color(NSColor.labelColor),
                    helpText: NSLocalizedString("Zoom Out", comment: "Zoom out tooltip"),
                    appearance: preference.currentMode.nsAppearance
                ) {
                    NotificationCenter.default.post(name: .zoomOut, object: nil)
                }

                CircularToolbarIconButton(
                    systemName: "arrow.uturn.backward",
                    foregroundColor: Color(NSColor.labelColor),
                    helpText: NSLocalizedString("Reset Zoom (⌘0)", comment: "Reset zoom tooltip"),
                    appearance: preference.currentMode.nsAppearance
                ) {
                    showToolbarToast(resetZoomToastMessage)
                    NotificationCenter.default.post(name: .resetZoom, object: nil)
                }

                CircularToolbarIconButton(
                    systemName: "textformat.size.larger",
                    foregroundColor: Color(NSColor.labelColor),
                    helpText: NSLocalizedString("Zoom In", comment: "Zoom in tooltip"),
                    appearance: preference.currentMode.nsAppearance
                ) {
                    NotificationCenter.default.post(name: .zoomIn, object: nil)
                }

                CircularToolbarIconButton(
                    systemName: "questionmark.circle",
                    foregroundColor: Color(NSColor.labelColor),
                    helpText: NSLocalizedString("Show Help", comment: "Show help tooltip"),
                    appearance: preference.currentMode.nsAppearance
                ) {
                    NotificationCenter.default.post(name: .toggleHelp, object: nil)
                }

                CircularToolbarIconButton(
                    systemName: viewMode == .source ? "eye.fill" : "doc.text.fill",
                    foregroundColor: viewMode == .source ? .blue : Color(NSColor.labelColor),
                    helpText: viewMode == .source
                        ? NSLocalizedString("Show Preview", comment: "Show preview tooltip")
                        : NSLocalizedString("Show Source", comment: "Show source tooltip"),
                    appearance: preference.currentMode.nsAppearance
                ) {
                    viewMode = (viewMode == .preview) ? .source : .preview
                }

                CircularToolbarIconButton(
                    systemName: preference.currentMode == .light ? "sun.max.fill" : preference.currentMode == .dark ? "moon.fill" : "circle.lefthalf.filled",
                    foregroundColor: preference.currentMode == .light ? .yellow : Color(NSColor.labelColor),
                    helpText: NSLocalizedString("Toggle Theme (System / Light / Dark)", comment: "Theme toggle tooltip"),
                    appearance: preference.currentMode.nsAppearance
                ) {
                    switch preference.currentMode {
                    case .system: preference.setAppearance(.light, source: .toolbar)
                    case .light:  preference.setAppearance(.dark, source: .toolbar)
                    case .dark:   preference.setAppearance(.system, source: .toolbar)
                    }
                }
            }
            .padding(.top, 10)
            .padding(.trailing, nativeToolbarTrailingInset)

            ToolbarFeedbackToastHost(toast: toolbarToast)
                .allowsHitTesting(false)
                .zIndex(3)
        }
        StarReminderCard(session: starReminder)
            .preferredColorScheme(preference.currentMode == .system ? nil : (preference.currentMode == .dark ? .dark : .light))
        }
        .onDisappear { starReminder.invalidate() }
        .onReceive(NotificationCenter.default.publisher(for: ReadingToolbarLayout.notification)) { note in
            guard (note.object as? URL)?.standardizedFileURL == file.fileURL?.standardizedFileURL,
                  let inset = note.userInfo?["inset"] as? CGFloat else { return }
            if nativeToolbarTrailingInset != inset { nativeToolbarTrailingInset = inset }
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
        .background(WindowAccessor(fileURL: file.fileURL))
        .background(ToolbarFeedbackObserver { result in
            switch result {
            case .reloadSuccess:
                showToolbarToast(reloadSuccessToastMessage)
            case .reloadFailure:
                showToolbarToast(reloadFailureToastMessage)
            case .resetZoom:
                showToolbarToast(resetZoomToastMessage)
            }
        })
        .interfaceLayoutDirection(for: preference.uiLanguage)
    }

    private func showToolbarToast(_ message: String) {
        NSLog("✅ Toolbar feedback toast requested: %@", message)
        let id = UUID()
        let toast = ToolbarToastState(id: id, message: message)

        withAnimation(.easeOut(duration: 0.16)) {
            toolbarToast = toast
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeIn(duration: 0.18)) {
                if toolbarToast?.id == id {
                    toolbarToast = nil
                }
            }
        }
    }
}

private struct ToolbarToastState: Equatable {
    let id: UUID
    let message: String
}

private struct ToolbarFeedbackToastHost: NSViewRepresentable {
    let toast: ToolbarToastState?

    func makeNSView(context: Context) -> ToolbarFeedbackToastHostView {
        ToolbarFeedbackToastHostView()
    }

    func updateNSView(_ nsView: ToolbarFeedbackToastHostView, context: Context) {
        nsView.update(toast: toast)
    }
}

private final class ToolbarFeedbackToastHostView: NSView {
    private var currentToastID: UUID?
    private weak var toastView: NSView?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(toast: ToolbarToastState?) {
        guard let toast else {
            removeToast()
            return
        }

        guard currentToastID != toast.id else { return }
        currentToastID = toast.id
        showToast(message: toast.message)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            removeToast()
        }
    }

    private func showToast(message: String) {
        removeToast()

        let toastContainer = ToolbarToastContainerView()
        toastContainer.setAccessibilityElement(true)
        toastContainer.setAccessibilityLabel(message)

        let messageLabel = NSTextField(labelWithString: message)
        messageLabel.font = .systemFont(ofSize: 13, weight: .medium)
        messageLabel.textColor = .labelColor
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        toastContainer.addSubview(messageLabel)
        addSubview(toastContainer)

        NSLayoutConstraint.activate([
            toastContainer.topAnchor.constraint(equalTo: topAnchor, constant: 52),
            toastContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            messageLabel.topAnchor.constraint(equalTo: toastContainer.topAnchor, constant: 8),
            messageLabel.bottomAnchor.constraint(equalTo: toastContainer.bottomAnchor, constant: -8),
            messageLabel.leadingAnchor.constraint(equalTo: toastContainer.leadingAnchor, constant: 14),
            messageLabel.trailingAnchor.constraint(equalTo: toastContainer.trailingAnchor, constant: -14)
        ])

        toastContainer.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            toastContainer.animator().alphaValue = 1
        }

        toastView = toastContainer
    }

    private func removeToast() {
        toastView?.removeFromSuperview()
        toastView = nil
        currentToastID = nil
    }

    private final class ToolbarToastContainerView: NSView {
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            configure()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            configure()
        }

        private func configure() {
            wantsLayer = true
            translatesAutoresizingMaskIntoConstraints = false
            layerContentsRedrawPolicy = .onSetNeedsDisplay
        }

        override func layout() {
            super.layout()
            applyToastStyle()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyToastStyle()
        }

        private func applyToastStyle() {
            guard let layer else { return }

            CATransaction.begin()
            CATransaction.setDisableActions(true)

            let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2

            layer.masksToBounds = false
            layer.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.97).cgColor
            layer.cornerRadius = 12
            layer.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
            layer.borderWidth = 1 / scale
            layer.shadowColor = NSColor.black.withAlphaComponent(0.18).cgColor
            layer.shadowOpacity = 1
            layer.shadowRadius = 10
            layer.shadowOffset = NSSize(width: 0, height: -4)
            layer.shadowPath = CGPath(roundedRect: bounds, cornerWidth: 12, cornerHeight: 12, transform: nil)

            CATransaction.commit()
        }
    }

}

private struct ToolbarFeedbackToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Color(NSColor.labelColor))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.94))
                    .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(NSColor.separatorColor).opacity(0.45), lineWidth: 1)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityLabel(message)
    }
}

private struct ToolbarFeedbackObserver: NSViewRepresentable {
    let onResult: (ToolbarFeedbackResult) -> Void

    func makeNSView(context: Context) -> WindowObservingToolbarFeedbackView {
        let view = WindowObservingToolbarFeedbackView()
        view.onWindowAttach = { window in
            context.coordinator.router.monitor(window: window)
        }
        return view
    }

    func updateNSView(_ nsView: WindowObservingToolbarFeedbackView, context: Context) {
        context.coordinator.router.onResult = onResult
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }

    final class Coordinator: NSObject {
        let router: ToolbarFeedbackNotificationRouter

        init(onResult: @escaping (ToolbarFeedbackResult) -> Void) {
            router = ToolbarFeedbackNotificationRouter(onResult: onResult)
        }
    }
}

private final class WindowObservingToolbarFeedbackView: NSView {
    var onWindowAttach: ((NSWindow) -> Void)?
    private weak var attachedWindow: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, attachedWindow !== window else { return }
        attachedWindow = window
        onWindowAttach?(window)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject var updaterController: AppUpdaterController

    var body: some View {
        Button(NSLocalizedString("Check for Updates...", comment: "Check for updates menu item")) {
            print("🔍 [DEBUG] Triggering update check...")
            updaterController.checkForUpdates()
        }
        .disabled(!updaterController.canCheckForUpdates)
        .keyboardShortcut("u", modifiers: [.command])
        Divider()
    }
}
