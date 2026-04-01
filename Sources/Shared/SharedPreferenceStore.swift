import Foundation

/// A file-based preference store for sharing settings between the main app
/// and the sandboxed QuickLook extension without requiring App Group entitlements.
///
/// On macOS 26 (Tahoe), ad-hoc signed apps can no longer use App Group containers
/// because `containermanagerd` requires a valid Team ID prefix. This store replaces
/// `UserDefaults(suiteName:)` with a plist file at a known location.
///
/// - The main app (unsandboxed) writes to:
///   `~/Library/Application Support/FluxMarkdown/shared-preferences.plist`
/// - The QuickLook extension (sandboxed) reads from that file via its
///   `temporary-exception.files.absolute-path.read-only` entitlement for `$HOME/`.
///
/// Both processes resolve the path via `getpwuid(getuid())` to ensure the real
/// home directory is used, bypassing sandbox container redirection.
///
/// **Thread safety:** All access is serialized through a serial DispatchQueue.
/// This matches the thread-safety guarantee of the `UserDefaults` API it replaces.
///
/// **Reload strategy:** The extension re-reads the plist from disk on every read
/// call. The file is small (~1 KB) and the extension's lifetime is short (one preview),
/// so the I/O cost is negligible and avoids stale-cache issues from same-second writes.
/// The main app skips redundant reloads using file modification date checks.
///
/// See: https://github.com/xykong/flux-markdown/issues/13
public class SharedPreferenceStore {

    private static let relativePath = "Library/Application Support/FluxMarkdown/shared-preferences.plist"

    /// Legacy App Group identifier — used for one-time migration of preferences
    /// from pre-Tahoe versions that used App Group UserDefaults.
    static let legacyAppGroupIdentifier = "group.com.xykong.Markdown"
    private static let migrationDoneKey = "_didMigrateFromAppGroup"

    private var cache: [String: Any]
    private let fileURL: URL
    private let canWrite: Bool
    private var lastModificationDate: Date?
    private let queue = DispatchQueue(label: "com.xykong.Markdown.SharedPreferenceStore")

    /// If true, always re-reads from disk on every read (for the extension).
    /// If false, uses modification-date caching (for the main app).
    private let alwaysReload: Bool

    /// Creates a store backed by the default shared plist location.
    /// - Parameter alwaysReload: When true, re-reads from disk on every read.
    ///   Use `true` for the QuickLook extension (short-lived, needs latest settings).
    ///   Use `false` for the main app (long-lived, writes settings itself).
    public convenience init(alwaysReload: Bool = false) {
        let url = Self.defaultFileURL()
        self.init(fileURL: url, alwaysReload: alwaysReload)
    }

    /// Creates a store backed by a specific file URL (for testing).
    public init(fileURL: URL, alwaysReload: Bool = false) {
        self.fileURL = fileURL
        self.alwaysReload = alwaysReload

        // Ensure the parent directory exists (succeeds for unsandboxed main app;
        // may fail for sandboxed extension — that's expected).
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Use an explicit writability check rather than inferring from directory creation,
        // since createDirectory can succeed for an existing directory even without write access.
        self.canWrite = FileManager.default.isWritableFile(atPath: dir.path)

        // Load existing preferences from file
        if let dict = NSDictionary(contentsOf: fileURL) as? [String: Any] {
            self.cache = dict
            self.lastModificationDate = Self.modificationDate(of: fileURL)
        } else {
            self.cache = [:]
            self.lastModificationDate = nil
        }
    }

    // MARK: - One-time migration from App Group UserDefaults

    /// Migrates preferences from the legacy App Group UserDefaults to this file-based store.
    /// Safe to call multiple times — runs only once per installation.
    /// Should be called from the main app's init path (not the extension).
    public func migrateFromAppGroupIfNeeded() {
        queue.sync {
            guard canWrite else { return }
            guard cache[Self.migrationDoneKey] == nil else { return }

            guard let legacyDefaults = UserDefaults(suiteName: Self.legacyAppGroupIdentifier) else {
                cache[Self.migrationDoneKey] = true
                _synchronizeUnsafe()
                return
            }

            let keysToMigrate = [
                "preferredAppearanceMode",
                "baseFontSize",
                "codeHighlightTheme",
                "enableMermaid",
                "enableKatex",
                "enableEmoji",
                "uiLanguage"
            ]

            var migrated = 0
            for key in keysToMigrate {
                if cache[key] == nil, let value = legacyDefaults.object(forKey: key) {
                    cache[key] = value
                    migrated += 1
                }
            }

            cache[Self.migrationDoneKey] = true
            if _synchronizeUnsafe() && migrated > 0 {
                NSLog("[SharedPreferenceStore] Migrated %d preference(s) from App Group UserDefaults", migrated)
            }
        }
    }

