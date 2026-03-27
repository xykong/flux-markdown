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
/// See: https://github.com/xykong/flux-markdown/issues/13
public class SharedPreferenceStore {

    private static let relativePath = "Library/Application Support/FluxMarkdown/shared-preferences.plist"

    private var cache: [String: Any]
    private let fileURL: URL
    private let canWrite: Bool
    private var lastModificationDate: Date?

    /// Creates a store backed by the default shared plist location.
    public convenience init() {
        let url = Self.defaultFileURL()
        self.init(fileURL: url)
    }

    /// Creates a store backed by a specific file URL (for testing).
    public init(fileURL: URL) {
        self.fileURL = fileURL

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

    // MARK: - Reading

    public func string(forKey key: String) -> String? {
        reloadIfNeeded()
        return cache[key] as? String
    }

    public func double(forKey key: String) -> Double {
        reloadIfNeeded()
        return cache[key] as? Double ?? 0
    }

    public func bool(forKey key: String) -> Bool {
        reloadIfNeeded()
        return cache[key] as? Bool ?? false
    }

    public func object(forKey key: String) -> Any? {
        reloadIfNeeded()
        return cache[key]
    }

    public func dictionary(forKey key: String) -> [String: Any]? {
        reloadIfNeeded()
        return cache[key] as? [String: Any]
    }

    public func array(forKey key: String) -> [Any]? {
        reloadIfNeeded()
        return cache[key] as? [Any]
    }

    // MARK: - Writing (updates in-memory cache; persists to disk only if writable)

    public func set(_ value: Any?, forKey key: String) {
        if let v = value {
            cache[key] = v
        } else {
            cache.removeValue(forKey: key)
        }
    }

    public func set(_ value: Bool, forKey key: String) {
        cache[key] = value
    }

    public func set(_ value: Double, forKey key: String) {
        cache[key] = value
    }

    public func removeObject(forKey key: String) {
        cache.removeValue(forKey: key)
    }

    /// Flush in-memory cache to disk. No-op for the sandboxed extension.
    @discardableResult
    public func synchronize() -> Bool {
        guard canWrite else { return false }
        let success = (cache as NSDictionary).write(to: fileURL, atomically: true)
        if success {
            lastModificationDate = Self.modificationDate(of: fileURL)
        } else {
            NSLog("[SharedPreferenceStore] Failed to write preferences to %@", fileURL.path)
        }
        return success
    }

    // MARK: - Private

    /// Resolves the real user home directory via the password database,
    /// bypassing sandbox container redirection. This ensures the main app
    /// and sandboxed QuickLook extension both resolve to the same absolute path.
    private static func realHomeDirectory() -> URL {
        if let pw = getpwuid(getuid()), let home = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: home))
        }
        // Fallback — unlikely to be reached, but avoids a crash
        return FileManager.default.homeDirectoryForCurrentUser
    }

    private static func defaultFileURL() -> URL {
        return realHomeDirectory().appendingPathComponent(relativePath)
    }

    /// Only re-reads from disk if the file's modification date has changed,
    /// avoiding unnecessary I/O on every property access.
    private func reloadIfNeeded() {
        let currentMod = Self.modificationDate(of: fileURL)
        guard currentMod != lastModificationDate else { return }
        if let dict = NSDictionary(contentsOf: fileURL) as? [String: Any] {
            cache = dict
        }
        lastModificationDate = currentMod
    }

    private static func modificationDate(of url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }
}
