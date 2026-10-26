import Foundation

@objc(FluxMarkdownSearchLaunchServing)
protocol SearchLaunchServing {
    func flushUsage(reply: @escaping (Bool) -> Void)
    func reportError(_ request: Data, reply: @escaping (Bool) -> Void)
    func openDocument(_ request: String, reply: @escaping (Bool) -> Void)
    func openGitHubRepository(reply: @escaping (Bool) -> Void)
    func openDocumentSearch(_ request: String, reply: @escaping (Bool) -> Void)
}

enum SearchLaunchPolicy {
    static let serviceName = "com.xykong.Markdown.SearchLauncher"
    static func request(_ value: String) -> DocumentOpenRequest? {
        guard value.utf8.count <= 8192, let url = URL(string: value), url.host == "open",
              let request = DocumentOpenRequest(url: url), request.wantsSearch else { return nil }
        let extensions: Set<String> = ["md", "markdown", "mdown", "mdx", "rmd", "qmd", "mdoc", "mdc", "mmd", "livemd", "mkd", "mkdn", "mkdown", "mdwn"]
        return extensions.contains(request.fileURL.pathExtension.lowercased()) ? request : nil
    }
    static func acceptsPeer(sameUser: Bool, validSignature: Bool, identifier: String,
                            expectedExecutable: Bool) -> Bool {
        sameUser && validSignature && identifier == "com.xykong.Markdown.QuickLook" && expectedExecutable
    }
}