    // MARK: - Reading

    public func string(forKey key: String) -> String? {
        queue.sync {
            reloadIfNeeded()
            return cache[key] as? String
        }
    }

    public func double(forKey key: String) -> Double {
        queue.sync {
            reloadIfNeeded()
            return cache[key] as? Double ?? 0
        }
    }

    public func bool(forKey key: String) -> Bool {
        queue.sync {
            reloadIfNeeded()
            return cache[key] as? Bool ?? false
        }
    }

    public func object(forKey key: String) -> Any? {
        queue.sync {
            reloadIfNeeded()
            return cache[key]
        }
    }

    public func dictionary(forKey key: String) -> [String: Any]? {
        queue.sync {
            reloadIfNeeded()
            return cache[key] as? [String: Any]
        }
    }

    public func array(forKey key: String) -> [Any]? {
        queue.sync {
            reloadIfNeeded()
            return cache[key] as? [Any]
        }
    }

    // MARK: - Writing (updates in-memory cache; persists to disk only if writable)

    public func set(_ value: String, forKey key: String) {
        queue.sync { cache[key] = value }
    }

    public func set(_ value: Bool, forKey key: String) {
        queue.sync { cache[key] = value }
    }

    public func set(_ value: Double, forKey key: String) {
        queue.sync { cache[key] = value }
    }

    public func set(_ value: [String: Any], forKey key: String) {
        queue.sync { cache[key] = value }
    }

    public func set(_ value: [Any], forKey key: String) {
        queue.sync { cache[key] = value }
    }

    public func setNil(forKey key: String) {
        queue.sync { _ = cache.removeValue(forKey: key) }
    }

    public func removeObject(forKey key: String) {
        queue.sync { _ = cache.removeValue(forKey: key) }
    }

    /// Flush in-memory cache to disk. No-op for the sandboxed extension.
    @discardableResult
    public func synchronize() -> Bool {
        queue.sync { _synchronizeUnsafe() }
    }

    // MARK: - Private

    /// Resolves the real user home directory via the password database,
    /// bypassing sandbox container redirection. This ensures the main app
    /// and sandboxed QuickLook extension both resolve to the same absolute path.
    private static func realHomeDirectory() -> URL {
        if let pw = getpwuid(getuid()), let home = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: home))
        }
        // getpwuid failed — this is unexpected on macOS. Log a warning because
        // the fallback will return the container path for sandboxed processes,
        // silently breaking cross-process preference sharing.
        NSLog("[SharedPreferenceStore] WARNING: getpwuid(getuid()) failed — " +
              "falling back to homeDirectoryForCurrentUser. " +
              "Preference sharing between main app and extension may not work.")
        return FileManager.default.homeDirectoryForCurrentUser
    }

    private static func defaultFileURL() -> URL {
        return realHomeDirectory().appendingPathComponent(relativePath)
    }

    /// Must be called within `queue.sync`. Writes cache to disk.
    @discardableResult
    private func _synchronizeUnsafe() -> Bool {
        guard canWrite else { return false }

        // Validate that all values are plist-serializable before writing
        guard PropertyListSerialization.propertyList(
            cache, isValidFor: .xml
        ) else {
            NSLog("[SharedPreferenceStore] Cache contains non-plist-serializable values — write skipped. " +
                  "Keys: %@", Array(cache.keys).joined(separator: ", "))
            return false
        }

        let success = (cache as NSDictionary).write(to: fileURL, atomically: true)
        if success {
            lastModificationDate = Self.modificationDate(of: fileURL)
        } else {
            NSLog("[SharedPreferenceStore] Failed to write preferences to %@", fileURL.path)
        }
        return success
    }

    /// Must be called within `queue.sync`.
    /// Extension mode (alwaysReload=true): re-reads from disk every time.
    /// Main app mode (alwaysReload=false): only re-reads if modification date changed.
    private func reloadIfNeeded() {
        if alwaysReload {
            reloadFromDisk()
            return
        }

        let currentMod = Self.modificationDate(of: fileURL)
        guard currentMod != lastModificationDate else { return }
        reloadFromDisk()
        lastModificationDate = currentMod
    }

    /// Must be called within `queue.sync`.
    private func reloadFromDisk() {
        if let dict = NSDictionary(contentsOf: fileURL) as? [String: Any] {
            cache = dict
        } else if FileManager.default.fileExists(atPath: fileURL.path) {
            // File exists but could not be parsed — likely corrupted
            NSLog("[SharedPreferenceStore] WARNING: plist at %@ exists but failed to parse — " +
                  "keeping cached values", fileURL.path)
        }
    }

    private static func modificationDate(of url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }
}
