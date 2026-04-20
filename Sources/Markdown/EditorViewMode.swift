import Foundation

enum EditorViewMode: CaseIterable, Equatable {
    case editorOnly
    case previewOnly
    case split

    static let defaultMode: EditorViewMode = .split

    var displayName: String {
        switch self {
        case .editorOnly:  return "Editor"
        case .previewOnly: return "Preview"
        case .split:       return "Split"
        }
    }

    var symbolName: String {
        switch self {
        case .editorOnly:  return "pencil"
        case .previewOnly: return "eye"
        case .split:       return "rectangle.split.2x1"
        }
    }

    var showsEditor: Bool {
        self == .editorOnly || self == .split
    }

    var showsPreview: Bool {
        self == .previewOnly || self == .split
    }

    mutating func cycle() {
        switch self {
        case .split:       self = .editorOnly
        case .editorOnly:  self = .previewOnly
        case .previewOnly: self = .split
        }
    }
}

struct MarkdownEditorState {
    var text: String
    var viewMode: EditorViewMode = .split
    var isEdited: Bool = false

    init(text: String) {
        self.text = text
    }

    mutating func cycleViewMode() {
        viewMode.cycle()
    }

    mutating func markEdited() {
        isEdited = true
    }
}
