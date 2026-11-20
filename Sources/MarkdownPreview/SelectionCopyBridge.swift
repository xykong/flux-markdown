import AppKit
import WebKit

/// Registered only by the Quick Look extension; app block-copy policy is unchanged.
enum SelectionCopyBridge {
    static let markdownExtensions: Set<String> = ["md", "mdx", "markdown", "mdown", "mkd", "mkdn", "mkdown", "mdwn", "rmd", "qmd", "mdoc", "mdc", "livemd"]

    static func enabled(expanded: Bool, visible: Bool, fileExtension: String?) -> Bool {
        guard expanded, visible, let fileExtension else { return false }
        return markdownExtensions.contains(fileExtension.lowercased())
    }
}
