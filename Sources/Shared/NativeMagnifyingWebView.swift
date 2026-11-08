import AppKit
import WebKit

class NativeMagnifyingWebView: WKWebView {
    override func accessibilityChildren() -> [Any]? {
        var children = super.accessibilityChildren() ?? []
        // WebKit normally exposes its remote document tree, omitting native overlays.
        for notice in subviews.compactMap({ $0 as? IncidentNotice }) where !notice.isHidden {
            if !children.contains(where: { ($0 as? NSView) === notice }) { children.append(notice) }
        }
        return children
    }

    private var magnificationGestureRecognizer: NSMagnificationGestureRecognizer?
    private var magnificationBase: CGFloat = 1.0

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        configureNativeMagnification()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureNativeMagnification()
    }

    static func targetMagnification(current: CGFloat, delta: CGFloat) -> CGFloat {
        min(5.0, max(0.25, current * (1.0 + delta)))
    }

    static func shouldRouteControlWheelAsScroll(_ modifierFlags: NSEvent.ModifierFlags) -> Bool {
        modifierFlags.contains(.control) && !modifierFlags.contains(.command)
    }

    override func scrollWheel(with event: NSEvent) {
        if Self.shouldRouteControlWheelAsScroll(event.modifierFlags) {
            let deltaX = event.scrollingDeltaX
            let deltaY = event.scrollingDeltaY
            evaluateJavaScript("window.scrollBy(\(deltaX), \(deltaY))", completionHandler: nil)
            return
        }
        super.scrollWheel(with: event)
    }

    override func smartMagnify(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            self.animator().magnification = 1.0
        }
    }

    private func configureNativeMagnification() {
        allowsMagnification = false

        let recognizer = NSMagnificationGestureRecognizer(
            target: self,
            action: #selector(handleNativeMagnification(_:))
        )
        recognizer.delaysMagnificationEvents = false
        addGestureRecognizer(recognizer)
        magnificationGestureRecognizer = recognizer
    }

    @objc private func handleNativeMagnification(_ recognizer: NSMagnificationGestureRecognizer) {
        switch recognizer.state {
        case .began:
            magnificationBase = magnification
            applyMagnification(from: recognizer)
        case .changed, .ended:
            applyMagnification(from: recognizer)
        default:
            break
        }
    }

    private func applyMagnification(from recognizer: NSMagnificationGestureRecognizer) {
        let target = Self.targetMagnification(
            current: magnificationBase,
            delta: recognizer.magnification
        )
        setMagnification(target, centeredAt: recognizer.location(in: self))
    }
}
