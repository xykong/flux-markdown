import Cocoa
import QuickLookUI
import os.log
import WebKit
import SwiftUI

// Subclass WKWebView to intercept mouse events and prevent them from bubbling up 
// to the QuickLook host, which would otherwise trigger "Open with default app".
class InteractiveWebView: WKWebView {
    private let logger = OSLog(subsystem: "com.markdownquicklook.app", category: "InteractiveWebView")
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        let result = self.window?.makeFirstResponder(self)
        os_log("🔵 WebView mouseDown - makeFirstResponder result: %{public}@", 
               log: logger, type: .debug, 
               result == true ? "SUCCESS" : "FAILED")
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        os_log("🔵 WebView becomeFirstResponder called", log: logger, type: .debug)
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        os_log("🔵 WebView keyDown: %{public}@", log: logger, type: .debug, event.charactersIgnoringModifiers ?? "nil")
        super.keyDown(with: event)
    }
    
    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            os_log("🔵 WebView scrollWheel with CMD modifier", log: logger, type: .debug)
            
            let js = """
            (function() {
                var currentZoom = parseFloat(document.getElementById('markdown-preview')?.style.transform?.match(/scale\\(([^)]+)\\)/)?.[1] || 1.0);
                var delta = \(event.scrollingDeltaY);
                var newZoom = currentZoom + (delta > 0 ? 0.05 : -0.05);
                newZoom = Math.max(0.5, Math.min(3.0, newZoom));
                if (window.setZoomLevel) {
                    window.setZoomLevel(newZoom);
                }
            })();
            """
            
            self.evaluateJavaScript(js, completionHandler: nil)
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
    var pendingMarkdown: String?
    var currentURL: URL?
    var isWebViewLoaded = false
    var currentZoomLevel: Double = 1.0
    var currentViewMode: ViewMode = .preview
    var localSchemeHandler: LocalSchemeHandler?
    
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
        return true
    }
    
    private var handshakeWorkItem: DispatchWorkItem?
    private let handshakeTimeoutInterval: TimeInterval = 10.0
    
    private var saveSizeWorkItem: DispatchWorkItem?
    private var resizeTrackingWorkItem: DispatchWorkItem?
    private var currentSize: CGSize?

    private var isResizeTrackingEnabled = false
    private var didUserResizeSinceOpen = false

    // Track which window we saw a live resize start event for.
    // This prevents spurious saves from programmatic resizes.
    // We only persist size if we observe both willStartLiveResize AND
    // didEndLiveResize for the SAME window.
    private var sawLiveResizeStartForWindow: ObjectIdentifier?
    
    // MARK: - File Monitoring
    private var fileMonitor: DispatchSourceFileSystemObject?
    private var monitoredFileDescriptor: Int32 = -1
    
    private let logger = OSLog(subsystem: "com.markdownquicklook.app", category: "MarkdownPreview")
    
    private let maxPreviewSizeBytes: UInt64 = 500 * 1024 // 500KB limit
    
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
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        os_log("🔵 init(coder:) called", log: logger, type: .debug)
    }
    
    private var themeButton: NSButton!
    private var sourceButton: NSButton!
    
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
        self.view.layer?.backgroundColor = NSColor.white.cgColor
        
        AppearancePreference.shared.apply(to: self.view)
        
        setupWindowResizeObservers()
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            os_log("🔵 Local event monitor triggered", log: self?.logger ?? .default, type: .debug)
            return self?.handleKeyDownEvent(event) ?? event
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
        
        webConfiguration.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "logger")
        userContentController.add(self, name: "linkClicked")
        webConfiguration.userContentController = userContentController
        
        let schemeHandler = LocalSchemeHandler()
        webConfiguration.setURLSchemeHandler(schemeHandler, forURLScheme: "local-md")
        localSchemeHandler = schemeHandler
        
        os_log("🔵 initializing InteractiveWebView instance...", log: logger, type: .default)
        webView = InteractiveWebView(frame: self.view.bounds, configuration: webConfiguration)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        self.view.addSubview(webView)
        
        os_log("🔵 WebView initialized and added to view", log: logger, type: .default)
        
        setupThemeButton()
        setupSourceButton()
        
        var bundleURL: URL?
        if let url = Bundle(for: type(of: self)).url(forResource: "index", withExtension: "html", subdirectory: "WebRenderer") {
            bundleURL = url
        } else if let url = Bundle(for: type(of: self)).url(forResource: "index", withExtension: "html", subdirectory: "dist") {
            bundleURL = url
        } else if let url = Bundle(for: type(of: self)).url(forResource: "index", withExtension: "html") {
            bundleURL = url
        }
        
        if let url = bundleURL {
            let distDir = url.deletingLastPathComponent()
            webView.loadFileURL(url, allowingReadAccessTo: distDir)
            os_log("🔵 Loaded HTML via loadFileURL: %{public}@", log: logger, type: .default, url.path)
        } else {
            webView.loadHTMLString("<h1>Error: index.html not found</h1>", baseURL: nil)
        }

        let doubleClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick(_:)))
        doubleClickGesture.numberOfClicksRequired = 2
        doubleClickGesture.delaysPrimaryMouseButtonEvents = false
        webView.addGestureRecognizer(doubleClickGesture)
        
        webView.allowsMagnification = true
        webView.magnification = currentZoomLevel
        os_log("🔵 Enabled WKWebView magnification, initial level: %.2f", log: logger, type: .default, currentZoomLevel)
        
        if #available(macOS 15.0, *) {
            webView.writingToolsBehavior = .none
        }
        
        DispatchQueue.main.async {
            self.view.window?.makeFirstResponder(self.webView)
        }

        #if DEBUG
        setupDebugLabel()
        #endif
        
        currentZoomLevel = AppearancePreference.shared.zoomLevel
        
        startResizeTracking()
    }
    
    @objc func handleDoubleClick(_ gesture: NSClickGestureRecognizer) {
        os_log("🔵 Intercepted double click gesture", log: logger, type: .debug)
    }
    
    
    public override func viewDidLayout() {
        super.viewDidLayout()
        
        let size = self.view.frame.size
        os_log("📊 [viewDidLayout] size=%.0fx%.0f trackingEnabled=%{public}@",
               log: logger, type: .default,
               size.width, size.height,
               isResizeTrackingEnabled ? "YES" : "NO")
        
        guard isResizeTrackingEnabled else {
            os_log("📊 [viewDidLayout] SKIPPED - tracking disabled", log: logger, type: .default)
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
        logScreenEnvironment(context: "viewDidAppear")
        
        DispatchQueue.main.async { [weak self] in
            self?.view.window?.makeFirstResponder(self)
            os_log("🔵 Attempted to make view controller first responder", 
                   log: self?.logger ?? .default, type: .default)
        }
    }
    
    public override func viewWillDisappear() {
        super.viewWillDisappear()
        logScreenEnvironment(context: "viewWillDisappear")

        stopFileMonitoring()

        os_log("📊 [viewWillDisappear] trackingEnabled=%{public}@ didUserResize=%{public}@ currentSize=%{public}@",
               log: logger, type: .default,
               isResizeTrackingEnabled ? "YES" : "NO",
               didUserResizeSinceOpen ? "YES" : "NO",
               currentSize != nil ? "\(currentSize!.width)x\(currentSize!.height)" : "nil")

        if didUserResizeSinceOpen, let size = self.currentSize, Self.isSizeValidForPersistence(size) {
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
    }
    
    private func cleanupWebView() {
        guard let webView = webView else { return }
        
        os_log("🔵 Cleaning up WKWebView (PID: %d, WebView: %p)", log: logger, type: .default, getpid(), webView)
        
        cancelHandshakeTimeout()
        
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "logger")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "linkClicked")
        
        for recognizer in webView.gestureRecognizers {
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
        NotificationCenter.default.removeObserver(self)
        handshakeWorkItem?.cancel()
        saveSizeWorkItem?.cancel()
        resizeTrackingWorkItem?.cancel()
    }
    

    
    private func setupThemeButton() {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .circular
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.1).cgColor
        button.layer?.cornerRadius = 15
        button.target = self
        button.action = #selector(toggleTheme)
        
        self.view.addSubview(button)
        self.themeButton = button
        
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 10),
            button.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -10),
            button.widthAnchor.constraint(equalToConstant: 30),
            button.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        updateThemeButtonState()
    }
    
    @objc private func toggleTheme() {
        let current = AppearancePreference.shared.currentMode
        let newMode: AppearanceMode = (current == .dark) ? .light : .dark
        
        AppearancePreference.shared.currentMode = newMode
        AppearancePreference.shared.apply(to: self.view)
        
        updateThemeButtonState()
        
        if isWebViewLoaded {
            renderPendingMarkdown()
        }
    }
    
    private func updateThemeButtonState() {
        let isDark = AppearancePreference.shared.currentMode == .dark
        let iconName = isDark ? "sun.max.fill" : "moon.fill"
        let iconColor = isDark ? NSColor.yellow : NSColor.darkGray
        
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Toggle Theme") {
            themeButton.image = image
            themeButton.contentTintColor = iconColor
        }
    }
    
    private func setupSourceButton() {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .circular
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.1).cgColor
        button.layer?.cornerRadius = 15
        button.target = self
        button.action = #selector(toggleViewMode)
        
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
            
            self.currentViewMode = (self.currentViewMode == .preview) ? .source : .preview
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
            }
        }
    }
    
    private func updateSourceButtonState() {
        let iconName = (currentViewMode == .source) ? "eye.fill" : "doc.text.fill"
        let iconColor = (currentViewMode == .source) ? NSColor.systemBlue : NSColor.darkGray
        
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Toggle Source View") {
            sourceButton.image = image
            sourceButton.contentTintColor = iconColor
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
        guard let content = pendingMarkdown else {
            os_log("🟡 renderSourceView called but pendingMarkdown is nil", log: logger, type: .debug)
            return
        }
        
        guard isWebViewLoaded else {
            os_log("🟡 renderSourceView called but WebView not ready", log: logger, type: .debug)
            return
        }
        
        os_log("🔵 renderSourceView called with content length: %d", log: logger, type: .debug, content.count)
        
        guard let contentData = try? JSONSerialization.data(withJSONObject: [content], options: []),
              let contentJsonArray = String(data: contentData, encoding: .utf8) else {
            os_log("🔴 Failed to encode content to JSON", log: self.logger, type: .error)
            return
        }
        
        let safeContentArg = String(contentJsonArray.dropFirst().dropLast())
        
        let appearanceName = self.view.effectiveAppearance.name
        var theme = "system"
        if appearanceName == .darkAqua || appearanceName == .vibrantDark || appearanceName == .accessibilityHighContrastDarkAqua || appearanceName == .accessibilityHighContrastVibrantDark {
            theme = "dark"
        } else if appearanceName == .aqua || appearanceName == .vibrantLight || appearanceName == .accessibilityHighContrastAqua || appearanceName == .accessibilityHighContrastVibrantLight {
            theme = "light"
        }
        
        let callJs = """
        try {
            window.renderSource(\(safeContentArg), "\(theme)");
            "success"
        } catch(e) {
            "error: " + e.toString()
        }
        """
        
        self.webView.evaluateJavaScript(callJs) { (innerResult, innerError) in
            if let innerError = innerError {
                os_log("🔴 JS Execution Error (renderSource): %{public}@", log: self.logger, type: .error, innerError.localizedDescription)
            } else if let res = innerResult as? String {
                os_log("🔵 JS Execution Result (renderSource): %{public}@", log: self.logger, type: .debug, res)
            }
            
            self.applyZoom()
        }
    }
    
    @objc private func zoomIn() {
        currentZoomLevel = min(currentZoomLevel + 0.1, 3.0)
        applyZoom()
    }
    
    @objc private func zoomOut() {
        currentZoomLevel = max(currentZoomLevel - 0.1, 0.5)
        applyZoom()
    }
    
    @objc private func resetZoom() {
        currentZoomLevel = 1.0
        applyZoom()
    }
    
    private func applyZoom() {
        webView.magnification = currentZoomLevel
        os_log("🔵 Zoom applied via magnification: %.2f", log: logger, type: .debug, currentZoomLevel)
        AppearancePreference.shared.zoomLevel = currentZoomLevel
    }
    
    private func handleKeyDownEvent(_ event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        os_log("🔵 handleKeyDownEvent: key=%{public}@ flags=%{public}@", 
               log: logger, type: .debug, 
               event.charactersIgnoringModifiers ?? "nil",
               String(describing: flags))
        
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
    
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        os_log("🔵 performKeyEquivalent called: key=%{public}@ modifiers=%{public}@", 
               log: logger, type: .debug,
               event.charactersIgnoringModifiers ?? "nil",
               String(describing: event.modifierFlags))
        
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
        let version = debugInfo?["CFBundleShortVersionString"] as? String ?? "Unknown"
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
        os_log("🔵 preparePreviewOfFile called for: %{public}@", log: logger, type: .default, url.path)
        self.currentURL = url
        
        let accessGranted = url.startAccessingSecurityScopedResource()
        os_log("🔵 Security-scoped resource access: %{public}@", log: logger, type: .debug, accessGranted ? "GRANTED" : "DENIED")
        
        logScreenEnvironment(context: "preparePreviewOfFile-ENTRY")
        
        DispatchQueue.main.async {
            self.logScreenEnvironment(context: "preparePreviewOfFile-ASYNC-START")
            
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
            
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? UInt64 ?? 0
                
                var content: String
                if fileSize > self.maxPreviewSizeBytes {
                    let fileHandle = try FileHandle(forReadingFrom: url)
                    defer { try? fileHandle.close() }
                    let data = fileHandle.readData(ofLength: Int(self.maxPreviewSizeBytes))
                    if var stringContent = String(data: data, encoding: .utf8) {
                        if let lastNewline = stringContent.lastIndex(of: "\n") {
                            stringContent = String(stringContent[...lastNewline])
                        }
                        content = stringContent + "\n\n> **Preview truncated.**"
                    } else {
                        content = "> **Encoding Error**"
                    }
                } else {
                    content = try String(contentsOf: url, encoding: .utf8)
                }
                
                self.pendingMarkdown = content
                if self.isWebViewLoaded {
                    self.renderPendingMarkdown()
                }
                
                self.startFileMonitoring()
            } catch {
                os_log("🔴 Failed to read file: %{public}@", log: self.logger, type: .error, error.localizedDescription)
            }
        }
        handler(nil)
    }
    
    nonisolated private func collectImageData(from markdownURL: URL, content: String) -> [String: String] {
        var imageData: [String: String] = [:]
        let baseDir = markdownURL.deletingLastPathComponent()
        
        let pattern = #"!\[[^\]]*\]\(([^)"]+(?:\s+"[^"]*")?)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return imageData
        }
        
        let nsContent = content as NSString
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))
        
        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            var imagePath = nsContent.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            
            if let spaceIndex = imagePath.firstIndex(of: " "), imagePath[spaceIndex...].contains("\"") {
                imagePath = String(imagePath[..<spaceIndex])
            }
            
            // Skip network URLs and data URLs
            if imagePath.starts(with: "http://") || imagePath.starts(with: "https://") || 
               imagePath.starts(with: "data:") {
                continue
            }
            
            // Store the original path as key (before any transformations)
            let originalPath = imagePath
            var cleanPath = imagePath
            var imageURL: URL
            
            // Handle file:// protocol
            if imagePath.starts(with: "file://") {
                cleanPath = String(imagePath.dropFirst("file://".count))
                imageURL = URL(fileURLWithPath: cleanPath)
            }
            // Handle absolute filesystem paths
            else if imagePath.starts(with: "/") {
                imageURL = URL(fileURLWithPath: imagePath)
                cleanPath = imagePath
            }
            // Handle relative paths
            else {
                if cleanPath.starts(with: "./") {
                    cleanPath = String(cleanPath.dropFirst(2))
                }
                
                imageURL = baseDir
                for component in cleanPath.split(separator: "/") {
                    let componentStr = String(component)
                    
                    if componentStr == ".." {
                        imageURL.deleteLastPathComponent()
                    } else {
                        if let decoded = componentStr.removingPercentEncoding {
                            imageURL.appendPathComponent(decoded)
                        } else {
                            imageURL.appendPathComponent(componentStr)
                        }
                    }
                }
            }
            
            os_log("🔵 Trying to load image: %{public}@ (original: %{public}@, cleanPath: %{public}@)", log: logger, type: .debug, imageURL.path, originalPath, cleanPath)
            
            do {
                let data = try Data(contentsOf: imageURL)
                let base64 = data.base64EncodedString()
                let mimeType = mimeTypeForExtension(imageURL.pathExtension)
                let dataURL = "data:\(mimeType);base64,\(base64)"
                
                // Store using the original path as key
                imageData[originalPath] = dataURL
                
                os_log("🟢 Collected image: key='%{public}@' -> file='%{public}@' (%d bytes)", log: logger, type: .debug, originalPath, imageURL.path, data.count)
            } catch {
                os_log("🔴 Failed to load image: %{public}@ (original: %{public}@) - Error: %{public}@", log: logger, type: .error, imageURL.path, originalPath, error.localizedDescription)
            }
        }
        
        os_log("🔵 Collected %d images from %d references", log: logger, type: .debug, imageData.count, matches.count)
        
        for (key, _) in imageData {
            os_log("🔵 ImageData key: '%{public}@'", log: logger, type: .debug, key)
        }
        
        return imageData
    }
    
    nonisolated private func mimeTypeForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "ico": return "image/x-icon"
        case "bmp": return "image/bmp"
        default: return "image/\(ext)"
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
        
        os_log("🔵 renderPendingMarkdown called with content length: %d", log: logger, type: .debug, content.count)
        
        guard let contentData = try? JSONSerialization.data(withJSONObject: [content], options: []),
              let contentJsonArray = String(data: contentData, encoding: .utf8) else {
            os_log("🔴 Failed to encode content to JSON", log: self.logger, type: .error)
            return
        }
        
        let safeContentArg = String(contentJsonArray.dropFirst().dropLast())
        
        let appearanceName = self.view.effectiveAppearance.name
        var theme = "system"
        if appearanceName == .darkAqua || appearanceName == .vibrantDark || appearanceName == .accessibilityHighContrastDarkAqua || appearanceName == .accessibilityHighContrastVibrantDark {
            theme = "dark"
        } else if appearanceName == .aqua || appearanceName == .vibrantLight || appearanceName == .accessibilityHighContrastAqua || appearanceName == .accessibilityHighContrastVibrantLight {
            theme = "light"
        }
        
        let capturedURL = self.currentURL
        
        if let url = capturedURL {
            localSchemeHandler?.baseDirectory = url.deletingLastPathComponent()
        }
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            var options: [String: Any] = ["theme": theme]
            if let url = capturedURL {
                options["baseUrl"] = url.deletingLastPathComponent().path
            }
            
            guard let optionsData = try? JSONSerialization.data(withJSONObject: options, options: []),
                  let optionsJson = String(data: optionsData, encoding: .utf8) else {
                await MainActor.run {
                    os_log("🔴 Failed to encode options to JSON", log: self.logger, type: .error)
                }
                return
            }
            
            let callJs = """
            try {
                window.renderMarkdown(\(safeContentArg), \(optionsJson));
                "success"
            } catch(e) {
                "error: " + e.toString()
            }
            """
            
            await MainActor.run {
                self.webView.evaluateJavaScript(callJs) { (innerResult, innerError) in
                    if let innerError = innerError {
                        os_log("🔴 JS Execution Error: %{public}@", log: self.logger, type: .error, innerError.localizedDescription)
                    } else if let res = innerResult as? String {
                        os_log("🔵 JS Execution Result: %{public}@", log: self.logger, type: .debug, res)
                    }
                    
                    self.applyZoom()
                    
                    if let url = self.currentURL,
                       let savedScrollY = AppearancePreference.shared.getScrollPosition(for: url.path),
                       savedScrollY > 0 {
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
        startHandshakeTimeout()
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        os_log("🔵 WebView didStartProvisionalNavigation (resetting state)", log: logger, type: .debug)
        isWebViewLoaded = false
        cancelHandshakeTimeout()
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        os_log("🔴 WebView didFail navigation: %{public}@", log: logger, type: .error, error.localizedDescription)
        cancelHandshakeTimeout()
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        os_log("🔴 WebView didFailProvisionalNavigation: %{public}@", log: logger, type: .error, error.localizedDescription)
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
        webView.reload()
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "logger", let body = message.body as? String {
            os_log("🟢 JS Log: %{public}@", log: logger, type: .debug, body)
            
            if body == "rendererReady" {
                os_log("🟢 Renderer Handshake Received!", log: logger, type: .default)
                cancelHandshakeTimeout()
                
                isWebViewLoaded = true
                renderPendingMarkdown()
            }
        } else if message.name == "linkClicked", let href = message.body as? String {
            os_log("🔵 Link clicked from JS: %{public}@", log: logger, type: .default, href)
            handleLinkClick(href: href)
        }
    }
    
    private func handleLinkClick(href: String) {
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
    
    private func showLinkUnsupportedToast() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.toastView != nil {
                return
            }
            
            let toastContainer = NSView()
            toastContainer.wantsLayer = true
            toastContainer.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.95).cgColor
            toastContainer.layer?.cornerRadius = 8
            toastContainer.translatesAutoresizingMaskIntoConstraints = false
            
            let iconImageView = NSImageView()
            iconImageView.image = NSImage(systemSymbolName: "info.circle.fill", accessibilityDescription: nil)
            iconImageView.contentTintColor = .white
            iconImageView.translatesAutoresizingMaskIntoConstraints = false
            
            let messageLabel = NSTextField(labelWithString: NSLocalizedString("QuickLook preview does not support link navigation", comment: "Toast message when link clicked in QuickLook"))
            messageLabel.textColor = .white
            messageLabel.font = .systemFont(ofSize: 13, weight: .medium)
            messageLabel.translatesAutoresizingMaskIntoConstraints = false
            
            let hintLabel = NSTextField(labelWithString: NSLocalizedString("Double-click .md file to open in main app for full functionality", comment: "Toast hint message"))
            hintLabel.textColor = NSColor.white.withAlphaComponent(0.9)
            hintLabel.font = .systemFont(ofSize: 11)
            hintLabel.translatesAutoresizingMaskIntoConstraints = false
            
            toastContainer.addSubview(iconImageView)
            toastContainer.addSubview(messageLabel)
            toastContainer.addSubview(hintLabel)
            self.view.addSubview(toastContainer)
            
            NSLayoutConstraint.activate([
                toastContainer.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 16),
                toastContainer.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                toastContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 500),
                
                iconImageView.leadingAnchor.constraint(equalTo: toastContainer.leadingAnchor, constant: 12),
                iconImageView.centerYAnchor.constraint(equalTo: toastContainer.centerYAnchor),
                iconImageView.widthAnchor.constraint(equalToConstant: 20),
                iconImageView.heightAnchor.constraint(equalToConstant: 20),
                
                messageLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
                messageLabel.trailingAnchor.constraint(equalTo: toastContainer.trailingAnchor, constant: -12),
                messageLabel.topAnchor.constraint(equalTo: toastContainer.topAnchor, constant: 10),
                
                hintLabel.leadingAnchor.constraint(equalTo: messageLabel.leadingAnchor),
                hintLabel.trailingAnchor.constraint(equalTo: messageLabel.trailingAnchor),
                hintLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 2),
                hintLabel.bottomAnchor.constraint(equalTo: toastContainer.bottomAnchor, constant: -10)
            ])
            
            self.toastView = toastContainer
            
            toastContainer.alphaValue = 0
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                toastContainer.animator().alphaValue = 1
            })
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self, let toast = self.toastView else { return }
                
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.3
                    toast.animator().alphaValue = 0
                }, completionHandler: {
                    toast.removeFromSuperview()
                    self.toastView = nil
                })
            }
        }
    }
    
    private func startHandshakeTimeout() {
        cancelHandshakeTimeout()
        
        if isWebViewLoaded { return }
        
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if !self.isWebViewLoaded {
                os_log("🔴 Renderer Handshake Timeout (%{public}.1fs)! Showing non-destructive error.", log: self.logger, type: .error, self.handshakeTimeoutInterval)
                
                let js = """
                (function() {
                    var status = document.getElementById('loading-status');
                    if (status) {
                        status.textContent = 'Renderer timed out. Please retry.';
                        status.style.color = 'red';
                    } else {
                        var d = document.createElement('div');
                        d.style.position = 'fixed';
                        d.style.top = '10px';
                        d.style.right = '10px';
                        d.style.background = 'rgba(255,0,0,0.8)';
                        d.style.color = 'white';
                        d.style.padding = '5px 10px';
                        d.style.borderRadius = '4px';
                        d.style.zIndex = '9999';
                        d.innerText = 'Renderer Timeout';
                        document.body.appendChild(d);
                    }
                })();
                """
                self.webView.evaluateJavaScript(js, completionHandler: nil)
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
        sawLiveResizeStartForWindow = ObjectIdentifier(window)
        os_log("📊 [windowWillStartLiveResize] Window starting live resize", log: logger, type: .default)

        #if DEBUG
        logScreenEnvironment(context: "windowWillStartLiveResize")
        #endif
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
        
        guard fd >= 0 else {
            os_log("🔴 Failed to open file for monitoring: %{public}@", log: logger, type: .error, path)
            return
        }
        
        monitoredFileDescriptor = fd
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            os_log("🟢 File change detected, reloading content", log: self.logger, type: .default)
            self.handleFileChange()
        }
        
        source.setCancelHandler { [weak self] in
            guard let self = self, self.monitoredFileDescriptor >= 0 else { return }
            close(self.monitoredFileDescriptor)
            self.monitoredFileDescriptor = -1
        }
        
        source.resume()
        self.fileMonitor = source
        
        os_log("🟢 File monitoring started for: %{public}@", log: logger, type: .default, path)
    }
    
    private func stopFileMonitoring() {
        guard let monitor = fileMonitor else { return }
        
        monitor.cancel()
        fileMonitor = nil
        
        os_log("🔵 File monitoring stopped", log: logger, type: .debug)
    }
    
    private func handleFileChange() {
        guard let url = currentURL else {
            os_log("🔴 handleFileChange called but currentURL is nil", log: logger, type: .error)
            return
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            
            var content: String
            if fileSize > self.maxPreviewSizeBytes {
                let fileHandle = try FileHandle(forReadingFrom: url)
                defer { try? fileHandle.close() }
                let data = fileHandle.readData(ofLength: Int(self.maxPreviewSizeBytes))
                if var stringContent = String(data: data, encoding: .utf8) {
                    if let lastNewline = stringContent.lastIndex(of: "\n") {
                        stringContent = String(stringContent[...lastNewline])
                    }
                    content = stringContent + "\n\n> **Preview truncated.**"
                } else {
                    content = "> **Encoding Error**"
                }
            } else {
                content = try String(contentsOf: url, encoding: .utf8)
            }
            
            self.pendingMarkdown = content
            if self.isWebViewLoaded {
                self.renderPendingMarkdown()
            }
            
            os_log("🟢 File content reloaded successfully", log: logger, type: .default)
        } catch {
            os_log("🔴 Failed to reload file: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }
}
