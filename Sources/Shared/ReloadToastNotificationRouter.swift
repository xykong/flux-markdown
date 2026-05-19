import AppKit
import Foundation

enum ReloadToastResult {
    case success
    case failure
}

final class ReloadToastNotificationRouter {
    private(set) weak var window: NSWindow?
    private var observers: [NSObjectProtocol] = []
    var onResult: (ReloadToastResult) -> Void

    init(onResult: @escaping (ReloadToastResult) -> Void) {
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
            self?.onResult(.success)
        })
        observers.append(center.addObserver(forName: .reloadFileFailed, object: window, queue: .main) { [weak self] _ in
            self?.onResult(.failure)
        })
    }

    private func stopMonitoring() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
}
