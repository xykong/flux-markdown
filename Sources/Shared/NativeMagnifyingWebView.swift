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
    private var gestureAnchor: CGPoint?
    private var readingGestureID = 0
    private var finishingGesture = false
    private var pinchSample = 0
    private var lastPinchDelta: CGFloat = 0
    private var syncingPinchResult = false
    private var wheelAccumulator: CGFloat = 0
    private var wheelBase: CGFloat = 1

    /// The reading column owns zoom; application chrome stays at 100%.
    var readingZoom: CGFloat = 1.0 {
        didSet {
            if syncingPinchResult { return }
            pinchSample += 1
            let value = min(3, max(0.5, readingZoom))
            guard readingZoom.isFinite else { readingZoom = oldValue; return }
            if value != readingZoom { readingZoom = value }
            let point = gestureAnchor.map { ", {x: \($0.x), y: \($0.y), gesture: \(readingGestureID), finished: \(finishingGesture)}" } ?? ""
            evaluateJavaScript("window.requestZoomLevel?.(\(value)\(point))", completionHandler: nil)
        }
    }

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        configureNativeMagnification()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureNativeMagnification()
    }

    static func targetMagnification(current: CGFloat, delta: CGFloat) -> CGFloat {
        min(3.0, max(0.5, current * (1.0 + delta)))
    }

    static func shouldRouteControlWheelAsScroll(_ modifierFlags: NSEvent.ModifierFlags) -> Bool {
        modifierFlags.contains(.control) && !modifierFlags.contains(.command)
    }

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            guard event.momentumPhase == [], event.phase != .cancelled, event.phase != .mayBegin else { return }
            if event.phase == .began || event.phase == [] {
                wheelAccumulator = 0
                wheelBase = readingZoom
            }
            wheelAccumulator += event.scrollingDeltaY
            readingZoom = min(3, max(0.5, wheelBase + wheelAccumulator * 0.01))
            AppearancePreference.shared.zoomLevel = readingZoom
            return
        }
        if Self.shouldRouteControlWheelAsScroll(event.modifierFlags) {
            let deltaX = event.scrollingDeltaX
            let deltaY = event.scrollingDeltaY
            evaluateJavaScript("window.scrollBy(\(deltaX), \(deltaY))", completionHandler: nil)
            return
        }
        super.scrollWheel(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags
        if (flags.contains(.command) || flags.contains(.control)), !flags.contains(.option) {
            switch event.charactersIgnoringModifiers {
            case "+", "=": readingZoom += 0.1
            case "-", "_": readingZoom -= 0.1
            case "0": readingZoom = 1
            default: return super.performKeyEquivalent(with: event)
            }
            AppearancePreference.shared.zoomLevel = readingZoom
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func smartMagnify(with event: NSEvent) {
        readingZoom = 1
        AppearancePreference.shared.zoomLevel = 1
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
            magnificationBase = readingZoom
            readingGestureID += 1
            finishingGesture = false
            let location = recognizer.location(in: self)
            gestureAnchor = CGPoint(x: location.x, y: isFlipped ? location.y : bounds.height - location.y)
            applyMagnification(from: recognizer)
        case .changed:
            applyMagnification(from: recognizer)
        case .ended:
            finishingGesture = true
            applyMagnification(from: recognizer)
            gestureAnchor = nil
        case .cancelled:
            finishingGesture = true
            applyPinch(delta: lastPinchDelta)
            gestureAnchor = nil
        default:
            break
        }
    }

    private func applyMagnification(from recognizer: NSMagnificationGestureRecognizer) {
        lastPinchDelta = recognizer.magnification
        applyPinch(delta: lastPinchDelta)
    }

    private func applyPinch(delta: CGFloat) {
        guard let point = gestureAnchor, delta.isFinite else { return }
        pinchSample += 1
        let sample = pinchSample
        let finished = finishingGesture
        let script = "window.requestPinchZoom?.(\(magnificationBase), \(delta), {x: \(point.x), y: \(point.y), gesture: \(readingGestureID), finished: \(finished)})"
        evaluateJavaScript(script) { [weak self] result, _ in
            guard let self, self.pinchSample == sample, let level = result as? NSNumber else { return }
            self.syncingPinchResult = true
            self.readingZoom = min(3, max(0.5, CGFloat(level.doubleValue)))
            self.syncingPinchResult = false
            if finished { AppearancePreference.shared.zoomLevel = self.readingZoom }
        }
    }
}
