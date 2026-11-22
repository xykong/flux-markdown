import AppKit

/// Quick Look sets its own appearance on the preview's root view, for example dark in full
/// screen. Toolbar buttons and notices then draw for a dark window over a light page and vanish.
/// The root view keeps the appearance of the theme the person chose.
final class AppearanceKeepingView: NSView {
    var selectedAppearance: NSAppearance?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        guard needsSelectedAppearance else { return }
        // Not during AppKit's own appearance update.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.needsSelectedAppearance else { return }
            self.appearance = self.selectedAppearance
        }
    }

    private var needsSelectedAppearance: Bool {
        guard let selected = selectedAppearance else { return false }
        return appearance?.name != selected.name
    }
}
