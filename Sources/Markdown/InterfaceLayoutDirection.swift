import SwiftUI

/// Resolves the layout direction for the in-app language picker.
///
/// AppKit and SwiftUI resolve `AppleLanguages` once at launch, so a language
/// change made from Settings would otherwise leave the current windows in the
/// previous direction until the app restarts. Explicit overrides keep SwiftUI
/// content mirrored immediately; `.system` keeps the OS-resolved direction.
enum InterfaceLayoutDirection {
    static func override(for preference: String) -> LayoutDirection? {
        switch preference {
        case "ar": return .rightToLeft
        case "system": return nil
        default: return .leftToRight
        }
    }
}

extension View {
    @ViewBuilder
    func interfaceLayoutDirection(for preference: String) -> some View {
        if let direction = InterfaceLayoutDirection.override(for: preference) {
            environment(\.layoutDirection, direction)
        } else {
            self
        }
    }
}
