import Foundation

enum QuickLookProbeEvidence {
    static let heading = "FluxMarkdown Quick Look Test"
    static let boldText = "Rendered Markdown"
    static let fixture = "# \(heading)\n\n**\(boldText)** confirms the extension was selected.\n\nThis temporary document contains no personal data.\n"
    static let prefix = "flux-quicklook-probe-"
    static func token(for url: URL) -> String? {
        guard url.pathExtension == "md" else { return nil }
        let name = url.deletingPathExtension().lastPathComponent
        guard name.hasPrefix(prefix), let id = UUID(uuidString: String(name.dropFirst(prefix.count))) else { return nil }
        return id.uuidString
    }
    static func marker(token: String, version: String, build: String, stage: String) -> String {
        "FluxQuickLookProbe token=\(token) version=\(version) build=\(build) stage=\(stage)"
    }
    static func rendered(in json: String, token: String, version: String, build: String, executableURL: URL) -> Bool {
        guard executableURL.isFileURL, executableURL.path.hasPrefix("/"),
              !version.isEmpty, version != "unknown", !build.isEmpty, build != "unknown",
              let data = json.data(using: .utf8),
              let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return false }
        let expected = marker(token: token, version: version, build: build, stage: "rendered")
        let expectedPath = executableURL.resolvingSymlinksInPath().standardizedFileURL.path
        return entries.contains { entry in
            guard let path = entry["processImagePath"] as? String, path.hasPrefix("/") else { return false }
            return entry["eventMessage"] as? String == expected &&
            entry["subsystem"] as? String == "com.markdownquicklook.app" &&
            URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path == expectedPath
        }
    }
}
