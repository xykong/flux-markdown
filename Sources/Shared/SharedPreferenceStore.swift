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
/// See: https://github.com/xykong/flux-markdown/issues/13
public class SharedPreferenceStore {

    private static let directoryName = "FluxMarkdown"
    private static let fileName = "shared-preferences.plist"

    private var cache: [String: Any]
    private let fileURL: URL
    private let canWrite: Bool

    public init() {
        // Resolve ~/Library/Application Support/FluxMarkdown/shared-preferences.plist
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent(Self.directoryName)
        self.fileURL = dir.appendingPathComponent(Self.fileName)

        // Attempt to create the directory.
        // Succeeds for the unsandboxed main app; fails (harmlessly) for the sandboxed extension.
        var writable = false
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            writable = true
        } catch {
            writable = false
        }
        self.canWrite = writable

        // Load existing preferences from file
        if let dict = NSDictionary(contentsOf: fileURL) as? [String: Any] {
            self.cache = dict
        } else {
            self.cache = [:]
        }
    }

    // MARK: - Reading (re-reads from disk each time to pick up cross-process changes)

    public func string(forKey key: String) -> String? {
        reloadFromDisk()
        return cache[key] as? String
    }

    public func double(forKey key: String) -> Double {
        reloadFromDisk()
        return cache[key] as? Double ?? 0
    }

    public func bool(forKey key: String) -> Bool {
        reloadFromDisk()
        return cache[key] as? Bool ?? false
    }

    public func object(forKey key: String) -> Any? {
        reloadFromDisk()
        return cache[key]
    }

    public func dictionary(forKey key: String) -> [String: Any]? {
        reloadFromDisk()
        return cache[key] as? [String: Any]
    }

    public func array(forKey key: String) -> [Any]? {
        reloadFromDisk()
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
    public func synchronize() {
        guard canWrite else { return }
        (cache as NSDictionary).write(to: fileURL, atomically: true)
    }

    // MARK: - Private

    private func reloadFromDisk() {
        if let dict = NSDictionary(contentsOf: fileURL) as? [String: Any] {
            cache = dict
        }
    }
}
