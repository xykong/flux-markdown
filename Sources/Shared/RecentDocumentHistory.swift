import Foundation
import Combine

/// Host-only history, independent of LaunchServices' code-signing requirement.
/// An explicitly empty array is a tombstone: never migrate old system entries again.
final class RecentDocumentHistory: ObservableObject {
    static let shared = RecentDocumentHistory()
    private let defaults: UserDefaults
    private let limit: Int
    private let key = "FluxRecentDocumentPaths.v1"

    init(defaults: UserDefaults = .standard, limit: Int = 20) {
        self.defaults = defaults
        self.limit = max(1, limit)
    }

    var urls: [URL] {
        (defaults.stringArray(forKey: key) ?? []).map { URL(fileURLWithPath: $0) }
    }

    func migrate(_ systemURLs: [URL]) {
        guard defaults.object(forKey: key) == nil else { return }
        save(systemURLs)
    }

    func record(_ url: URL) {
        guard url.isFileURL else { return }
        save([url] + urls)
    }

    func clear() { objectWillChange.send(); defaults.set([String](), forKey: key) }

    private func save(_ urls: [URL]) {
        var seen = Set<String>()
        let paths = urls.filter(\.isFileURL).map { $0.standardizedFileURL.path }
            .filter { seen.insert($0).inserted }
        objectWillChange.send()
        defaults.set(Array(paths.prefix(limit)), forKey: key)
    }
}
