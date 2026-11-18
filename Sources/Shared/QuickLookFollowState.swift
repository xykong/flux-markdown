import Foundation

/// Refresh policy shared by file metadata and content reads; contains no paths/text.
struct QuickLookFollowState {
    var enabled = false
    var paused = false
    private(set) var suspended = false
    private var failures = 0
    var interval: TimeInterval { enabled ? 0.5 : 2 }

    mutating func start() { enabled = true; paused = false; succeeded() }
    mutating func stop() { enabled = false; paused = false }
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
