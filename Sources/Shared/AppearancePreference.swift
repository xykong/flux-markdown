import Foundation
import SwiftUI
import AppKit

public enum AppearanceMode: String, CaseIterable, Identifiable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
    
    public var nsAppearance: NSAppearance? {
        switch self {
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        case .system: return nil // System handles it (nil implies inherited)
        }
    }
}

public class AppearancePreference: ObservableObject {
    public static let shared = AppearancePreference()
    
    // Key for UserDefaults
    private let key = "preferredAppearanceMode"
    private let quickLookSizeKey = "quickLookWindowSize"
    private let hostWindowFrameKey = "hostWindowFrame"
    private let zoomLevelKey = "markdownZoomLevel"
    private let scrollPositionsKey = "markdownScrollPositions"
    
    // File-based store for settings shared between main app and QuickLook extension.
    // Replaces App Group UserDefaults which fails on macOS 26 (Tahoe) for ad-hoc signed apps.
    // See: https://github.com/xykong/flux-markdown/issues/13
    private let sharedStore: SharedPreferenceStore
    private var pendingSyncWorkItem: DispatchWorkItem?

    public var currentMode: AppearanceMode {
        get {
            let raw = sharedStore.string(forKey: key) ?? AppearanceMode.light.rawValue
            return AppearanceMode(rawValue: raw) ?? .light
        }
        set {
            objectWillChange.send()
            sharedStore.set(newValue.rawValue, forKey: key)
            scheduleSyncToSharedStore()
        }
    }
    
    public var hostWindowFrame: CGRect? {
        get {
            guard let dict = localStore.dictionary(forKey: hostWindowFrameKey) else { return nil }
            let x = dict["x"] as? Double ?? 0
            let y = dict["y"] as? Double ?? 0
            let w = dict["w"] as? Double ?? 0
            let h = dict["h"] as? Double ?? 0
            return CGRect(x: x, y: y, width: w, height: h)
        }
        set {
            if let v = newValue {
                localStore.set(["x": v.origin.x, "y": v.origin.y, "w": v.width, "h": v.height], forKey: hostWindowFrameKey)
            } else {
                localStore.removeObject(forKey: hostWindowFrameKey)
            }
            localStore.synchronize()
        }
    }

    public var quickLookSize: CGSize? {
        get {
            guard let dict = localStore.dictionary(forKey: quickLookSizeKey) else { return nil }

            let w = dict["w"] as? Double ?? 0
            let h = dict["h"] as? Double ?? 0

            if w > 0 && h > 0 {
                return CGSize(width: w, height: h)
            }
            return nil
        }
        set {
            if let v = newValue {
                localStore.set(["w": Double(v.width), "h": Double(v.height)], forKey: quickLookSizeKey)
            } else {
                localStore.removeObject(forKey: quickLookSizeKey)
            }
            localStore.synchronize()
        }
    }

    public var zoomLevel: Double {
        get {
            let level = localStore.double(forKey: zoomLevelKey)
            return level == 0 ? 1.0 : level
        }
        set {
            localStore.set(newValue, forKey: zoomLevelKey)
            localStore.synchronize()
        }
    }
    
    private let baseFontSizeKey = "baseFontSize"
    private let codeHighlightThemeKey = "codeHighlightTheme"
    private let enableMermaidKey = "enableMermaid"
    private let enableKatexKey = "enableKatex"
    private let enableEmojiKey = "enableEmoji"
    private let uiLanguageKey = "uiLanguage"

    public var baseFontSize: Double {
        get {
            let v = sharedStore.double(forKey: baseFontSizeKey)
            return v == 0 ? 16 : v
        }
        set {
            objectWillChange.send()
            sharedStore.set(newValue, forKey: baseFontSizeKey)
            scheduleSyncToSharedStore()
        }
    }

    public var codeHighlightTheme: String {
        get { sharedStore.string(forKey: codeHighlightThemeKey) ?? "default" }
        set {
            objectWillChange.send()
            sharedStore.set(newValue, forKey: codeHighlightThemeKey)
            scheduleSyncToSharedStore()
        }
    }

    public var enableMermaid: Bool {
        get {
            guard sharedStore.object(forKey: enableMermaidKey) != nil else { return true }
            return sharedStore.bool(forKey: enableMermaidKey)
        }
        set {
            objectWillChange.send()
            sharedStore.set(newValue, forKey: enableMermaidKey)
            scheduleSyncToSharedStore()
        }
    }

