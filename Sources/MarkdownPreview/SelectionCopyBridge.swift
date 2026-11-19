import AppKit
import WebKit

/// Registered only by the Quick Look extension; app block-copy policy is unchanged.
final class SelectionCopyBridge {
    static let markdownExtensions: Set<String> = ["md", "mdx", "markdown", "mdown", "mkd", "mkdn", "mkdown", "mdwn", "rmd", "qmd", "mdoc", "mdc", "livemd"]
    private let clipboard = BlockCopyBridge()

    static func enabled(expanded: Bool, visible: Bool, fileExtension: String?) -> Bool {
        guard expanded, visible, let fileExtension else { return false }
        return markdownExtensions.contains(fileExtension.lowercased())
    }

    func handle(_ message: WKScriptMessage, generation: String, expanded: Bool, visible: Bool, fileExtension: String?) {
        clipboard.handle(message, generation: generation,
                         enabled: Self.enabled(expanded: expanded, visible: visible, fileExtension: fileExtension))
    }
}
