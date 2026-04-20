import Foundation

struct EditorLayoutConfig {
    let viewMode: EditorViewMode

    var showsEditorPane: Bool { viewMode.showsEditor }
    var showsPreviewPane: Bool { viewMode.showsPreview }

    var editorWidthFraction: Double {
        switch viewMode {
        case .split:       return 0.5
        case .editorOnly:  return 1.0
        case .previewOnly: return 0.0
        }
    }

    var minWindowWidth: CGFloat {
        switch viewMode {
        case .split:       return 640
        case .editorOnly:  return 320
        case .previewOnly: return 320
        }
    }
}

struct EditorToolbarState {
    var viewMode: EditorViewMode

    init(viewMode: EditorViewMode = .split) {
        self.viewMode = viewMode
    }

    var toggleButtonSymbol: String { viewMode.symbolName }
    var toggleButtonLabel: String  { viewMode.displayName }
    var isEditing: Bool            { viewMode.showsEditor }

    mutating func cycleViewMode() {
        viewMode.cycle()
    }
}