    public var enableKatex: Bool {
        get {
            guard sharedStore.object(forKey: enableKatexKey) != nil else { return true }
            return sharedStore.bool(forKey: enableKatexKey)
        }
        set {
            objectWillChange.send()
            sharedStore.set(newValue, forKey: enableKatexKey)
            scheduleSyncToSharedStore()
        }
    }

    public var enableEmoji: Bool {
        get {
            guard sharedStore.object(forKey: enableEmojiKey) != nil else { return true }
            return sharedStore.bool(forKey: enableEmojiKey)
        }
        set {
            objectWillChange.send()
            sharedStore.set(newValue, forKey: enableEmojiKey)
            scheduleSyncToSharedStore()
        }
    }

    public var uiLanguage: String {
        get { sharedStore.string(forKey: uiLanguageKey) ?? "system" }
        set {
            objectWillChange.send()
            sharedStore.set(newValue, forKey: uiLanguageKey)
            scheduleSyncToSharedStore()
        }
    }

    // Per-process store for settings that don't need cross-process sharing
    // (zoom level, scroll positions, window sizes)
    private let localStore: UserDefaults

    public init() {
        // Detect if running inside the QuickLook extension by checking bundle identifier.
        // Extension: alwaysReload=true (short-lived, needs latest settings from main app).
        // Main app: alwaysReload=false (long-lived, writes settings itself, uses mod-date caching).
        let isExtension = Bundle.main.bundleIdentifier?.hasSuffix(".QuickLook") == true
        self.sharedStore = SharedPreferenceStore(alwaysReload: isExtension)
        self.localStore = UserDefaults.standard

        // Migrate preferences from pre-Tahoe App Group UserDefaults on first launch.
        // Safe to call from extension too (no-op since canWrite is false).
        sharedStore.migrateFromAppGroupIfNeeded()
    }

    /// Coalesces rapid preference changes into a single disk write.
    /// Writes after a 0.3s debounce, preventing 5+ writes when changing multiple settings.
    private func scheduleSyncToSharedStore() {
        pendingSyncWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.sharedStore.synchronize()
        }
        pendingSyncWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    /// Force-flush any pending shared preference writes to disk immediately.
    /// Called from applicationWillTerminate to ensure nothing is lost.
    public func flushSharedPreferences() {
        pendingSyncWorkItem?.cancel()
        pendingSyncWorkItem = nil
        sharedStore.synchronize()
    }
    
    private let maxScrollPositions = 100
    
    private struct ScrollPosition {
        let path: String
        let scrollY: Double
        
        init(path: String, scrollY: Double) {
            self.path = path
            self.scrollY = scrollY
        }
        
        init?(dict: [String: Any]) {
            guard let path = dict["path"] as? String,
                  let scrollY = dict["scrollY"] as? Double else {
                return nil
            }
            self.path = path
            self.scrollY = scrollY
        }
        
        func toDictionary() -> [String: Any] {
            return ["path": path, "scrollY": scrollY]
        }
    }
    
    private var scrollPositions: [ScrollPosition] {
        get {
            guard let array = localStore.array(forKey: scrollPositionsKey) as? [[String: Any]] else {
                return []
            }
            return array.compactMap { ScrollPosition(dict: $0) }
        }
        set {
            let array = newValue.map { $0.toDictionary() }
            localStore.set(array, forKey: scrollPositionsKey)
            localStore.synchronize()
        }
    }
    
    public func getScrollPosition(for filePath: String) -> Double? {
        return scrollPositions.first { $0.path == filePath }?.scrollY
    }
    
    public func setScrollPosition(for filePath: String, value: Double) {
        var positions = scrollPositions
        
        positions.removeAll { $0.path == filePath }
        positions.insert(ScrollPosition(path: filePath, scrollY: value), at: 0)
        
        if positions.count > maxScrollPositions {
            positions = Array(positions.prefix(maxScrollPositions))
        }
        
        scrollPositions = positions
    }
    
    public func clearScrollPositions() {
        localStore.removeObject(forKey: scrollPositionsKey)
        localStore.synchronize()
    }
    
    // Helper to apply appearance to a view
    public func apply(to view: NSView) {
        if let appearance = currentMode.nsAppearance {
            view.appearance = appearance
        } else {
            view.appearance = nil // Reset to system
        }
    }
}
