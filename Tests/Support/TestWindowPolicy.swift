import CoreGraphics

/// Local visible probes stay on a secondary screen and never activate by default.
/// Foreground modes require an explicit runner setting; ci-foreground is for CI only.
enum TestWindowPolicy: String {
    case secondaryBackground = "secondary-background"
    case secondaryForeground = "secondary-foreground"
    case ciForeground = "ci-foreground"

    init?(environment: [String: String]) {
        self.init(rawValue: environment["FLUX_TEST_WINDOW_POLICY"] ?? "secondary-background")
    }

    var allowsFocus: Bool { self != .secondaryBackground }

    /// NSScreen.screens starts with the menu-bar screen, not necessarily the key window's screen.
    func frame(size: CGSize, screens: [CGRect]) -> CGRect? {
        let candidates: [CGRect] = self == .ciForeground ? Array(screens.prefix(1)) : Array(screens.dropFirst())
        for screen in candidates where screen.width >= size.width && screen.height >= size.height {
            return CGRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2,
                          width: size.width, height: size.height)
        }
        return nil
    }
}
