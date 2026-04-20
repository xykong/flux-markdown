import Foundation

struct MarkdownEditorTextModel {
    var text: String

    init(text: String) {
        self.text = text
    }

    var lineCount: Int {
        text.isEmpty ? 1 : text.components(separatedBy: "\n").count
    }

    var wordCount: Int {
        let stripped = text
            .replacingOccurrences(of: #"[#*_`\[\]()>!]+"#, with: " ", options: .regularExpression)
        let words = stripped.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return words.count
    }

    var charCount: Int {
        text.count
    }

    var statusText: String {
        "\(lineCount) lines · \(wordCount) words · \(charCount) chars"
    }
}
