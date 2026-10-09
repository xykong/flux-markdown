import Foundation

/// Identifies this build as the unofficial xluffy fork or as the upstream app.
///
/// The fork adds a suffix to the display version, for example
/// `1.34.495-xluffy.1`. The About screen and the version label use this value
/// to tell the user which build is running.
enum AppIdentity {
    static let appName = "FluxMarkdown"
    static let forkOwner = "xluffy"
    static let forkRepositoryURL = URL(string: "https://github.com/xluffy-fork/flux-markdown")!
    static let upstreamRepositoryURL = URL(string: "https://github.com/xykong/flux-markdown")!

    /// Returns `true` when the display version carries the fork suffix.
    static func isFork(displayVersion: String?) -> Bool {
        guard let displayVersion = displayVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
              !displayVersion.isEmpty else {
            return false
        }
        return displayVersion.localizedCaseInsensitiveContains("-\(forkOwner)")
    }

    /// A short label for the About screen.
    static func editionLabel(displayVersion: String?) -> String {
        isFork(displayVersion: displayVersion) ? "Unofficial \(forkOwner) fork" : "Upstream release"
    }

    /// A sentence that tells the user which build is running.
    static func summary(displayVersion: String?) -> String {
        if isFork(displayVersion: displayVersion) {
            return "This build is the unofficial \(forkOwner) fork. It is not the upstream release."
        }
        return "This build is the upstream release. It is not the \(forkOwner) fork."
    }
}
