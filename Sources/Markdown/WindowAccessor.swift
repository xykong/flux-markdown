import SwiftUI
import AppKit
import os.log

struct WindowAccessor: NSViewRepresentable {
    static let minimumRestorableWindowSize = CGSize(width: 320, height: 200)
    private static let initialFrameReapplyDelays: [TimeInterval] = [0.20, 0.80]
    private static let logger = OSLog(subsystem: "com.markdownquicklook.app", category: "WindowAccessor")

    struct FrameApplication: Equatable {
        let delay: TimeInterval
        let frame: CGRect
    }

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
            let intersection = frame.intersection(visibleFrame)
            guard !intersection.isNull else { return false }

            return intersection.width >= minimumRestorableWindowSize.width &&
                intersection.height >= minimumRestorableWindowSize.height
        }
    }

    static func defaultDocumentFrame(currentFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        let targetWidth = min(max(currentFrame.width, minimumRestorableWindowSize.width), visibleFrame.width)
        let targetHeight = max(minimumRestorableWindowSize.height, visibleFrame.height * 0.80)
        let x = visibleFrame.midX - (targetWidth / 2)
        let y = visibleFrame.minY + (visibleFrame.height * 0.05)

        return CGRect(x: x, y: y, width: targetWidth, height: targetHeight)
    }

    static func defaultFrameApplications(currentFrame: CGRect, targetFrame: CGRect, visibleFrame: CGRect) -> [FrameApplication] {
        frameApplications(
            currentFrame: currentFrame,
            targetFrame: targetFrame,
            visibleFrames: [visibleFrame]
        )
    }

    static func initialDocumentContentSize(savedFrame: CGRect?, visibleFrames: [CGRect] = currentVisibleFrames()) -> CGSize {
        guard let savedFrame, isFrameRestorable(savedFrame, visibleFrames: visibleFrames) else {
            return CGSize(width: 1_000, height: 800)
        }

        return contentSize(forWindowFrame: savedFrame)
    }

    static func contentSize(forWindowFrame frame: CGRect) -> CGSize {
        let contentRect = NSWindow.contentRect(
            forFrameRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable]
        )

        return contentRect.size
    }

    static func isInFullScreenContext(
        styleMask: NSWindow.StyleMask,
        tabbedWindowStyleMasks: [NSWindow.StyleMask]
    ) -> Bool {
        styleMask.contains(.fullScreen) ||
            tabbedWindowStyleMasks.contains { $0.contains(.fullScreen) }
    }

    private static func isInFullScreenContext(_ window: NSWindow) -> Bool {
        isInFullScreenContext(
            styleMask: window.styleMask,
            tabbedWindowStyleMasks: window.tabbedWindows?.map(\.styleMask) ?? []
        )
    }

    private static func frameApplications(currentFrame: CGRect, targetFrame: CGRect, visibleFrames: [CGRect]) -> [FrameApplication] {
        guard isFrameRestorable(targetFrame, visibleFrames: visibleFrames) else { return [] }

        let immediateApplication = FrameApplication(delay: 0, frame: targetFrame)
        guard !framesApproximatelyEqual(currentFrame, targetFrame) else {
            return [immediateApplication]
        }

        return [
            immediateApplication
        ] + initialFrameReapplyDelays.map {
            FrameApplication(delay: $0, frame: targetFrame)
        }
    }

    func makeNSView(context: Context) -> WindowObservingView {
        let view = WindowObservingView()
        view.onWindowAttach = { window in
            window.minSize = Self.minimumRestorableWindowSize

            let startupPhase: Coordinator.StartupPhase
            if Self.isInFullScreenContext(window) {
                startupPhase = .applyingDefault
                os_log("Skipping startup frame restore in full-screen context", log: Self.logger, type: .debug)
            } else if let savedFrame = AppearancePreference.shared.hostWindowFrame {
                let visibleFrames = Self.currentVisibleFrames()
                if Self.isFrameRestorable(savedFrame, visibleFrames: visibleFrames) {
                    startupPhase = .restoring(targetFrame: savedFrame)
                    Self.applyFrameApplications(to: window, targetFrame: savedFrame, visibleFrames: visibleFrames)
                } else {
                    AppearancePreference.shared.hostWindowFrame = nil
                    startupPhase = .applyingDefault
                    Self.applyDefaultFrame(to: window)
                }
            } else {
                startupPhase = .applyingDefault
                Self.applyDefaultFrame(to: window)
            }
            // Start observing changes
            context.coordinator.monitor(window: window, startupPhase: startupPhase)
        }
        return view
    }
    
    func updateNSView(_ nsView: WindowObservingView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private static func applyDefaultFrame(to window: NSWindow) {
        guard !isInFullScreenContext(window) else { return }
        guard let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }

        let frame = defaultDocumentFrame(
            currentFrame: window.frame,
            visibleFrame: screen.visibleFrame
        )

        applyFrameApplications(to: window, targetFrame: frame, visibleFrames: [screen.visibleFrame])
    }

    static func applyFrameApplications(
        to window: NSWindow,
        targetFrame: CGRect,
        visibleFrames: [CGRect],
        fullScreenContextProvider: ((NSWindow) -> Bool)? = nil
    ) {
        let isFullScreen = fullScreenContextProvider ?? isInFullScreenContext
        guard !isFullScreen(window) else { return }

        let applications = frameApplications(
            currentFrame: window.frame,
            targetFrame: targetFrame,
            visibleFrames: visibleFrames
        )

        for application in applications {
            if application.delay == 0 {
                applyFrame(application.frame, to: window)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + application.delay) { [weak window] in
                    guard let window else { return }
                    guard !window.inLiveResize else { return }
                    guard !isFullScreen(window) else {
                        os_log("Cancelled delayed frame restore after window entered full-screen context", log: logger, type: .debug)
                        return
                    }
                    guard !framesApproximatelyEqual(window.frame, application.frame) else { return }
                    applyFrame(application.frame, to: window)
                }
            }
        }
    }

    private static func applyFrame(_ frame: CGRect, to window: NSWindow) {
        guard !isInFullScreenContext(window) else { return }
        guard !framesApproximatelyEqual(window.frame, frame) else { return }
        window.setFrame(frame, display: true)
    }

    static func shouldSaveFrame(for window: NSWindow, isFullScreenTransitionInProgress: Bool = false) -> Bool {
        guard !isFullScreenTransitionInProgress, !isInFullScreenContext(window) else { return false }
        return window.title.hasSuffix(".md") || window.representedURL != nil
    }

    private static func framesApproximatelyEqual(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) < 0.5 &&
            abs(lhs.origin.y - rhs.origin.y) < 0.5 &&
            abs(lhs.width - rhs.width) < 0.5 &&
            abs(lhs.height - rhs.height) < 0.5
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
        enum StartupPhase {
            case restoring(targetFrame: CGRect)
            case applyingDefault
            case settled
        }

        var window: NSWindow?
        var observers: [NSObjectProtocol] = []
        private var startupPhase: StartupPhase = .settled
        private var isFullScreenTransitionInProgress = false
        
        deinit {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
        }
        
        func monitor(window: NSWindow, startupPhase: StartupPhase) {
            self.window = window
            self.startupPhase = startupPhase
            
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

            observers.append(center.addObserver(forName: NSWindow.willEnterFullScreenNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.isFullScreenTransitionInProgress = true }
            })

            observers.append(center.addObserver(forName: NSWindow.didEnterFullScreenNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.isFullScreenTransitionInProgress = false }
            })

            observers.append(center.addObserver(forName: NSWindow.willExitFullScreenNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.isFullScreenTransitionInProgress = true }
            })

            observers.append(center.addObserver(forName: NSWindow.didExitFullScreenNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.isFullScreenTransitionInProgress = false
                    self?.saveFrame()
                }
            })

            settleStartupPersistenceGate(after: 1.0)
        }

        private func settleStartupPersistenceGate(after delay: TimeInterval) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                MainActor.assumeIsolated { self?.startupPhase = .settled }
            }
        }
        
        @MainActor
        private func saveFrame() {
            guard let window = window else { return }
            guard WindowAccessor.shouldSaveFrame(
                for: window,
                isFullScreenTransitionInProgress: isFullScreenTransitionInProgress
            ) else { return }
            guard WindowAccessor.isFrameValidForRestore(window.frame) else { return }
            guard shouldPersistCurrentFrame(window.frame) else { return }
            AppearancePreference.shared.hostWindowFrame = window.frame
        }

        private func shouldPersistCurrentFrame(_ frame: CGRect) -> Bool {
            switch startupPhase {
            case .settled:
                return true
            case .applyingDefault:
                return false
            case .restoring(let targetFrame):
                return WindowAccessor.framesApproximatelyEqual(frame, targetFrame)
            }
        }
    }
}
