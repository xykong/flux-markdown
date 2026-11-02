import Foundation
import os.log

/// Keeps the latest failure across restarts. Never persists localized error text,
/// URLs, file paths or arbitrary userInfo from Sparkle / the operating system.
final class UpdateDiagnostics {
    static let shared = UpdateDiagnostics(defaults: .standard)
    private let defaults: UserDefaults
    private var session: UpdateSessionSnapshot?
    private var frozen: UpdateSessionSnapshot?
    private var startUptime = ProcessInfo.processInfo.systemUptime
    private let sessionsKey = "updateSessions.v1"
    private let log = OSLog(subsystem: "com.markdownquicklook.app", category: "Updater")
    private let key = "lastUpdateFailure.v1"
    private static let domains: Set<String> = [
        "SUSparkleErrorDomain", NSCocoaErrorDomain, NSPOSIXErrorDomain,
        NSURLErrorDomain, NSOSStatusErrorDomain
    ]

    private struct ErrorCode: Codable {
        let domain: String
        let code: Int
    }

    private struct Failure: Codable {
        let date: Date
        let sourceVersion: String
        let targetVersion: String
        let errors: [ErrorCode]
    }

    init(defaults: UserDefaults) { self.defaults = defaults }

    var latestSession: UpdateSessionSnapshot? { savedSessions.last }
    private var savedSessions: [UpdateSessionSnapshot] {
        guard let data = defaults.data(forKey: sessionsKey), data.count <= 32768,
              let values = try? JSONDecoder().decode([UpdateSessionSnapshot].self, from: data),
              values.count <= 3, values.allSatisfy(\.isValid) else { return [] }
        return values
    }

    func beginSession(observedCheck: Bool = true) {
        session = UpdateSessionSnapshot(id: UUID(), events: [], failure: nil, truncated: false)
        frozen = nil
        startUptime = ProcessInfo.processInfo.systemUptime
        event(observedCheck ? .checkStarted : .observationStarted)
    }

    func event(_ stage: UpdateStage) {
        if session == nil { beginSession(observedCheck: false) }
        guard frozen == nil, var current = session else { return }
        let elapsed = min(604800, max(0, ProcessInfo.processInfo.systemUptime - startUptime))
        if current.events.count >= 32 {
            current.events.remove(at: 1) // Preserve the initial check and newest evidence.
            current.truncated = true
        }
        current.events.append(UpdateSessionEvent(stage: stage, date: Date(), elapsed: elapsed))
        session = current
        persist(current)
        os_log("Update session %{public}@ stage %{public}@ elapsed %.3f", log: log, type: .info,
               current.id.uuidString, stage.rawValue, elapsed)
    }

    /// Idempotent across user-driver presentation and the subsequent abort callback.
    @discardableResult func freeze(error: Error) -> UpdateSessionSnapshot {
        if let frozen { return frozen }
        event(.failed)
        var current = session!
        var item: NSError? = error as NSError
        var category = UpdateFailureCategory.unclassified
        for _ in 0..<8 {
            guard let value = item else { break }
            if value.domain == "SUSparkleErrorDomain", value.code == 10 {
                // Exact allowlist only: no arbitrary descriptions, suffixes or paths persisted.
                switch value.userInfo[NSLocalizedDescriptionKey] as? String {
                case "Timeout: agent connection was never initiated": category = .agentConnectionTimeout
                case "Timeout: installation data was never received": category = .installationDataTimeout
                case "Error: Agent Invalidating without having the chance to reply to installer": category = .agentInvalidated
                default: break
                }
            }
            item = value.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        current.failure = category
        session = current; frozen = current
        persist(current)
        return current
    }

    private func persist(_ value: UpdateSessionSnapshot) {
        guard value.isValid else { return }
        var values = savedSessions.filter { $0.id != value.id }
        values.append(value)
        if let data = try? JSONEncoder().encode(Array(values.suffix(3))), data.count <= 32768 {
            defaults.set(data, forKey: sessionsKey)
        }
    }

    func record(error: Error, sourceVersion: String, targetVersion: String?, date: Date = Date()) {
        var errors: [ErrorCode] = []
        var current: NSError? = error as NSError
        while let item = current, errors.count < 8 {
            errors.append(ErrorCode(domain: Self.safeDomain(item.domain), code: item.code))
            current = item.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        let failure = Failure(date: date, sourceVersion: DiagnosticEnvironment.version(sourceVersion),
                              targetVersion: DiagnosticEnvironment.version(targetVersion ?? "unknown"), errors: errors)
        if let data = try? JSONEncoder().encode(failure) { defaults.set(data, forKey: key) }
    }

    func summary() -> String {
        let heading = "\n\n## Last update failure\n"
        guard let data = defaults.data(forKey: key), data.count <= 8192,
              let failure = try? JSONDecoder().decode(Failure.self, from: data),
              failure.date.timeIntervalSince1970.isFinite else {
            return heading + "No recorded update failure. History starts with this version."
        }
        let codes = failure.errors.prefix(8).map { "\(Self.safeDomain($0.domain)):\($0.code)" }.joined(separator: " → ")
        return heading + "- date: \(ISO8601DateFormatter().string(from: failure.date))\n"
            + "- versions: \(DiagnosticEnvironment.version(failure.sourceVersion)) → \(DiagnosticEnvironment.version(failure.targetVersion))\n"
            + "- error-chain: \(codes)\n"
            + "This is the last recorded failure, not the current update status. Error descriptions and private paths are omitted."
    }

    private static func safeDomain(_ domain: String) -> String {
        domains.contains(domain) ? domain : "other"
    }
}
