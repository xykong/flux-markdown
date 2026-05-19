import SwiftUI
import AppKit

struct WindowAccessor: NSViewRepresentable {
    static let minimumRestorableWindowSize = CGSize(width: 320, height: 200)

    static func isFrameValidForRestore(_ frame: CGRect) -> Bool {
        guard !frame.isNull, !frame.isInfinite else { return false }

        return frame.origin.x.isFinite &&
            frame.origin.y.isFinite &&
            frame.width.isFinite &&
            frame.height.isFinite &&
            frame.width >= minimumRestorableWindowSize.width &&
            frame.height >= minimumRestorableWindowSize.height
    }

    static func isFrameRestorable(_ frame: CGRect, visibleFrames: [CGRect]) -> Bool {
        guard isFrameValidForRestore(frame) else { return false }
        guard !visibleFrames.isEmpty else { return true }

        return visibleFrames.contains { visibleFrame in
            frame.intersection(visibleFrame).width >= minimumRestorableWindowSize.width &&
                frame.intersection(visibleFrame).height >= minimumRestorableWindowSize.height
        }
    }

    static func defaultDocumentFrame(currentFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        let targetWidth = min(max(currentFrame.width, minimumRestorableWindowSize.width), visibleFrame.width)
        let targetHeight = max(minimumRestorableWindowSize.height, visibleFrame.height * 0.80)
        let x = visibleFrame.midX - (targetWidth / 2)
        let y = visibleFrame.minY + (visibleFrame.height * 0.05)

        return CGRect(x: x, y: y, width: targetWidth, height: targetHeight)
    }

    func makeNSView(context: Context) -> WindowObservingView {
        let view = WindowObservingView()
        view.onWindowAttach = { window in
            window.minSize = Self.minimumRestorableWindowSize

            if let savedFrame = AppearancePreference.shared.hostWindowFrame {
                if Self.isFrameRestorable(savedFrame, visibleFrames: Self.currentVisibleFrames()) {
                    window.setFrame(savedFrame, display: true)
                } else {
                    AppearancePreference.shared.hostWindowFrame = nil
                    Self.applyDefaultFrame(to: window)
                }
            } else {
                Self.applyDefaultFrame(to: window)
            }
            // Start observing changes
            context.coordinator.monitor(window: window)
        }
        return view
    }
    
    func updateNSView(_ nsView: WindowObservingView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private static func applyDefaultFrame(to window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }

        let frame = defaultDocumentFrame(
            currentFrame: window.frame,
            visibleFrame: screen.visibleFrame
        )

        window.setFrame(frame, display: true)
    }

    private static func currentVisibleFrames() -> [CGRect] {
        NSScreen.screens.map(\.visibleFrame)
    }
    
    /// Custom NSView that reliably detects when it's added to a window.
    class WindowObservingView: NSView {
        var onWindowAttach: ((NSWindow) -> Void)?
        private var didAttach = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard !didAttach, let window = self.window else { return }
            didAttach = true
            onWindowAttach?(window)
        }
    }
    
    class Coordinator: NSObject {
        var window: NSWindow?
        var observers: [NSObjectProtocol] = []
        
        deinit {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
        }
        
        func monitor(window: NSWindow) {
            self.window = window
            
            // Clean up old observers
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            observers.removeAll()
            
            let center = NotificationCenter.default
            
            observers.append(center.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.saveFrame() }
            })

            observers.append(center.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.saveFrame() }
            })
        }
        
        @MainActor
        private func saveFrame() {
            guard let window = window else { return }
            guard WindowAccessor.isFrameValidForRestore(window.frame) else { return }
            AppearancePreference.shared.hostWindowFrame = window.frame
        }
    }
}
