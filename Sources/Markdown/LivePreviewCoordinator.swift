import Foundation

struct LivePreviewCoordinator {
    private(set) var previewContent: String
    private(set) var needsRender: Bool = false

    init(initialText: String) {
        self.previewContent = initialText
    }

    mutating func updateText(_ newText: String) {
        guard newText != previewContent else { return }
        previewContent = newText
        needsRender = true
    }

    mutating func acknowledgeRender() {
        needsRender = false
    }
}
