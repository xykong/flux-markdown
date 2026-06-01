import AppKit
import Foundation

enum ToolbarFeedbackResult: Equatable {
    case reloadSuccess
    case reloadFailure
    case resetZoom
}

final class ToolbarFeedbackNotificationRouter {
    private(set) weak var window: NSWindow?
    private var observers: [NSObjectProtocol] = []
    var onResult: (ToolbarFeedbackResult) -> Void

    init(onResult: @escaping (ToolbarFeedbackResult) -> Void) {
        self.onResult = onResult
    }

    deinit {
        stopMonitoring()
    }

    func monitor(window: NSWindow) {
        guard self.window !== window else { return }
        stopMonitoring()
        self.window = window

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .reloadFileSucceeded, object: window, queue: .main) { [weak self] _ in
            self?.onResult(.reloadSuccess)
        })
        observers.append(center.addObserver(forName: .reloadFileFailed, object: window, queue: .main) { [weak self] _ in
            self?.onResult(.reloadFailure)
        })
        observers.append(center.addObserver(forName: .resetZoomCompleted, object: window, queue: .main) { [weak self] _ in
            self?.onResult(.resetZoom)
        })
    }

    private func stopMonitoring() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
}
