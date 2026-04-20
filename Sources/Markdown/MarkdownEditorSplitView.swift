import SwiftUI

struct MarkdownEditorSplitView: View {
    @Binding var text: String
    var fileURL: URL?
    var appearanceMode: AppearanceMode
    var baseFontSize: Double
    var enableMermaid: Bool
    var enableKatex: Bool
    var enableEmoji: Bool
    var codeHighlightTheme: String
    var collapseBlockquotesByDefault: Bool

    @State private var editorViewMode: EditorViewMode = .split
    @State private var liveCoord: LivePreviewCoordinator

    init(
        text: Binding<String>,
        fileURL: URL?,
        appearanceMode: AppearanceMode,
        baseFontSize: Double,
        enableMermaid: Bool,
        enableKatex: Bool,
        enableEmoji: Bool,
        codeHighlightTheme: String,
        collapseBlockquotesByDefault: Bool
    ) {
        self._text = text
        self.fileURL = fileURL
        self.appearanceMode = appearanceMode
        self.baseFontSize = baseFontSize
        self.enableMermaid = enableMermaid
        self.enableKatex = enableKatex
        self.enableEmoji = enableEmoji
        self.codeHighlightTheme = codeHighlightTheme
        self.collapseBlockquotesByDefault = collapseBlockquotesByDefault
        self._liveCoord = State(initialValue: LivePreviewCoordinator(initialText: text.wrappedValue))
    }

    var body: some View {
        let layout = EditorLayoutConfig(viewMode: editorViewMode)
        let toolbar = EditorToolbarState(viewMode: editorViewMode)
        let textModel = MarkdownEditorTextModel(text: text)

        return VStack(spacing: 0) {
            editorToolbar(toolbar: toolbar, textModel: textModel)
            Divider()
            contentArea(layout: layout)
        }
        .frame(minWidth: layout.minWindowWidth)
        .onReceive(NotificationCenter.default.publisher(for: .toggleEditorLayout)) { _ in
            editorViewMode.cycle()
        }
    }

    @ViewBuilder
    private func editorToolbar(toolbar: EditorToolbarState, textModel: MarkdownEditorTextModel) -> some View {
        HStack(spacing: 8) {
            Button(action: { editorViewMode.cycle() }) {
                HStack(spacing: 4) {
                    Image(systemName: toolbar.toggleButtonSymbol)
                    Text(toolbar.toggleButtonLabel)
                }
            }
            .help("Toggle editor layout (\(EditorViewMode.editorOnly.displayName) / \(EditorViewMode.previewOnly.displayName) / \(EditorViewMode.split.displayName))")
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Spacer()

            Text(textModel.statusText)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
    }

    @ViewBuilder
    private func contentArea(layout: EditorLayoutConfig) -> some View {
        HStack(spacing: 0) {
            if layout.showsEditorPane {
                MarkdownEditorView(
                    text: $text,
                    font: .monospacedSystemFont(ofSize: CGFloat(baseFontSize * 0.875), weight: .regular),
                    onTextChange: { newText in
                        liveCoord.updateText(newText)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if layout.showsPreviewPane {
                    Divider()
                }
            }

            if layout.showsPreviewPane {
                MarkdownWebView(
                    content: liveCoord.previewContent,
                    fileURL: fileURL,
                    appearanceMode: appearanceMode,
                    viewMode: .preview,
                    baseFontSize: baseFontSize,
                    enableMermaid: enableMermaid,
                    enableKatex: enableKatex,
                    enableEmoji: enableEmoji,
                    codeHighlightTheme: codeHighlightTheme,
                    collapseBlockquotesByDefault: collapseBlockquotesByDefault
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
