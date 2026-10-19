import Cocoa
import QuickLookUI
import os.log
import WebKit
import SwiftUI

final class QuickLookDoubleClickGestureRecognizer: NSClickGestureRecognizer {
    override func canPrevent(_ preventedGestureRecognizer: NSGestureRecognizer) -> Bool {
        if preventedGestureRecognizer is NSPanGestureRecognizer {
            return false
        }
        return super.canPrevent(preventedGestureRecognizer)
    }
}

enum QuickLookFindShortcut {
    static func isShowFindAction(_ sender: Any?) -> Bool {
        let tag = (sender as? NSMenuItem)?.tag ?? (sender as? NSControl)?.tag
        return tag == NSTextFinder.Action.showFindInterface.rawValue
    }
    static func matches(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
        return modifiers == .command && event.charactersIgnoringModifiers?.lowercased() == "f"
    }
}

// Subclass WKWebView to intercept mouse events and prevent them from bubbling up 
// to the QuickLook host, which would otherwise trigger "Open with default app".
class InteractiveWebView: NativeMagnifyingWebView {
    var searchShortcutHandler: (() -> Void)?

    override func performTextFinderAction(_ sender: Any?) {
        if QuickLookFindShortcut.isShowFindAction(sender), let searchShortcutHandler {
            searchShortcutHandler()
            return
        }
        super.performTextFinderAction(sender)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if QuickLookFindShortcut.matches(event), let searchShortcutHandler {
            searchShortcutHandler()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    private let logger = OSLog(subsystem: "com.markdownquicklook.app", category: "InteractiveWebView")

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override var acceptsFirstResponder: Bool {
        return false
    }
    
    override func scrollWheel(with event: NSEvent) {
        guard event.phase == .changed || event.phase == .began else {
            super.scrollWheel(with: event)
            return
        }

        if event.modifierFlags.contains(.command) {
            let delta = event.scrollingDeltaY
            guard abs(delta) > 0.1 else {
                super.scrollWheel(with: event)
                return
            }
            let newZoom = max(0.5, min(3.0, self.pageZoom + (delta > 0 ? 0.05 : -0.05)))
            self.pageZoom = newZoom
            AppearancePreference.shared.zoomLevel = newZoom
            os_log("🔵 Cmd+scroll zoom: %.2f", log: logger, type: .debug, newZoom)
            return
        }
        super.scrollWheel(with: event)
    }

}

enum ViewMode {
    case preview
    case source
}

public class PreviewViewController: NSViewController, QLPreviewingController, WKNavigationDelegate, WKScriptMessageHandler {

    var statusLabel: NSTextField!
    var webView: InteractiveWebView!
    private var truncationNotice: NSTextField?
    private let errorRegistry = RendererErrorRegistry()
    private func showFailure(_ kind: FailureKind, error: Error? = nil) {
        let incident = errorRegistry.nativeFailure(kind, error: error)
        IncidentNotice.attach(to: view, incident: incident, recoveryTitle: "Open in FluxMarkdown", recovery: { [weak self] in
            guard let self, let url = self.currentURL else { return }
            SearchLaunchClient.openForReading(url) { success in
                if !success { IncidentNotice.fallback(in: self.view, draft: IncidentDraft(incident)) }
            }
        })
    }
    private var previewIsTruncated = false
    private var previewHasUnreadableImages = false

    private func updateTruncationNotice(_ truncated: Bool) {
        previewIsTruncated = truncated
        if truncationNotice == nil {
            let label = NSTextField(wrappingLabelWithString: NSLocalizedString("Preview limited to 500 KiB. Use Open with FluxMarkdown above to read the complete document.", comment: "QuickLook truncation notice"))
            label.font = .systemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
            label.setAccessibilityLabel(label.stringValue)
            view.addSubview(label)
            truncationNotice = label
        }
        truncationNotice?.stringValue = truncated
            ? NSLocalizedString("Preview limited to 500 KiB. Use Open with FluxMarkdown above to read the complete document.", comment: "QuickLook truncation notice")
            : NSLocalizedString("Some local images could not be read. Use Open with FluxMarkdown above to view the document.", comment: "QuickLook resource notice")
        truncationNotice?.setAccessibilityLabel(truncationNotice?.stringValue)
        truncationNotice?.isHidden = !truncated && !previewHasUnreadableImages
        layoutTruncationNotice()
        if truncated || previewHasUnreadableImages { showFailure(truncated ? .previewLimit : .images) }
    }

    private func layoutTruncationNotice() {
        guard let webView else { return }
        let height: CGFloat = (previewIsTruncated || previewHasUnreadableImages) ? 52 : 0
        // Native chrome stays visible even when truncated Markdown ends in a code fence or image URI.
        webView.frame = NSRect(x: 0, y: height, width: view.bounds.width, height: max(0, view.bounds.height - height))
        truncationNotice?.frame = NSRect(x: 16, y: 8, width: max(0, view.bounds.width - 32), height: 36)
    }

    var pendingMarkdown: String?
    private var prevMarkdown: String? = nil
    var currentURL: URL?
    var searchDocumentOpener: (URL, @escaping (Bool) -> Void) -> Void = SearchLaunchClient.open
    var searchLaunchFailureHandler: (() -> Void)?
    var isWebViewLoaded = false
    var isSearchReady = false
    private var pendingSearchRequest = false
    var currentZoomLevel: Double = 1.0
    var currentViewMode: ViewMode = .preview
    var rendererBundleSchemeHandler: RendererBundleSchemeHandler?
    var localSchemeHandler: LocalSchemeHandler?

    private var securityScopedURL: URL?
    private var isSecurityScopedAccessActive: Bool = false
    
    // MARK: - Process Pool Management
    
    /// Shared process pool for all WKWebView instances to reduce memory footprint.
    /// Without this, each WKWebView creates its own Web Content process, leading to
    /// 30+ processes (60-80MB each) when previewing multiple markdown files.
    /// With a shared pool, all WebViews share 1-2 Web Content processes (~100-200MB total).
    private static let sharedProcessPool = WKProcessPool()

    // MARK: - Size Persistence Constants

    /// Minimum window size that should be persisted.
    /// Sizes below this threshold are considered "near-minimum accidental sizes"
    /// and will be rejected during both persistence and restore.
    ///
    /// Chosen threshold: 320x240
    /// - Rationale: This is a safe minimum that allows readable content display
    /// - Below this, the preview would be too small to be useful
    /// - Significantly above the previous 200x200 threshold that allowed 203x269
    public static let minimumPersistedWindowSize = CGSize(width: 320, height: 240)

    // MARK: - Size Validation Helpers (Testable)

    /// Determines whether a size is valid for persistence.
    /// - Parameter size: The window size to validate
    /// - Returns: `true` if the size meets minimum thresholds, `false` otherwise
    public static func isSizeValidForPersistence(_ size: CGSize) -> Bool {
        return size.width >= minimumPersistedWindowSize.width &&
               size.height >= minimumPersistedWindowSize.height
    }

    /// Clamps a persisted size for restore, rejecting obviously-bad sizes.
    /// - Parameter size: The persisted size from UserDefaults (may be nil)
    /// - Returns: The clamped size, or `nil` if the size should be ignored
    public static func clampPersistedSizeForRestore(_ size: CGSize?) -> CGSize? {
        guard let size = size else { return nil }
        return isSizeValidForPersistence(size) ? size : nil
    }

    /// Determines whether an invalid persisted size should be auto-cleared.
    /// - Parameter size: The persisted size from UserDefaults (may be nil)
    /// - Returns: `true` if the size exists but is invalid and should be cleared, `false` otherwise
    public static func shouldClearInvalidPersistedSize(_ size: CGSize?) -> Bool {
        guard let size = size else { return false }
        return !isSizeValidForPersistence(size)
    }

    public override var acceptsFirstResponder: Bool {
        return false
    }
    
    private var handshakeWorkItem: DispatchWorkItem?
    private let handshakeTimeoutInterval: TimeInterval = 10.0
    
    private var saveSizeWorkItem: DispatchWorkItem?
    private var resizeTrackingWorkItem: DispatchWorkItem?
    private var currentSize: CGSize?

    private var isResizeTrackingEnabled = false
    private var didUserResizeSinceOpen = false
    private var isFullScreenTransitionInProgress = false

    // Track which window we saw a live resize start event for.
    // This prevents spurious saves from programmatic resizes.
    // We only persist size if we observe both willStartLiveResize AND
    // didEndLiveResize for the SAME window.
    private var sawLiveResizeStartForWindow: ObjectIdentifier?
    
    private let renderVersion = RenderVersionCounter()
    private let usage = UsageTelemetrySession(source: "quicklook")
    private var usageReady = false
    private let fileReadVersion = RenderVersionCounter()

    // MARK: - File Monitoring
    private var fileMonitor: DispatchSourceFileSystemObject?
    private var monitoredFileDescriptor: Int32 = -1

    private var lastKnownFileSize: UInt64?
    private var lastKnownFileModificationDate: Date?

    private var pollingTimer: Timer?
    private let pollingInterval: TimeInterval = 2.0
    
    private let logger = OSLog(subsystem: "com.markdownquicklook.app", category: "MarkdownPreview")
    
    enum PreviewMode {
        case expanded   // Full QuickLook panel (spacebar press, large window)
        case compact    // Finder column-view / preview pane (small embedded view)
    }
    
    private var currentPreviewMode: PreviewMode = .expanded
    private static let compactWidthThreshold: CGFloat = 700
    private static let compactHeightThreshold: CGFloat = 500
    
    private var keyDownEventMonitor: Any?
    
    private var fileReadInFlight = false
    
    private func logScreenEnvironment(context: String) {
        os_log("📊 [%{public}@] ===== SCREEN ENVIRONMENT =====", log: logger, type: .default, context)
        
        let allScreens = NSScreen.screens
        os_log("📊 [%{public}@] Total screens: %d", log: logger, type: .default, context, allScreens.count)
        
        for (index, screen) in allScreens.enumerated() {
            let frame = screen.frame
            let visibleFrame = screen.visibleFrame
            let scale = screen.backingScaleFactor
            let isMain = (screen == NSScreen.main)
            os_log("📊 [%{public}@] Screen[%d] isMain=%{public}@ frame=(%.0f,%.0f,%.0fx%.0f) visible=(%.0f,%.0f,%.0fx%.0f) scale=%.1f",
                   log: logger, type: .default, context, index,
                   isMain ? "YES" : "NO",
                   frame.origin.x, frame.origin.y, frame.width, frame.height,
                   visibleFrame.origin.x, visibleFrame.origin.y, visibleFrame.width, visibleFrame.height,
                   scale)
        }
        
        let mouseLocation = NSEvent.mouseLocation
        var mouseScreenIndex = -1
        for (index, screen) in allScreens.enumerated() {
            if screen.frame.contains(mouseLocation) {
                mouseScreenIndex = index
                break
            }
        }
        os_log("📊 [%{public}@] Mouse location=(%.0f,%.0f) onScreen[%d]",
               log: logger, type: .default, context,
               mouseLocation.x, mouseLocation.y, mouseScreenIndex)
        
        if let window = self.view.window {
            let windowFrame = window.frame
            let windowScreen = window.screen
            var windowScreenIndex = -1
            if let ws = windowScreen {
                windowScreenIndex = allScreens.firstIndex(of: ws) ?? -1
            }
            os_log("📊 [%{public}@] Window frame=(%.0f,%.0f,%.0fx%.0f) onScreen[%d]",
                   log: logger, type: .default, context,
                   windowFrame.origin.x, windowFrame.origin.y, windowFrame.width, windowFrame.height,
                   windowScreenIndex)
        } else {
            os_log("📊 [%{public}@] Window: nil", log: logger, type: .default, context)
        }
        
        let viewFrame = self.view.frame
        let preferredSize = self.preferredContentSize
        os_log("📊 [%{public}@] View frame=(%.0f,%.0f,%.0fx%.0f) preferredContentSize=(%.0fx%.0f)",
               log: logger, type: .default, context,
               viewFrame.origin.x, viewFrame.origin.y, viewFrame.width, viewFrame.height,
               preferredSize.width, preferredSize.height)
        
        if let savedSize = AppearancePreference.shared.quickLookSize {
            os_log("📊 [%{public}@] Saved quickLookSize=(%.0fx%.0f)",
                   log: logger, type: .default, context, savedSize.width, savedSize.height)
        } else {
            os_log("📊 [%{public}@] Saved quickLookSize=nil", log: logger, type: .default, context)
        }
        
        os_log("📊 [%{public}@] ===== END SCREEN ENVIRONMENT =====", log: logger, type: .default, context)
    }
    
    public override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        os_log("🔵 init(nibName:bundle:) called", log: logger, type: .debug)
        LocalizationManager.bootstrap(initialPreference: AppearancePreference.shared.uiLanguage)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        os_log("🔵 init(coder:) called", log: logger, type: .debug)
        LocalizationManager.bootstrap(initialPreference: AppearancePreference.shared.uiLanguage)
    }
    
    private var themeButton: CircularToolbarButton!
    private var sourceButton: CircularToolbarButton!
    private var searchButton: CircularToolbarButton!
    private let shortcutViewID = UUID()
    private var helpButton: CircularToolbarButton!
    private var zoomInButton: CircularToolbarButton!
    private var zoomOutButton: CircularToolbarButton!
    private var resetZoomButton: CircularToolbarButton!
    private var reloadButton: CircularToolbarButton!
    private var versionLabel: NSTextField!
    
    public override func loadView() {
        os_log("🔵 loadView called", log: logger, type: .debug)

        let screen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)

        let width = screenFrame.width * 0.5
        let height = screenFrame.height * 0.8

        os_log("🔵 Setting preferred size to: %.0f x %.0f", log: logger, type: .debug, width, height)

        self.view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        self.view.autoresizingMask = [.width, .height]

        logScreenEnvironment(context: "loadView-BEFORE")

        if Self.shouldClearInvalidPersistedSize(AppearancePreference.shared.quickLookSize) {
            os_log("🔵 Auto-clearing invalid persisted size: %.0f x %.0f",
                   log: logger, type: .default,
                   AppearancePreference.shared.quickLookSize?.width ?? 0,
                   AppearancePreference.shared.quickLookSize?.height ?? 0)
            AppearancePreference.shared.quickLookSize = nil
        }

        if let clampedSize = Self.clampPersistedSizeForRestore(AppearancePreference.shared.quickLookSize) {
            let targetScreen = getTargetScreen()
            let constrainedSize = constrainSizeToScreen(clampedSize, screen: targetScreen)
            os_log("🔵 Restoring saved size: %.0f x %.0f (constrained to %.0f x %.0f)",
                   log: logger, type: .debug,
                   clampedSize.width, clampedSize.height,
                   constrainedSize.width, constrainedSize.height)
            self.preferredContentSize = NSSize(width: constrainedSize.width, height: constrainedSize.height)
        } else {
            os_log("🔵 Using default size (saved size was nil or too small)", log: logger, type: .debug)
            self.preferredContentSize = NSSize(width: width, height: height)
        }

            logScreenEnvironment(context: "loadView-AFTER")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        
        os_log("🔵 viewDidLoad called", log: logger, type: .default)
        
        self.view.wantsLayer = true
        applySelectedAppearanceToView()
        
        setupWindowResizeObservers()
        
        keyDownEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            os_log("🔵 Local event monitor triggered", log: self?.logger ?? .default, type: .debug)
            guard let self else { return event }
            return self.handleMonitoredKeyDownEvent(event)
        }
        os_log("🔵 Registered local key event monitor", log: logger, type: .default)
        
