import Foundation

/// Refresh policy shared by file metadata and content reads; contains no paths/text.
struct QuickLookFollowState {
    var enabled = false
    var paused = false
    private(set) var suspended = false
    private var failures = 0
    var interval: TimeInterval { enabled ? 0.5 : 2 }

    /// Paused and the file has changed since the preview last showed it.
    var linesWaiting = false

    enum ButtonLook: Equatable { case off, following, paused }
    var buttonLook: ButtonLook { !enabled ? .off : paused ? .paused : .following }
    enum ButtonClick: Equatable { case start, stop, resume }
    /// One click turns Follow on, stops a running Follow and resumes a paused one;
    /// a double click always stops it.
    func buttonClick(clickCount: Int) -> ButtonClick {
        if clickCount >= 2 { return .stop }
        switch buttonLook { case .off: return .start; case .following: return .stop; case .paused: return .resume }
    }

    mutating func start() { enabled = true; paused = false; linesWaiting = false; succeeded() }
    mutating func stop() { enabled = false; paused = false; linesWaiting = false }
    mutating func reset() { self = Self() }
    mutating func succeeded() { failures = 0; suspended = false }
    /// Report once after bounded retries; normal refresh reports its first failure.
    mutating func failedAttempt() -> Bool {
        guard !suspended else { return false }
        failures += 1
        guard !enabled || failures >= 3 else { return false }
        stop(); suspended = true
        return true
    }
}
