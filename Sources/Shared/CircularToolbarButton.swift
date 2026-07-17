import AppKit
import SwiftUI

final class CircularToolbarButton: NSButton, NSViewToolTipOwner {
    static let diameter: CGFloat = 30
    private var currentToolTipText: String?
    private var toolTipTag: NSView.ToolTipTag?

    override var intrinsicContentSize: NSSize {
        NSSize(width: 30, height: 30)
    }

    static func make(
        systemName: String,
        accessibilityDescription: String,
        tintColor: NSColor,
        target: AnyObject,
        action: Selector,
        toolTip: String? = nil,
        appearance: NSAppearance? = nil
    ) -> CircularToolbarButton {
        let button = CircularToolbarButton(frame: NSRect(x: 0, y: 0, width: diameter, height: diameter))
        button.appearance = appearance
        button.configure(
            systemName: systemName,
            accessibilityDescription: accessibilityDescription,
            tintColor: tintColor,
            toolTip: toolTip
        )
        button.target = target
        button.action = action
        return button
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureNativeCircle()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureNativeCircle()
    }

    func configure(
        systemName: String,
        accessibilityDescription: String,
        tintColor: NSColor,
        toolTip: String? = nil
    ) {
        image = NSImage(systemSymbolName: systemName, accessibilityDescription: accessibilityDescription)
        contentTintColor = tintColor
        let text = toolTip ?? accessibilityDescription
        currentToolTipText = text
        self.toolTip = nil
        setAccessibilityLabel(text)
        updateToolTipRect()
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        updateToolTipRect()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateToolTipRect()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = superview.map { convert(point, from: $0) } ?? point
        return bounds.contains(localPoint) ? self : nil
    }

    @objc func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String {
        currentToolTipText ?? ""
    }

    private func configureNativeCircle() {
        translatesAutoresizingMaskIntoConstraints = false
        setButtonType(.momentaryPushIn)
        bezelStyle = .circular
        isBordered = true
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyDown
        focusRingType = .none
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    private func updateToolTipRect() {
        if let toolTipTag {
            removeToolTip(toolTipTag)
            self.toolTipTag = nil
        }

        guard currentToolTipText?.isEmpty == false, !bounds.isEmpty else { return }
        toolTipTag = addToolTip(bounds, owner: self, userData: nil)
    }
}

struct CircularToolbarIconButton: NSViewRepresentable {
    let systemName: String
    let foregroundColor: Color
    let helpText: String
    let appearance: NSAppearance?
    let action: () -> Void

    init(
        systemName: String,
        foregroundColor: Color,
        helpText: String,
        appearance: NSAppearance? = nil,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.foregroundColor = foregroundColor
        self.helpText = helpText
        self.appearance = appearance
        self.action = action
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> CircularToolbarButton {
        CircularToolbarButton.make(
            systemName: systemName,
            accessibilityDescription: helpText,
            tintColor: NSColor(foregroundColor),
            target: context.coordinator,
            action: #selector(Coordinator.performAction),
            toolTip: helpText,
            appearance: appearance
        )
    }

    func updateNSView(_ button: CircularToolbarButton, context: Context) {
        context.coordinator.action = action
        button.appearance = appearance
        button.configure(
            systemName: systemName,
            accessibilityDescription: helpText,
            tintColor: NSColor(foregroundColor),
            toolTip: helpText
        )
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func performAction() {
            action()
        }
    }
}