        os_log("🔵 configuring WebView...", log: logger, type: .default)
        
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.processPool = PreviewViewController.sharedProcessPool
        
        let preferences = WKPreferences()
        webConfiguration.preferences = preferences
        
        if #available(macOS 11.0, *) {
            let pagePreferences = WKWebpagePreferences()
            pagePreferences.allowsContentJavaScript = true
            webConfiguration.defaultWebpagePreferences = pagePreferences
        }
        
        
        let userContentController = WKUserContentController()
        errorRegistry.onRecover = { [weak self] incident in
            guard let self, let url = self.currentURL else { return }
            SearchLaunchClient.openForReading(url) { success in
                if !success { IncidentNotice.fallback(in: self.view, draft: IncidentDraft(incident)) }
            }
        }
        errorRegistry.onFailure = { [weak self] draft in
            guard let self else { return }; IncidentNotice.fallback(in: self.view, draft: draft)
        }
        userContentController.add(self, name: "logger")
        userContentController.add(self, name: "linkClicked")
        userContentController.add(self, name: "readingToolsLayout")
        userContentController.add(self, name: "errorFeedback")
        webConfiguration.userContentController = userContentController
        
        let schemeHandler = LocalSchemeHandler()
        webConfiguration.setURLSchemeHandler(schemeHandler, forURLScheme: "local-md")
        localSchemeHandler = schemeHandler
        schemeHandler.onReadFailure = { [weak self] in
            guard let self else { return }
            self.previewHasUnreadableImages = true
            self.updateTruncationNotice(self.previewIsTruncated)
        }

        if let rendererHandler = RendererBundleSchemeHandler(bundle: Bundle(for: type(of: self))) {
            webConfiguration.setURLSchemeHandler(rendererHandler, forURLScheme: RendererBundleSchemeHandler.scheme)
            rendererBundleSchemeHandler = rendererHandler
        } else {
            os_log("🔴 Renderer bundle handler could not locate index.html", log: logger, type: .error)
        }
        
        os_log("🔵 initializing InteractiveWebView instance...", log: logger, type: .default)
        webView = InteractiveWebView(frame: self.view.bounds, configuration: webConfiguration)
        webView.searchShortcutHandler = { [weak self] in self?.requestSearch() }
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        self.view.addSubview(webView)
        applySelectedAppearanceToView()
        
        os_log("🔵 WebView initialized and added to view", log: logger, type: .default)
        
        setupThemeButton()
        setupSourceButton()
        setupSearchButton()
        setupHelpButton()
        setupZoomInButton()
        setupResetZoomButton()
        setupZoomOutButton()
        setupReloadButton()
        setupVersionLabel()
        
        if rendererBundleSchemeHandler != nil {
            let url = RendererBundleSchemeHandler.rendererURL()
            webView.load(URLRequest(url: url))
            os_log("🔵 Loaded renderer via custom scheme: %{public}@", log: logger, type: .default, url.absoluteString)
        } else {
            showFailure(.rendererResources)
        }

        let doubleClickGesture = QuickLookDoubleClickGestureRecognizer(
            target: self,
            action: #selector(handleDoubleClick(_:))
        )
        doubleClickGesture.numberOfClicksRequired = 2
        doubleClickGesture.delaysPrimaryMouseButtonEvents = false
        webView.addGestureRecognizer(doubleClickGesture)
        
        // Zoom is session-only; always start at 1.0 (Bug 2 fix)
        webView.pageZoom = 1.0
        
        #if DEBUG
        setupDebugLabel()
        #endif
        
        startResizeTracking()
    }
    
    @objc func handleDoubleClick(_ gesture: NSClickGestureRecognizer) {
        os_log("🔵 Intercepted double click gesture", log: logger, type: .debug)
    }

    private func applyInitialBackgroundColor() {
        if currentThemeString() == "dark" {
            self.view.layer?.backgroundColor = NSColor(red: 0.051, green: 0.067, blue: 0.09, alpha: 1.0).cgColor
        } else {
            self.view.effectiveAppearance.performAsCurrentDrawingAppearance {
                self.view.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
            }
        }
    }

    private func applySelectedAppearanceToView() {
        let mode = AppearancePreference.shared.currentMode
        let appearance: NSAppearance?
        if mode == .system {
            let appearanceName: NSAppearance.Name = currentThemeString() == "dark" ? .darkAqua : .aqua
            appearance = NSAppearance(named: appearanceName)
        } else {
            appearance = mode.nsAppearance
        }
        self.view.appearance = appearance
        self.webView?.appearance = appearance
        applyInitialBackgroundColor()
    }
    
    
    public override func viewDidLayout() {
        super.viewDidLayout()
        layoutTruncationNotice()
        
        let size = self.view.frame.size
        os_log("📊 [viewDidLayout] size=%.0fx%.0f trackingEnabled=%{public}@",
               log: logger, type: .default,
               size.width, size.height,
               isResizeTrackingEnabled ? "YES" : "NO")
        
        updatePreviewMode()
        
        guard isResizeTrackingEnabled else {
            os_log("📊 [viewDidLayout] SKIPPED - tracking disabled", log: logger, type: .default)
            return
        }

        if let window = view.window,
           !Self.shouldTrackWindowSize(
               styleMask: window.styleMask,
               isFullScreenTransitionInProgress: isFullScreenTransitionInProgress,
               windowFrame: window.frame,
               visibleScreenFrame: window.screen?.visibleFrame
           ) {
            return
        }
        
        guard size.width > 200 && size.height > 200 else {
            os_log("📊 [viewDidLayout] SKIPPED - size too small", log: logger, type: .default)
            return
        }
        
        self.currentSize = size
    }
    
    public override func viewWillAppear() {
        super.viewWillAppear()
        logScreenEnvironment(context: "viewWillAppear")
    }
    
    public override func viewDidAppear() {
        super.viewDidAppear()
        usage.setHostVisible(true)
        usage.attach(view, document: currentURL)
        if usageReady { usage.rendered() }
        logScreenEnvironment(context: "viewDidAppear")
        
        updatePreviewMode()
        
    }
    
    private func updatePreviewMode() {
        let size = view.bounds.size
        let previousMode = currentPreviewMode
        currentPreviewMode = (size.width < Self.compactWidthThreshold || size.height < Self.compactHeightThreshold)
            ? .compact : .expanded
        
        if currentPreviewMode != previousMode {
            os_log("🔵 Preview mode changed: %{public}@ (%.0fx%.0f)", log: logger, type: .default,
                   currentPreviewMode == .expanded ? "expanded" : "compact", size.width, size.height)
            updateUIForPreviewMode()
            if isWebViewLoaded && pendingMarkdown != nil {
                renderCurrentMode()
            }
        }
    }
    
    private func updateUIForPreviewMode() {
        let isCompact = (currentPreviewMode == .compact)
        
        themeButton?.isHidden = isCompact
        sourceButton?.isHidden = isCompact
        searchButton?.isHidden = isCompact
        helpButton?.isHidden = isCompact
        zoomInButton?.isHidden = isCompact
        zoomOutButton?.isHidden = isCompact
        resetZoomButton?.isHidden = isCompact
        reloadButton?.isHidden = isCompact
        versionLabel?.isHidden = isCompact
    }
    
    public override func viewWillDisappear() {
        super.viewWillDisappear()
        usage.setHostVisible(false)
        usage.stop()
        fileReadVersion.next()
        renderVersion.next()
        webView.evaluateJavaScript("window.invalidateRender && window.invalidateRender();", completionHandler: nil)
        logScreenEnvironment(context: "viewWillDisappear")

        stopFileMonitoring()

        os_log("📊 [viewWillDisappear] trackingEnabled=%{public}@ didUserResize=%{public}@ currentSize=%{public}@",
               log: logger, type: .default,
               isResizeTrackingEnabled ? "YES" : "NO",
               didUserResizeSinceOpen ? "YES" : "NO",
               currentSize != nil ? "\(currentSize!.width)x\(currentSize!.height)" : "nil")

        let shouldPersistWindowSize = view.window.map {
            Self.shouldTrackWindowSize(
                styleMask: $0.styleMask,
                isFullScreenTransitionInProgress: isFullScreenTransitionInProgress,
                windowFrame: $0.frame,
                visibleScreenFrame: $0.screen?.visibleFrame
            )
        } ?? false

        if shouldPersistWindowSize,
           didUserResizeSinceOpen,
           let size = self.currentSize,
           Self.isSizeValidForPersistence(size) {
            os_log("📊 [viewWillDisappear] Saving final size after user resize: %.0fx%.0f", log: logger, type: .default, size.width, size.height)
            AppearancePreference.shared.quickLookSize = size
        } else {
            os_log("📊 [viewWillDisappear] Skipping save - no user resize detected or size too small", log: logger, type: .default)
        }

        if let url = currentURL {
            webView.evaluateJavaScript("window.scrollY || document.documentElement.scrollTop") { result, error in
                if let scrollY = result as? Double, scrollY >= 0 {
                    AppearancePreference.shared.setScrollPosition(for: url.path, value: scrollY)
                    os_log("📊 [viewWillDisappear] Saved scroll position: %.0f for %{public}@", 
                           log: self.logger, type: .default, scrollY, url.lastPathComponent)
                } else if let error = error {
                    os_log("🔴 [viewWillDisappear] Failed to get scroll position: %{public}@",
                           log: self.logger, type: .error, error.localizedDescription)
                }
            }
        }
        
        os_log("📊 [viewWillDisappear] Disabling tracking NOW", log: logger, type: .default)
        isResizeTrackingEnabled = false
        didUserResizeSinceOpen = false
        sawLiveResizeStartForWindow = nil
        saveSizeWorkItem?.cancel()
        saveSizeWorkItem = nil
        resizeTrackingWorkItem?.cancel()
        resizeTrackingWorkItem = nil
        
        cleanupWebView()
        stopSecurityScopedAccessIfNeeded()
    }
    
    private func cleanupWebView() {
        guard let webView = webView else { return }
        
        os_log("🔵 Cleaning up WKWebView (PID: %d, WebView: %p)", log: logger, type: .default, getpid(), webView)
        
        cancelHandshakeTimeout()
        
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "logger")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "linkClicked")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "readingToolsLayout")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "errorFeedback")
        
        for recognizer in webView.gestureRecognizers where recognizer is NSClickGestureRecognizer {
            webView.removeGestureRecognizer(recognizer)
        }
        
        webView.removeFromSuperview()
        
        self.webView = nil
        
        os_log("🔵 WKWebView cleanup complete", log: logger, type: .default)
    }
    
    deinit {
        os_log("🔵 PreviewViewController DEINIT called (PID: %d)", log: logger, type: .default, getpid())
        cleanupWebView()
        stopFileMonitoring()
        stopSecurityScopedAccessIfNeeded()
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        handshakeWorkItem?.cancel()
        saveSizeWorkItem?.cancel()
        resizeTrackingWorkItem?.cancel()
        if let keyDownEventMonitor {
            NSEvent.removeMonitor(keyDownEventMonitor)
            self.keyDownEventMonitor = nil
        }
    }

    private func stopSecurityScopedAccessIfNeeded() {
        guard isSecurityScopedAccessActive, let url = securityScopedURL else {
            securityScopedURL = nil
            isSecurityScopedAccessActive = false
            return
        }

        url.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
        isSecurityScopedAccessActive = false
        os_log("🔵 Security-scoped resource access stopped", log: logger, type: .debug)
    }
    

    
    private var themeTrailingConstraint: NSLayoutConstraint?

    private func setupThemeButton() {
        let title = NSLocalizedString("Toggle Theme", comment: "Theme toggle tooltip")
        let button = CircularToolbarButton.make(
            systemName: "circle.lefthalf.filled",
            accessibilityDescription: title,
            tintColor: NSColor.labelColor,
            target: self,
            action: #selector(toggleTheme),
            toolTip: title
        )
        
        self.view.addSubview(button)
        self.themeButton = button
        
        let trailing = button.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -10)
        themeTrailingConstraint = trailing
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 10),
            trailing,
            button.widthAnchor.constraint(equalToConstant: 30),
            button.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        updateThemeButtonState()
    }
    
    @objc private func toggleTheme() {
        let current = AppearancePreference.shared.currentMode
        let newMode: AppearanceMode
        switch current {
        case .system: newMode = .light
        case .light:  newMode = .dark
        case .dark:   newMode = .system
        }
        
        AppearancePreference.shared.currentMode = newMode
        applySelectedAppearanceToView()
        
        updateThemeButtonState()
        
        // 使用 updateTheme() 而非 renderPendingMarkdown()，避免 DOM 重建导致状态丢失（Bug 2）
        applyThemeToWebView()
    }
    
    private func updateThemeButtonState() {
        let title = NSLocalizedString("Toggle Theme", comment: "Theme toggle tooltip")
        let mode = AppearancePreference.shared.currentMode
        let iconName: String
        let iconColor: NSColor
        switch mode {
        case .system:
            iconName = "circle.lefthalf.filled"
            iconColor = NSColor.labelColor
        case .light:
            iconName = "sun.max.fill"
            iconColor = NSColor.systemYellow
        case .dark:
            iconName = "moon.fill"
            iconColor = NSColor.labelColor
        }
        themeButton.configure(
            systemName: iconName,
            accessibilityDescription: title,
            tintColor: iconColor,
            toolTip: title
        )
    }
    
    private func setupSourceButton() {
        let title = NSLocalizedString("Toggle Source View", comment: "Source view toggle tooltip")
        let button = CircularToolbarButton.make(
            systemName: "doc.text.fill",
            accessibilityDescription: title,
            tintColor: NSColor.labelColor,
            target: self,
            action: #selector(toggleViewMode),
            toolTip: title
        )
        
        self.view.addSubview(button)
        self.sourceButton = button
        
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 10),
            button.trailingAnchor.constraint(equalTo: themeButton.leadingAnchor, constant: -8),
            button.widthAnchor.constraint(equalToConstant: 30),
            button.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        updateSourceButtonState()
    }
    
    @objc private func toggleViewMode() {
        webView.evaluateJavaScript("window.scrollY || document.documentElement.scrollTop") { [weak self] result, error in
            guard let self = self else { return }
            
            let scrollY = (result as? Double) ?? 0.0
            
            let prevMode = self.currentViewMode
            self.currentViewMode = (self.currentViewMode == .preview) ? .source : .preview
            os_log("🔵 toggleViewMode: %{public}@ → %{public}@ isWebViewLoaded=%{public}@",
                   log: self.logger, type: .default,
                   prevMode == .preview ? "preview" : "source",
                   self.currentViewMode == .preview ? "preview" : "source",
                   self.isWebViewLoaded ? "true" : "false")
            self.updateSourceButtonState()
            
            if self.isWebViewLoaded {
                self.renderCurrentMode()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let scrollJS = "window.scrollTo({ top: \(scrollY), behavior: 'auto' });"
                    self.webView.evaluateJavaScript(scrollJS) { _, error in
                        if error == nil {
                            os_log("🔵 Restored scroll position: %.0f after mode switch", 
                                   log: self.logger, type: .default, scrollY)
                        }
                    }
                }
            } else {
                os_log("🔴 toggleViewMode: isWebViewLoaded=false, renderCurrentMode skipped! Mode toggled to %{public}@ but content NOT updated.",
                       log: self.logger, type: .error,
                       self.currentViewMode == .preview ? "preview" : "source")
            }
        }
    }
    
    private func updateSourceButtonState() {
        let title = NSLocalizedString("Toggle Source View", comment: "Source view toggle tooltip")
        let iconName = (currentViewMode == .source) ? "eye.fill" : "doc.text.fill"
        let iconColor = (currentViewMode == .source) ? NSColor.systemBlue : NSColor.darkGray
        
        sourceButton.configure(
            systemName: iconName,
            accessibilityDescription: title,
            tintColor: iconColor,
            toolTip: title
        )
    }

    func makeSearchButton() -> CircularToolbarButton {
        let title = NSLocalizedString("Search in FluxMarkdown", comment: "Quick Look search handoff button")
        let button = CircularToolbarButton.make(
            systemName: "magnifyingglass",
            accessibilityDescription: title,
            tintColor: NSColor.labelColor,
            target: self,
            action: #selector(showDocumentSearch),
            toolTip: title
        )
        button.keyEquivalent = "f"
        button.keyEquivalentModifierMask = .command
        button.keyEquivalentMatcher = QuickLookFindShortcut.matches
        button.setAccessibilityIdentifier(QuickLookShortcutIdentity.identifier(for: shortcutViewID))
        return button
    }

    private func setupSearchButton() {
        let button = makeSearchButton()
        view.addSubview(button)
        searchButton = button
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            button.trailingAnchor.constraint(equalTo: sourceButton.leadingAnchor, constant: -8),
            button.widthAnchor.constraint(equalToConstant: 30),
            button.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    @objc private func showDocumentSearch() {
        requestSearch()
    }

    private func setupHelpButton() {
        let title = NSLocalizedString("Show Help", comment: "Show help tooltip")
        let button = CircularToolbarButton.make(
            systemName: "questionmark.circle",
            accessibilityDescription: title,
            tintColor: NSColor.labelColor,
            target: self,
            action: #selector(toggleHelp),
            toolTip: title
        )

        self.view.addSubview(button)
        self.helpButton = button

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 10),
            button.trailingAnchor.constraint(equalTo: searchButton.leadingAnchor, constant: -8),
            button.widthAnchor.constraint(equalToConstant: 30),
            button.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    @objc private func toggleHelp() {
        webView.evaluateJavaScript("window.toggleHelp();", completionHandler: nil)
    }

    private func setupZoomInButton() {
        let title = NSLocalizedString("Zoom In", comment: "Zoom in tooltip")
        let button = CircularToolbarButton.make(
            systemName: "textformat.size.larger",
            accessibilityDescription: title,
            tintColor: NSColor.labelColor,
            target: self,
            action: #selector(zoomIn),
            toolTip: title
        )

        self.view.addSubview(button)
        self.zoomInButton = button

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 10),
            button.trailingAnchor.constraint(equalTo: helpButton.leadingAnchor, constant: -8),
            button.widthAnchor.constraint(equalToConstant: 30),
            button.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    private func setupZoomOutButton() {
        let title = NSLocalizedString("Zoom Out", comment: "Zoom out tooltip")
        let button = CircularToolbarButton.make(
            systemName: "textformat.size.smaller",
            accessibilityDescription: title,
            tintColor: NSColor.labelColor,
            target: self,
            action: #selector(zoomOut),
            toolTip: title
        )

        self.view.addSubview(button)
        self.zoomOutButton = button

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 10),
            button.trailingAnchor.constraint(equalTo: resetZoomButton.leadingAnchor, constant: -8),
            button.widthAnchor.constraint(equalToConstant: 30),
            button.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    private func setupResetZoomButton() {
        let title = NSLocalizedString("Reset Zoom (⌘0)", comment: "Reset zoom tooltip")
        let button = CircularToolbarButton.make(
            systemName: "arrow.uturn.backward",
            accessibilityDescription: title,
            tintColor: NSColor.labelColor,
            target: self,
            action: #selector(resetZoom),
            toolTip: title
        )

        self.view.addSubview(button)
        self.resetZoomButton = button

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 10),
            button.trailingAnchor.constraint(equalTo: zoomInButton.leadingAnchor, constant: -8),
            button.widthAnchor.constraint(equalToConstant: 30),
            button.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    private func setupReloadButton() {
        let title = NSLocalizedString("Reload File (⌘R)", comment: "Reload file tooltip")
        let button = CircularToolbarButton.make(
            systemName: "arrow.clockwise",
            accessibilityDescription: title,
            tintColor: NSColor.labelColor,
            target: self,
            action: #selector(reloadFileManually),
            toolTip: title
        )

        self.view.addSubview(button)
        self.reloadButton = button

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 10),
            button.trailingAnchor.constraint(equalTo: zoomOutButton.leadingAnchor, constant: -8),
            button.widthAnchor.constraint(equalToConstant: 30),
            button.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    private func setupVersionLabel() {
        let version = DisplayVersion.text(in: Bundle(for: type(of: self))) ?? ""
        guard !version.isEmpty else { return }

        let label = NSTextField(labelWithString: "v\(version)")
        label.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        label.textColor = NSColor.secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        self.view.addSubview(label)
        self.versionLabel = label

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: zoomOutButton.bottomAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -72)
        ])
    }

    static func resolvedTheme(
        mode: AppearanceMode,
        systemInterfaceStyle: String?
    ) -> String {
        switch mode {
        case .light:
            return "light"
        case .dark:
            return "dark"
        case .system:
            return systemInterfaceStyle?.caseInsensitiveCompare("dark") == .orderedSame
                ? "dark"
                : "light"
        }
    }

    /// Resolve System from the global macOS preference, not Quick Look's host window.
    private func currentThemeString() -> String {
        Self.resolvedTheme(
            mode: AppearancePreference.shared.currentMode,
            systemInterfaceStyle: UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
        )
    }

    /// 调用 JS window.updateTheme()，不重新渲染文档（避免 DOM 重建）
    private func applyThemeToWebView() {
        guard isWebViewLoaded else { return }
        let theme = currentThemeString()
        let js = """
        if (typeof window.updateTheme === 'function') {
            window.updateTheme('\(theme)');
        }
        """
        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                os_log("🔴 updateTheme JS error: %{public}@", log: self.logger, type: .error, error.localizedDescription)
            }
        }
    }

    private func renderCurrentMode() {
        if currentViewMode == .preview {
            renderPendingMarkdown()
        } else {
            renderSourceView()
        }
    }
    
    private func renderSourceView() {
        let usageRenderVersion = renderVersion.next()
        usage.rendering()
        usageReady = false
        guard let content = pendingMarkdown else {
            os_log("🟡 renderSourceView called but pendingMarkdown is nil", log: logger, type: .debug)
            return
        }
        
        guard isWebViewLoaded else {
            os_log("🟡 renderSourceView called but WebView not ready", log: logger, type: .debug)
            return
        }

        webView.evaluateJavaScript("window.clearDiffMarks && window.clearDiffMarks();", completionHandler: nil)
        os_log("🔵 renderSourceView called with content length: %d", log: logger, type: .debug, content.count)
        
        guard let contentData = try? JSONSerialization.data(withJSONObject: [content], options: []),
              let contentJsonArray = String(data: contentData, encoding: .utf8) else {
            os_log("🔴 Failed to encode content to JSON", log: self.logger, type: .error)
            return
        }
        
        let safeContentArg = String(contentJsonArray.dropFirst().dropLast())
        
        let theme = currentThemeString()
        
        let capturedPrevForSource = self.prevMarkdown
        self.prevMarkdown = nil

        let feedbackGeneration = errorRegistry.beginDocument()
        webView.evaluateJavaScript("window.setFeedbackGeneration && window.setFeedbackGeneration('\(feedbackGeneration)');", completionHandler: nil)
        var callJs: String
        if let prev = capturedPrevForSource, !prev.isEmpty,
           let prevData = try? JSONSerialization.data(withJSONObject: [prev]),
           let prevJson = String(data: prevData, encoding: .utf8) {
            let safePrevArg = String(prevJson.dropFirst().dropLast())
            callJs = """
            try {
                window.renderSource(\(safeContentArg), "\(theme)", \(safePrevArg));
                "success"
            } catch(e) {
                "error: " + e.toString()
            }
            """
        } else {
            callJs = """
            try {
                window.renderSource(\(safeContentArg), "\(theme)");
                "success"
            } catch(e) {
                "error: " + e.toString()
            }
            """
        }
        
        self.webView.evaluateJavaScript(callJs) { (innerResult, innerError) in
            guard self.renderVersion.isCurrent(usageRenderVersion) else { return }
            if let innerError = innerError {
                os_log("🔴 JS Execution Error (renderSource): %{public}@", log: self.logger, type: .error, innerError.localizedDescription)
                self.showFailure(.source, error: innerError)
            } else if let res = innerResult as? String {
                if res == "success" { self.usageReady = true; self.usage.rendered() }
                os_log("🔵 JS Execution Result (renderSource): %{public}@", log: self.logger, type: .debug, res)
                self.isSearchReady = true
                self.completePendingSearchRequest()
            }
            
        }
    }
    
    @objc private func zoomIn() {
        webView.pageZoom = min(3.0, webView.pageZoom + 0.1)
        AppearancePreference.shared.zoomLevel = webView.pageZoom
        os_log("🔵 pageZoom in: %.2f", log: logger, type: .debug, webView.pageZoom)
    }
    
    @objc private func zoomOut() {
        webView.pageZoom = max(0.5, webView.pageZoom - 0.1)
        AppearancePreference.shared.zoomLevel = webView.pageZoom
        os_log("🔵 pageZoom out: %.2f", log: logger, type: .debug, webView.pageZoom)
    }
    
    @objc private func resetZoom() {
        webView.pageZoom = 1.0
        AppearancePreference.shared.zoomLevel = 1.0
        showToolbarFeedbackToast(NSLocalizedString("Zoom reset", comment: "Reset zoom toast"))
        os_log("🔵 pageZoom reset", log: logger, type: .debug)
    }

    @objc private func reloadFileManually() {
        os_log("🔄 Manual reload triggered by button/shortcut", log: logger, type: .default)
        reloadFromDisk(force: true) { [weak self] success in
            self?.showToolbarFeedbackToast(success
                ? NSLocalizedString("Document reloaded", comment: "Reload success toast")
                : NSLocalizedString("Reload failed", comment: "Reload failure toast"))
        }
    }
    
    /// The process can host multiple remote views; do not steal another window's keys.
    func handleMonitoredKeyDownEvent(_ event: NSEvent) -> NSEvent? {
        guard let window = view.window, event.windowNumber == window.windowNumber else { return event }
        return handleKeyDownEvent(event)
    }

    private func requestSearch() {
        os_log("QuickLook find requested (renderer=%d, search=%d)", log: logger, type: .default,
               isWebViewLoaded, isSearchReady)
        pendingSearchRequest = true
        completePendingSearchRequest()
    }

    func completePendingSearchRequest() {
        let placement: SearchWindowPlacement?
        if let window = view.window, let screen = window.screen,
           let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            placement = SearchWindowPlacement(frame: window.frame, displayID: id.uint32Value)
        } else { placement = nil }
        guard pendingSearchRequest, let currentURL,
              let url = DocumentOpenRequest.searchURL(for: currentURL, placement: placement) else { return }
        pendingSearchRequest = false
        searchDocumentOpener(url) { [weak self] succeeded in
            guard let self, !succeeded else { return }
            guard let context = self.extensionContext else {
                self.showSearchLaunchFailure()
                return
            }
            context.open(url) { [weak self] accepted in
                DispatchQueue.main.async {
                    if !accepted { self?.showSearchLaunchFailure() }
                }
            }
        }
    }

    private func showSearchLaunchFailure() {
        os_log("Host also refused document search launch", log: logger, type: .error)
        if let searchLaunchFailureHandler { searchLaunchFailureHandler(); return }
        showFailure(.search)
        showToast(
            message: NSLocalizedString("Search in FluxMarkdown", comment: "Search guidance title"),
            hint: NSLocalizedString("Double-click the file, then press ⌘F to search.", comment: "Search guidance after host refuses app launch"),
            iconName: "info.circle.fill", duration: 8
        )
    }

    private func handleKeyDownEvent(_ event: NSEvent) -> NSEvent? {
        if QuickLookFindShortcut.matches(event) {
            requestSearch()
            return nil
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        if flags == .command {
            switch event.charactersIgnoringModifiers {
            case "+", "=":
                os_log("🔵 Zoom In triggered", log: logger, type: .default)
                zoomIn()
                return nil
            case "-", "_":
                os_log("🔵 Zoom Out triggered", log: logger, type: .default)
                zoomOut()
                return nil
            case "0":
                os_log("🔵 Reset Zoom triggered", log: logger, type: .default)
                resetZoom()
                return nil
            case "r", "R":
                os_log("🔵 Reload File triggered", log: logger, type: .default)
                reloadFileManually()
                return nil
            default:
                break
            }
        } else if flags == [.command, .shift] {
            switch event.charactersIgnoringModifiers {
            case "M", "m":
                os_log("🔵 Toggle View Mode triggered", log: logger, type: .default)
                toggleViewMode()
                return nil
            default:
                break
            }
        }
        
        return event
    }
    
    public override func performTextFinderAction(_ sender: Any?) {
        if QuickLookFindShortcut.isShowFindAction(sender) { requestSearch(); return }
        super.performTextFinderAction(sender)
    }

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleKeyDownEvent(event) == nil {
            os_log("🔵 performKeyEquivalent handled the event", log: logger, type: .default)
            return true
        }
        
        return super.performKeyEquivalent(with: event)
    }
    
    public override func keyDown(with event: NSEvent) {
        if handleKeyDownEvent(event) == nil {
            return
        }
        super.keyDown(with: event)
    }
    
    #if DEBUG
    private func setupDebugLabel() {
        let debugInfo = Bundle(for: type(of: self)).infoDictionary
        let version = DisplayVersion.text(from: debugInfo) ?? "Unknown"
        let build = debugInfo?["CFBundleVersion"] as? String ?? "Unknown"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        let now = dateFormatter.string(from: Date())
        
        let debugLabel = NSTextField(labelWithString: "v\(version)(\(build)) \(now)")
        debugLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        debugLabel.textColor = NSColor.white
        debugLabel.drawsBackground = true
        debugLabel.backgroundColor = NSColor.red.withAlphaComponent(0.6)
        debugLabel.translatesAutoresizingMaskIntoConstraints = false
        
        self.view.addSubview(debugLabel)
        
        NSLayoutConstraint.activate([
            debugLabel.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 5),
            debugLabel.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 5)
        ])
        
        self.view.addSubview(debugLabel, positioned: .above, relativeTo: webView)
    }
    #endif

    public func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        _ = errorRegistry.beginDocument()
        for notice in view.subviews.compactMap({ $0 as? IncidentNotice }) { notice.removeFromSuperview() }
        os_log("🔵 preparePreviewOfFile called for: %{public}@", log: logger, type: .default, url.path)
        renderVersion.next()
        let readVersion = fileReadVersion.next()
        fileReadInFlight = false
        pendingMarkdown = nil
        previewHasUnreadableImages = false
        updateTruncationNotice(false)
        self.currentURL = url
        usageReady = false
        usage.attach(view, document: url)
        
        stopSecurityScopedAccessIfNeeded()
        securityScopedURL = url
        isSecurityScopedAccessActive = url.startAccessingSecurityScopedResource()
        completePendingSearchRequest()
        os_log("Security-scope activation: %{public}@ (actual file read determines access)", log: logger, type: .debug, isSecurityScopedAccessActive ? "activated" : "not-activated")
        
        logScreenEnvironment(context: "preparePreviewOfFile-ENTRY")
        
        DispatchQueue.main.async {
            self.logScreenEnvironment(context: "preparePreviewOfFile-ASYNC-START")

            let savedZoom = AppearancePreference.shared.zoomLevel
            self.webView.pageZoom = savedZoom
            os_log("🔵 Restored pageZoom to %.2f for new file preview", log: self.logger, type: .debug, savedZoom)

            // Reset tracking to prevent capturing layout thrashing during display switching.
            // This is necessary because when QuickLook switches displays or reuses the view controller,
            // transient layout passes with incorrect sizes may occur.
            self.startResizeTracking()

            if Self.shouldClearInvalidPersistedSize(AppearancePreference.shared.quickLookSize) {
                os_log("🔵 Auto-clearing invalid persisted size: %.0f x %.0f",
                       log: self.logger, type: .default,
                       AppearancePreference.shared.quickLookSize?.width ?? 0,
                       AppearancePreference.shared.quickLookSize?.height ?? 0)
                AppearancePreference.shared.quickLookSize = nil
            }

            if let clampedSize = Self.clampPersistedSizeForRestore(AppearancePreference.shared.quickLookSize) {
                let targetScreen = self.getTargetScreen()
                let constrainedSize = self.constrainSizeToScreen(clampedSize, screen: targetScreen)
                os_log("🔵 Re-applying saved size: %.0f x %.0f (constrained to %.0f x %.0f)",
                       log: self.logger, type: .debug,
                       clampedSize.width, clampedSize.height,
                       constrainedSize.width, constrainedSize.height)
                self.preferredContentSize = NSSize(width: constrainedSize.width, height: constrainedSize.height)
                self.logScreenEnvironment(context: "preparePreviewOfFile-AFTER-SET-SIZE")
            }
            
            AppearancePreference.shared.apply(to: self.view)
            self.updateThemeButtonState()
            
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result { try PreviewFileReader.read(url) }
                DispatchQueue.main.async {
                    guard self.fileReadVersion.isCurrent(readVersion), self.currentURL == url else {
                        handler(CocoaError(.userCancelled))
                        return
                    }
                    switch result {
                    case .success(let snapshot):
                        self.pendingMarkdown = snapshot.content
                        self.previewHasUnreadableImages = false
                        self.updateTruncationNotice(snapshot.isTruncated)
                        self.lastKnownFileSize = snapshot.size
                        self.lastKnownFileModificationDate = snapshot.modificationDate
                        if self.isWebViewLoaded { self.renderCurrentMode() }
                        self.startFileMonitoring()
                        handler(nil)
                    case .failure(let error):
                        os_log("Failed to read preview: %{public}@", log: self.logger, type: .error, error.localizedDescription)
                        self.showFailure(.fileRead, error: error)
                        handler(nil)
                    }
                }
            }
        }
    }
    
    private func renderPendingMarkdown() {
        guard let content = pendingMarkdown else {
            os_log("🟡 renderPendingMarkdown called but pendingMarkdown is nil", log: logger, type: .debug)
            return
        }
        
        guard isWebViewLoaded else {
            os_log("🟡 renderPendingMarkdown called but WebView not ready (handshake pending), queuing...", log: logger, type: .debug)
            return
        }

        webView.evaluateJavaScript("window.clearDiffMarks && window.clearDiffMarks();", completionHandler: nil)
        os_log("🔵 renderPendingMarkdown called with content length: %d", log: logger, type: .debug, content.count)
        
        guard let contentData = try? JSONSerialization.data(withJSONObject: [content], options: []),
              let contentJsonArray = String(data: contentData, encoding: .utf8) else {
            os_log("🔴 Failed to encode content to JSON", log: self.logger, type: .error)
            return
        }
        
        let safeContentArg = String(contentJsonArray.dropFirst().dropLast())
        
        let theme = currentThemeString()
        
        let capturedURL = self.currentURL
        
        if let url = capturedURL {
            localSchemeHandler?.baseDirectory = url.deletingLastPathComponent()
            localSchemeHandler?.allowedFileURLs = MarkdownImageDataCollector.referencedLocalImageURLs(
                from: url,
                content: content
            )
        } else {
            localSchemeHandler?.allowedFileURLs = []
        }

        let capturedUILanguage = AppearancePreference.shared.uiLanguage
        let capturedCollapseBlockquotes = AppearancePreference.shared.collapseBlockquotesByDefault
        let capturedContentsSide = AppearancePreference.shared.contentsSide.rawValue
        let capturedShowLineNumbers = AppearancePreference.shared.showLineNumbers
        let capturedPrevMarkdown = self.prevMarkdown
        let capturedPreviewMode = self.currentPreviewMode
        let capturedFontSize: Double = (capturedPreviewMode == .compact)
            ? AppearancePreference.shared.finderPaneFontSize
            : AppearancePreference.shared.baseFontSize
        self.prevMarkdown = nil
        usage.rendering()
        usageReady = false
        let capturedRenderVersion = renderVersion.next()
        webView.evaluateJavaScript("window.invalidateRender && window.invalidateRender();", completionHandler: nil)

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            let contextValue = capturedPreviewMode == .compact ? "finder" : "quicklook"
            var options: [String: Any] = ["theme": theme, "context": contextValue, "uiLanguage": capturedUILanguage, "collapseBlockquotes": capturedCollapseBlockquotes, "showLineNumbers": capturedShowLineNumbers, "contentsSide": capturedContentsSide, "fontSize": capturedFontSize, "renderVersion": capturedRenderVersion]
            if let url = capturedURL {
                options["filename"] = url.lastPathComponent
                options["baseUrl"] = url.deletingLastPathComponent().path
                let imageData = MarkdownImageDataCollector.collectImageData(from: url, content: content)
                if !imageData.isEmpty {
                    options["imageData"] = imageData
                }
            }
            if let prev = capturedPrevMarkdown, !prev.isEmpty {
                options["prevContent"] = prev
            }
            
            guard let optionsData = try? JSONSerialization.data(withJSONObject: options, options: []),
                  let optionsJson = String(data: optionsData, encoding: .utf8) else {
                await MainActor.run {
                    os_log("🔴 Failed to encode options to JSON", log: self.logger, type: .error)
                    self.showFailure(.renderer)
                }
                return
            }
            
            let callJs = "return window.renderMarkdown(\(safeContentArg), \(optionsJson));"
            
            await MainActor.run {
                guard self.renderVersion.isCurrent(capturedRenderVersion), self.currentURL == capturedURL else { return }
                let feedbackGeneration = self.errorRegistry.beginDocument()
                ErrorFeedback.capture(.renderer, phase: .started, scope: self.errorRegistry.scope)
                self.webView.evaluateJavaScript("window.setFeedbackGeneration && window.setFeedbackGeneration('\(feedbackGeneration)');", completionHandler: nil)
                self.webView.callAsyncJavaScript(
                    callJs,
                    arguments: [:],
                    in: nil,
                    in: WKContentWorld.page
                ) { result in
                    guard self.renderVersion.isCurrent(capturedRenderVersion), self.currentURL == capturedURL else { return }
                    switch result {
                    case .failure(let error):
                        os_log("🔴 JS Execution Error (renderMarkdown): %{public}@", log: self.logger, type: .error, error.localizedDescription)
                self.showFailure(.renderer, error: error)
                    case .success(let value):
                        self.usageReady = true
                        self.usage.rendered()
                        os_log("🔵 renderMarkdown completed successfully, result: %{public}@", log: self.logger, type: .debug, String(describing: value))
                        if let url = self.currentURL, let token = QuickLookProbeEvidence.token(for: url) {
                            let version = Bundle(for: type(of: self)).object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
                            os_log("%{public}@", log: self.logger, type: .default,
                                   QuickLookProbeEvidence.marker(token: token, version: version, stage: "rendered"))
                        }
                        self.isSearchReady = true
                        self.completePendingSearchRequest()
                    }
                    
                    if let url = self.currentURL,
                       let savedScrollY = AppearancePreference.shared.getScrollPosition(for: url.path),
                       savedScrollY > 0 {
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            guard self.renderVersion.isCurrent(capturedRenderVersion), self.currentURL == capturedURL else { return }
                            let scrollJS = "window.scrollTo({ top: \(savedScrollY), behavior: 'auto' });"
                            self.webView.evaluateJavaScript(scrollJS) { _, error in
                                if error == nil {
                                    os_log("📊 [renderPendingMarkdown] Restored scroll position: %.0f for %{public}@",
                                           log: self.logger, type: .default, savedScrollY, url.lastPathComponent)
                                } else {
                                    os_log("🔴 [renderPendingMarkdown] Failed to restore scroll position: %{public}@",
                                           log: self.logger, type: .error, error!.localizedDescription)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        os_log("🔵 WebView didFinish navigation (waiting for handshake)", log: logger, type: .debug)
        // Always reset isWebViewLoaded on navigation finish.
        // This handles browser-initiated reloads (e.g., right-click > Reload)
        // where didStartProvisionalNavigation may not be called.
        isWebViewLoaded = false
        isSearchReady = false
        startHandshakeTimeout()
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        os_log("🔵 WebView didStartProvisionalNavigation (resetting state)", log: logger, type: .debug)
        isWebViewLoaded = false
        isSearchReady = false
        cancelHandshakeTimeout()
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        os_log("🔴 WebView didFail navigation: %{public}@", log: logger, type: .error, error.localizedDescription)
                showFailure(.renderer, error: error)
        cancelHandshakeTimeout()
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        os_log("🔴 WebView didFailProvisionalNavigation: %{public}@", log: logger, type: .error, error.localizedDescription)
                showFailure(.renderer, error: error)
        cancelHandshakeTimeout()
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard navigationAction.navigationType == .linkActivated,
              let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        os_log("🔵 Link clicked: %{public}@", log: logger, type: .default, url.absoluteString)
        os_log("🔵   - scheme: %{public}@, isFileURL: %{public}@, path: %{public}@", 
               log: logger, type: .default, 
               url.scheme ?? "nil", 
               url.isFileURL ? "YES" : "NO", 
               url.path)
        
        if let fragment = url.fragment, !fragment.isEmpty {
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            urlComponents?.fragment = nil
            let targetPath = urlComponents?.url?.absoluteString ?? ""
            
            var currentComponents = webView.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
            currentComponents?.fragment = nil
            let currentPath = currentComponents?.url?.absoluteString ?? ""
            
            let isSameDocument = targetPath.isEmpty || currentPath == targetPath || url.scheme == nil
            
            if isSameDocument {
                os_log("🔵 Same-document anchor link, letting JavaScript handle it", log: logger, type: .default)
                decisionHandler(.cancel)
                return
            }
        }
        
        if url.scheme == "http" || url.scheme == "https" {
            os_log("🔵 Opening external URL in browser: %{public}@", log: logger, type: .default, url.absoluteString)
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        
        if url.isFileURL {
            os_log("🔵 Opening local file with default app: %{public}@ (extension: %{public}@)", 
                   log: logger, type: .default, url.path, url.pathExtension)
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        
        os_log("🔵 Allowing navigation (unhandled scheme: %{public}@)", log: logger, type: .default, url.scheme ?? "nil")
        decisionHandler(.allow)
    }

    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        os_log("🔴 WebContent process terminated! Attempting reload...", log: logger, type: .error)
        cancelHandshakeTimeout()
        showFailure(.renderer)
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard RendererBridgePolicy.accepts(message) else { return }
        if message.name == "errorFeedback" { errorRegistry.handle(message.body); return }
        if message.name == "logger", let body = message.body as? String {
            os_log("🟢 JS Log: %{public}@", log: logger, type: .debug, body)
            
            if body == "rendererReady" {
                os_log("🟢 Renderer Handshake Received!", log: logger, type: .default)
                cancelHandshakeTimeout()
                
                isWebViewLoaded = true
                renderCurrentMode()
            }
        } else if message.name == "readingToolsLayout" {
            themeTrailingConstraint?.constant = -ReadingToolbarLayout.trailingInset(body: message.body, zoom: message.webView?.pageZoom ?? 1)
            view.needsLayout = true
        } else if message.name == "linkClicked", let href = message.body as? String {
            os_log("🔵 Link clicked from JS: %{public}@", log: logger, type: .default, href)
            handleLinkClick(href: href)
        }
    }
    
    private func handleLinkClick(href: String) {
        if href == GitHubStar.repository.absoluteString {
            SearchLaunchClient.openGitHubRepository { [weak self] success in
                guard let self else { return }
                os_log("GitHub repository browser handoff: %{public}@", log: self.logger,
                       type: .default, success ? "SUCCESS" : "FAILED")
                if !success {
                    self.showFailure(.browser)
                    self.showToast(message: NSLocalizedString("Could not open GitHub", comment: "GitHub support browser error"),
                                   hint: GitHubStar.repository.absoluteString, iconName: "info.circle.fill")
                }
            }
            return
        }
        if href.starts(with: "http://") || href.starts(with: "https://") {
            if let url = URL(string: href) {
                os_log("🔵 Opening external URL: %{public}@", log: logger, type: .default, href)
                let success = NSWorkspace.shared.open(url)
                os_log("🔵 NSWorkspace.open result: %{public}@", log: logger, type: .default, success ? "SUCCESS" : "FAILED")
                
                if !success {
                    os_log("🔴 Failed to open URL in QuickLook Extension sandbox", log: logger, type: .error)
                    showLinkUnsupportedToast()
                }
            }
            return
        }
        
        os_log("🔵 Local file link clicked: %{public}@", log: logger, type: .default, href)
        showLinkUnsupportedToast()
    }
    
    private var toastView: NSView?
    private var toastDismissWorkItem: DispatchWorkItem?
    
    private func showLinkUnsupportedToast() {
        showFailure(.link)
        showToast(
            message: NSLocalizedString("QuickLook preview does not support link navigation", comment: "Toast message when link clicked in QuickLook"),
            hint: NSLocalizedString("Double-click .md file to open in main app for full functionality", comment: "Toast hint message"),
            iconName: "info.circle.fill"
        )
    }

    private func showToolbarFeedbackToast(_ message: String) {
        showToast(message: message, hint: nil, iconName: "checkmark.circle.fill")
    }

    private func showToast(message: String, hint: String?, iconName: String, duration: TimeInterval = 3) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.toastDismissWorkItem?.cancel()
            self.toastDismissWorkItem = nil
            self.toastView?.removeFromSuperview()
            self.toastView = nil
            
            let toastContainer = NSView()
            toastContainer.wantsLayer = true
            toastContainer.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.95).cgColor
            toastContainer.layer?.cornerRadius = 8
            toastContainer.translatesAutoresizingMaskIntoConstraints = false
            
            let iconImageView = NSImageView()
            iconImageView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
            iconImageView.contentTintColor = .white
            iconImageView.translatesAutoresizingMaskIntoConstraints = false
            
            let messageLabel = NSTextField(labelWithString: message)
            messageLabel.textColor = .white
            messageLabel.font = .systemFont(ofSize: 13, weight: .medium)
            messageLabel.translatesAutoresizingMaskIntoConstraints = false
            
            let hintLabel = hint.map { text -> NSTextField in
                let label = NSTextField(wrappingLabelWithString: text)
                label.textColor = NSColor.white.withAlphaComponent(0.9)
                label.font = .systemFont(ofSize: 11)
                label.translatesAutoresizingMaskIntoConstraints = false
                return label
            }
            
            toastContainer.addSubview(iconImageView)
            toastContainer.addSubview(messageLabel)
            if let hintLabel {
                toastContainer.addSubview(hintLabel)
            }
            self.view.addSubview(toastContainer)

            var constraints = [
                toastContainer.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 16),
                toastContainer.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                toastContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 500),
                toastContainer.widthAnchor.constraint(lessThanOrEqualTo: self.view.widthAnchor, constant: -32),
                
                iconImageView.leadingAnchor.constraint(equalTo: toastContainer.leadingAnchor, constant: 12),
                iconImageView.centerYAnchor.constraint(equalTo: toastContainer.centerYAnchor),
                iconImageView.widthAnchor.constraint(equalToConstant: 20),
                iconImageView.heightAnchor.constraint(equalToConstant: 20),
                
                messageLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
                messageLabel.trailingAnchor.constraint(equalTo: toastContainer.trailingAnchor, constant: -12),
                messageLabel.topAnchor.constraint(equalTo: toastContainer.topAnchor, constant: 10)
            ]

            if let hintLabel {
                constraints += [
                    hintLabel.leadingAnchor.constraint(equalTo: messageLabel.leadingAnchor),
                    hintLabel.trailingAnchor.constraint(equalTo: messageLabel.trailingAnchor),
                    hintLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 2),
                    hintLabel.bottomAnchor.constraint(equalTo: toastContainer.bottomAnchor, constant: -10)
                ]
            } else {
                constraints.append(messageLabel.bottomAnchor.constraint(equalTo: toastContainer.bottomAnchor, constant: -10))
            }

            NSLayoutConstraint.activate(constraints)
            
            self.toastView = toastContainer
            
            toastContainer.alphaValue = 0
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                toastContainer.animator().alphaValue = 1
            })
            
            let dismissWorkItem = DispatchWorkItem { [weak self] in
                guard let self = self, let toast = self.toastView else { return }
                
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.3
                    toast.animator().alphaValue = 0
                }, completionHandler: {
                    toast.removeFromSuperview()
                    self.toastView = nil
                    self.toastDismissWorkItem = nil
                })
            }
            self.toastDismissWorkItem = dismissWorkItem
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: dismissWorkItem)
        }
    }
    
    private func startHandshakeTimeout() {
        cancelHandshakeTimeout()
        
        if isWebViewLoaded { return }
        
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if !self.isWebViewLoaded {
                os_log("🔴 Renderer Handshake Timeout (%{public}.1fs)! Showing non-destructive error.", log: self.logger, type: .error, self.handshakeTimeoutInterval)
                
                self.showFailure(.renderer)
            }
        }
        
        self.handshakeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + handshakeTimeoutInterval, execute: item)
        os_log("🔵 Started handshake timer (%.1fs)", log: logger, type: .debug, handshakeTimeoutInterval)
    }
    
    private func cancelHandshakeTimeout() {
        if let item = handshakeWorkItem {
            item.cancel()
            handshakeWorkItem = nil
            os_log("🔵 Cancelled handshake timer", log: logger, type: .debug)
        }
    }
    
    private func startResizeTracking() {
        resizeTrackingWorkItem?.cancel()
        isResizeTrackingEnabled = false
        didUserResizeSinceOpen = false
        sawLiveResizeStartForWindow = nil

        let item = DispatchWorkItem { [weak self] in
            self?.isResizeTrackingEnabled = true
            os_log("🔵 Resize tracking enabled", log: self?.logger ?? .default, type: .debug)
        }

        resizeTrackingWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: item)
    }
    
    private func setupWindowResizeObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillStartLiveResize),
            name: NSWindow.willStartLiveResizeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidEndLiveResize),
            name: NSWindow.didEndLiveResizeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillEnterFullScreen),
            name: NSWindow.willEnterFullScreenNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidEnterFullScreen),
            name: NSWindow.didEnterFullScreenNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillExitFullScreen),
            name: NSWindow.willExitFullScreenNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidExitFullScreen),
            name: NSWindow.didExitFullScreenNotification,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(systemAppearanceDidChange),
            name: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )

        #if DEBUG
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidChangeScreen),
            name: NSWindow.didChangeScreenNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidChangeBackingProperties),
            name: NSWindow.didChangeBackingPropertiesNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidChangeScreenParameters),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        #endif
    }

    @objc private func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window == self.view.window else {
            return
        }

        let windowId = ObjectIdentifier(window)

        guard Self.shouldTrackWindowSize(
            styleMask: window.styleMask,
            isFullScreenTransitionInProgress: isFullScreenTransitionInProgress,
            windowFrame: window.frame,
            visibleScreenFrame: window.screen?.visibleFrame
        ) else {
            sawLiveResizeStartForWindow = nil
            os_log("📊 [windowDidEndLiveResize] Skipping save - full-screen transition", log: logger, type: .default)
            return
        }

        // Only save if we previously observed a matching start event for this window.
        // This prevents saving sizes from programmatic/animated resizes.
        guard sawLiveResizeStartForWindow == windowId else {
            os_log("📊 [windowDidEndLiveResize] Skipping save - no matching start event for this window", log: logger, type: .default)
            // Reset flag to prevent false positives from mismatched events
            sawLiveResizeStartForWindow = nil
            return
        }

        didUserResizeSinceOpen = true
        if let size = self.currentSize, Self.isSizeValidForPersistence(size) {
            os_log("📊 [windowDidEndLiveResize] Saving size: %.0fx%.0f", log: logger, type: .default, size.width, size.height)
            AppearancePreference.shared.quickLookSize = size
        } else {
            os_log("📊 [windowDidEndLiveResize] Skipping save - size too small or nil", log: logger, type: .default)
        }

        // Reset flag after processing end event
        sawLiveResizeStartForWindow = nil

        #if DEBUG
        logScreenEnvironment(context: "windowDidEndLiveResize")
        #endif
    }

    @objc private func windowWillStartLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window == self.view.window else {
            return
        }
        guard Self.shouldTrackWindowSize(
            styleMask: window.styleMask,
            isFullScreenTransitionInProgress: isFullScreenTransitionInProgress,
            windowFrame: window.frame,
            visibleScreenFrame: window.screen?.visibleFrame
        ) else {
            sawLiveResizeStartForWindow = nil
            os_log("📊 [windowWillStartLiveResize] Ignoring full-screen transition", log: logger, type: .default)
            return
        }
        sawLiveResizeStartForWindow = ObjectIdentifier(window)
        os_log("📊 [windowWillStartLiveResize] Window starting live resize", log: logger, type: .default)

        #if DEBUG
        logScreenEnvironment(context: "windowWillStartLiveResize")
        #endif
    }

    static func shouldTrackWindowSize(
        styleMask: NSWindow.StyleMask,
        isFullScreenTransitionInProgress: Bool,
        windowFrame: CGRect? = nil,
        visibleScreenFrame: CGRect? = nil
    ) -> Bool {
        guard !isFullScreenTransitionInProgress, !styleMask.contains(.fullScreen) else {
            return false
        }

        guard let windowFrame, let visibleScreenFrame else {
            return true
        }

        // Quick Look full screen is hosted in a remote window that does not
        // forward full-screen notifications or expose .fullScreen here.
        let tolerance: CGFloat = 2
        let fillsVisibleScreen =
            abs(windowFrame.minX - visibleScreenFrame.minX) <= tolerance &&
            abs(windowFrame.minY - visibleScreenFrame.minY) <= tolerance &&
            abs(windowFrame.maxX - visibleScreenFrame.maxX) <= tolerance &&
            abs(windowFrame.maxY - visibleScreenFrame.maxY) <= tolerance

        return !fillsVisibleScreen
    }

    @objc private func windowWillEnterFullScreen(_ notification: Notification) {
        setFullScreenTransition(true, notification: notification, context: "willEnter")
    }

    @objc private func windowDidEnterFullScreen(_ notification: Notification) {
        setFullScreenTransition(false, notification: notification, context: "didEnter")
    }

    @objc private func windowWillExitFullScreen(_ notification: Notification) {
        setFullScreenTransition(true, notification: notification, context: "willExit")
    }

    @objc private func windowDidExitFullScreen(_ notification: Notification) {
        setFullScreenTransition(false, notification: notification, context: "didExit")
    }

    @objc private func systemAppearanceDidChange(_ notification: Notification) {
        guard AppearancePreference.shared.currentMode == .system else { return }
        applySelectedAppearanceToView()
        applyThemeToWebView()
        updateThemeButtonState()
        os_log("🌓 [systemAppearance] Applied global macOS appearance", log: logger, type: .default)
    }

    private func setFullScreenTransition(
        _ inProgress: Bool,
        notification: Notification,
        context: String
    ) {
        guard let window = notification.object as? NSWindow, window == view.window else {
            return
        }
        isFullScreenTransitionInProgress = inProgress
        sawLiveResizeStartForWindow = nil
        os_log("📊 [fullScreen] %{public}@ inProgress=%{public}@", log: logger, type: .default,
               context, inProgress ? "YES" : "NO")
    }

    #if DEBUG
    @objc private func windowDidChangeScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window == self.view.window else {
            return
        }
        os_log("📊 [windowDidChangeScreen] Window changed screen", log: logger, type: .default)
        logScreenEnvironment(context: "windowDidChangeScreen")
    }

    @objc private func windowDidChangeBackingProperties(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window == self.view.window else {
            return
        }
        os_log("📊 [windowDidChangeBackingProperties] Window backing properties changed", log: logger, type: .default)
        logScreenEnvironment(context: "windowDidChangeBackingProperties")
    }

    @objc private func applicationDidChangeScreenParameters(_ notification: Notification) {
        os_log("📊 [applicationDidChangeScreenParameters] App-wide screen parameters changed", log: logger, type: .default)
        logScreenEnvironment(context: "applicationDidChangeScreenParameters")
    }
    #endif
    
    private func constrainSizeToScreen(_ size: CGSize, screen: NSScreen?) -> CGSize {
        guard let screen = screen else { return size }
        
        let screenFrame = screen.visibleFrame
        let maxWidth = screenFrame.width * 0.95
        let maxHeight = screenFrame.height * 0.95
        
        if size.width <= maxWidth && size.height <= maxHeight {
            return size
        }
        
        let widthRatio = maxWidth / size.width
        let heightRatio = maxHeight / size.height
        let ratio = min(widthRatio, heightRatio)
        
        let constrainedSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        os_log("🔵 Constraining size from %.0fx%.0f to %.0fx%.0f for screen %.0fx%.0f",
               log: logger, type: .debug,
               size.width, size.height,
               constrainedSize.width, constrainedSize.height,
               screenFrame.width, screenFrame.height)
        
        return constrainedSize
    }
    
    private func getTargetScreen() -> NSScreen? {
        if let windowScreen = self.view.window?.screen {
            return windowScreen
        }
        
        return NSScreen.main ?? NSScreen.screens.first
    }
    
    private func startFileMonitoring() {
        guard let url = currentURL else {
            os_log("🟡 Cannot start file monitoring: currentURL is nil", log: logger, type: .debug)
            return
        }

        stopFileMonitoring()

        let path = url.path
        let fd = open(path, O_EVTONLY)

        if fd < 0 {
            os_log("🔴 Failed to open file for monitoring, using polling only: %{public}@", log: logger, type: .error, path)
            startPollingTimer()
            return
        }

        monitoredFileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )

        source.setEventHandler { [weak self, weak source] in
            guard let self else { return }
            let flags = source?.data ?? []
            if flags.contains(.delete) || flags.contains(.rename) {
                os_log("🟡 File replaced/renamed — restarting monitor: %{public}@",
                       log: self.logger, type: .debug, path)
                self.stopDispatchMonitor()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    guard let self else { return }
                    self.startFileMonitoring()
                    self.reloadFromDisk()
                }
                return
            }
            self.handleFileChange()
        }

        source.setCancelHandler { [weak self] in
            guard let self, self.monitoredFileDescriptor >= 0 else { return }
            close(self.monitoredFileDescriptor)
            self.monitoredFileDescriptor = -1
        }

        source.resume()
        self.fileMonitor = source
        os_log("🟢 File monitoring started for: %{public}@", log: logger, type: .default, path)

        startPollingTimer()
    }
    
    private func stopDispatchMonitor() {
        fileMonitor?.cancel()
        fileMonitor = nil
    }

    private func stopFileMonitoring() {
        stopDispatchMonitor()
        stopPollingTimer()
    }

    private func startPollingTimer() {
        stopPollingTimer()
        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: pollingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.pollFileForChanges()
        }
    }

    private func stopPollingTimer() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func pollFileForChanges() {
        guard let url = currentURL else { return }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return }
        let newSize = attrs[.size] as? UInt64 ?? 0
        let newMtime = attrs[.modificationDate] as? Date
        guard FileMonitorHelpers.shouldReload(
            newSize: newSize, newMtime: newMtime,
            knownSize: lastKnownFileSize ?? 0,
            knownMtime: lastKnownFileModificationDate
        ) else { return }
        os_log("🟢 [poll] File changed, reloading: %{public}@", log: logger, type: .default, url.lastPathComponent)
        reloadFromDisk()
    }

    private func reloadFromDisk(force: Bool = false, completion: ((Bool) -> Void)? = nil) {
        guard let url = currentURL else { completion?(false); return }
        if fileReadInFlight && !force { return }
        fileReadInFlight = true
        let version = fileReadVersion.next()
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try PreviewFileReader.read(url) }
            DispatchQueue.main.async {
                guard self.fileReadVersion.isCurrent(version), self.currentURL == url else { completion?(false); return }
                self.fileReadInFlight = false
                do {
                    let snapshot = try result.get()
                    if force || snapshot.content != self.pendingMarkdown {
                        self.prevMarkdown = self.pendingMarkdown
                        self.pendingMarkdown = snapshot.content
                        self.previewHasUnreadableImages = false
                        self.updateTruncationNotice(snapshot.isTruncated)
                        if self.isWebViewLoaded { self.renderCurrentMode() }
                    }
                    self.lastKnownFileSize = snapshot.size
                    self.lastKnownFileModificationDate = snapshot.modificationDate
                    completion?(true)
                } catch {
                    os_log("Reload failed: %{public}@", log: self.logger, type: .error, error.localizedDescription)
                self.showFailure(.reload, error: error)
                    completion?(false)
                }
            }
        }
    }

    private func handleFileChange() {
        reloadFromDisk()
    }
}
