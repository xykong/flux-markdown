import Foundation
import Foundation
import Darwin
import os.log

/// Shared disk transactions coordinate host and sandboxed extension processes.
final class UsageTelemetry {
    static let shared = UsageTelemetry()
    private let queue = DispatchQueue(label: "com.xykong.Markdown.telemetry", qos: .utility)
    private let directory: URL
    private let session: URLSession
    private var task: URLSessionDataTask?
    private var nextBrokerWake = Date.distantPast
    private var brokerPending = false
    init(directory: URL = SharedPreferenceStore.applicationSupportDirectory().appendingPathComponent("Telemetry"), configuration: URLSessionConfiguration? = nil) {
        self.directory = directory
        let config = configuration ?? URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10; config.timeoutIntervalForResource = 15
        config.httpCookieStorage = nil; config.urlCache = nil
        session = URLSession(configuration: config)
    }
    @discardableResult
    func transaction<T>(wait: Bool = true, _ action: (inout UsageTelemetryState) -> T) -> T? {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            let descriptor = Darwin.open(directory.appendingPathComponent("state.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
            guard descriptor >= 0 else { return nil }
            defer { Darwin.close(descriptor) }
            guard flock(descriptor, wait ? LOCK_EX : (LOCK_EX | LOCK_NB)) == 0 else { return nil }
            defer { flock(descriptor, LOCK_UN) }
            let file = directory.appendingPathComponent("counters.json")
            var state: UsageTelemetryState
            if FileManager.default.fileExists(atPath: file.path) {
                let data = try BoundedFileReader.read(file, maxBytes: 1024 * 1024)
                state = try JSONDecoder().decode(UsageTelemetryState.self, from: data)
            } else { state = UsageTelemetryState() }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            let before = try encoder.encode(state)
            let result = action(&state)
            let after = try encoder.encode(state)
            if before != after || !FileManager.default.fileExists(atPath: file.path) {
                try after.write(to: file, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            }
            return result
        } catch {
            os_log("Usage statistics unavailable; collection skipped", type: .debug)
            return nil
        }
    }
    var enabled: Bool { transaction { $0.enabled } ?? false }
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        // Synchronous persisted opt-out prevents the other process from creating further snapshots.
        let saved = transaction { $0.setEnabled(enabled); return true } == true
        queue.async { if !enabled { self.task?.cancel(); self.task = nil } }
        return saved
    }
    func record(source: String, seconds: Int, views: Int, installationID: String, now: Date = Date()) {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let os = ProcessInfo.processInfo.operatingSystemVersion
        queue.async {
            self.transaction { state in
                guard state.enabled, state.installationID == installationID else { return }
                let previous = state.activityEnd[source] ?? now.addingTimeInterval(-Double(seconds))
                let duration = max(0, min(seconds, Int(now.timeIntervalSince(previous).rounded())))
                if seconds > 0 { state.activityEnd[source] = max(previous, now) }
                state.record(source: source, version: version, os: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)", at: now, seconds: duration, views: views)
            }
            if Bundle.main.bundleURL.pathExtension == "appex" {
                self.wakeUploadBroker()
            } else { self.uploadIfDue(now: Date()) }
        }
    }
    private func wakeUploadBroker() {
        guard !brokerPending, Date() >= nextBrokerWake,
              transaction({ $0.enabled && Date() >= $0.nextAttempt && $0.buckets.contains { $0.sequence > $0.acknowledged } }) == true else { return }
        brokerPending = true; nextBrokerWake = Date().addingTimeInterval(60)
        SearchLaunchClient.flushUsage { _ in
            self.queue.async { self.brokerPending = false }
        }
    }
    func flush(completion: @escaping (Bool) -> Void) {
        queue.async { self.uploadIfDue(now: Date(), completion: completion) }
    }
    private func uploadIfDue(now: Date, completion: @escaping (Bool) -> Void = { _ in }) {
        guard task == nil, let result = transaction({ $0.prepare(at: now) }), let upload = result,
              let body = try? JSONEncoder().encode(upload), body.count <= 65536 else { completion(false); return }
        // Recheck after reserving the shared lease; the other process may have opted out.
        guard transaction({ $0.enabled && $0.installationID == upload.installation_id }) == true else { completion(false); return }
        var request = URLRequest(url: URL(string: "https://t.xykong.cc/v3/snapshots")!)
        request.httpMethod = "POST"; request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        task = session.dataTask(with: request) { data, response, error in
            self.queue.async {
                self.task = nil
                guard error == nil, (response as? HTTPURLResponse)?.statusCode == 200,
                      let data, let ack = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let accepted = ack["accepted"] as? [String: Int],
                      upload.snapshots.allSatisfy({ accepted[$0.bucket_id] == $0.sequence }) else { completion(false); return }
                self.transaction { $0.acknowledge(upload) }
                completion(true)
            }
        }
        task?.resume()
    }
}
