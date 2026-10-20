import AppKit
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
    static func showPreferenceFailure() {
        let incident = ErrorFeedback.capture(.usageSettings)
        ErrorFeedback.present(incident, recoveryTitle: ErrorFeedback.text("Turn Off Usage Statistics"), recovery: {
            if !shared.setEnabled(false) { showPreferenceFailure() }
        })
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
            self.uploadIfDue(now: Date())
        }
    }
    private func uploadIfDue(now: Date) {
        guard task == nil, let result = transaction({ $0.prepare(at: now) }), let upload = result,
              let body = try? JSONEncoder().encode(upload), body.count <= 65536 else { return }
        // Recheck after reserving the shared lease; the other process may have opted out.
        guard transaction({ $0.enabled && $0.installationID == upload.installation_id }) == true else { return }
        var request = URLRequest(url: URL(string: "https://t.xykong.cc/v3/snapshots")!)
        request.httpMethod = "POST"; request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        task = session.dataTask(with: request) { data, response, error in
            self.queue.async {
                self.task = nil
                guard error == nil, (response as? HTTPURLResponse)?.statusCode == 200,
                      let data, let ack = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let accepted = ack["accepted"] as? [String: Int],
                      upload.snapshots.allSatisfy({ accepted[$0.bucket_id] == $0.sequence }) else { return }
                self.transaction { $0.acknowledge(upload) }
            }
        }
        task?.resume()
    }
}

private final class UsageActionButton: NSButton {
    var actionBlock: (() -> Void)?
    @objc func invoke() { actionBlock?() }
}

/// No file identity is persisted: the URL only distinguishes the current UI document.
final class UsageTelemetrySession {
    private weak var view: NSView?
    private var document: URL?
    private var timer: Timer?
    private var ready = false
    private var hostVisible = false
    private var counted = false
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var lastSecond: Int = 0
    private var pendingSeconds = 0
    private var pendingDate = Date()
    private var generation = ""
    private let source: String
    private let telemetry: UsageTelemetry
    init(source: String, telemetry: UsageTelemetry = .shared) { self.source = source; self.telemetry = telemetry }
    func attach(_ view: NSView, document: URL?) {
        self.view = view
        if self.document != document { flush(); self.document = document; counted = false; ready = false }
        if timer == nil {
            lastTick = ProcessInfo.processInfo.systemUptime
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        }
    }
    func setHostVisible(_ visible: Bool) { hostVisible = visible; if visible { sample(seconds: 0) } else { flush() } }
    func rendered() { ready = true; sample(seconds: 0) }
    func rendering() { flush(); ready = false }
    func stop() { flush(); timer?.invalidate(); timer = nil; ready = false; counted = false; document = nil; hostVisible = false }
    deinit { flush(); timer?.invalidate() }
    private func flush() {
        if pendingSeconds > 0 { telemetry.record(source: source, seconds: pendingSeconds, views: 0, installationID: generation, now: pendingDate) }
        pendingSeconds = 0
    }
    private func tick() {
        let uptime = ProcessInfo.processInfo.systemUptime
        let elapsed = uptime - lastTick; lastTick = uptime
        guard elapsed > 0, elapsed < 2.5 else { flush(); return }
        sample(seconds: 1)
    }
    private func sample(seconds: Int) {
        guard ready, document != nil, let view else { return }
        if source == "quicklook" {
            guard hostVisible else { flush(); return }
        } else {
            guard let window = view.window, window.isVisible, !window.isMiniaturized,
                  window.occlusionState.contains(.visible), NSApp.isActive, window.isKeyWindow else { flush(); return }
        }
        let now = Date(), second = Int(now.timeIntervalSince1970)
        if seconds > 0 { guard second != lastSecond else { return }; lastSecond = second }
        guard let state = telemetry.transaction(wait: false, { $0 }) else { pendingSeconds = 0; return }
        if generation != state.installationID { pendingSeconds = 0; counted = false; generation = state.installationID }
        guard state.enabled else { pendingSeconds = 0; return }
        if !state.disclosed {
            telemetry.transaction { $0.disclosed = true }
            disclose(in: view)
        }
        if UsageTelemetryState.day(now) != UsageTelemetryState.day(pendingDate) { flush() }
        pendingDate = now; pendingSeconds += seconds
        if !counted { telemetry.record(source: source, seconds: 0, views: 1, installationID: generation, now: now); counted = true }
        if pendingSeconds >= 15 { flush() }
    }
    private func disclose(in view: NSView) {
        let banner = NSStackView(); banner.orientation = .vertical; banner.alignment = .leading
        banner.wantsLayer = true; banner.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        banner.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        let text = NSTextField(wrappingLabelWithString: NSLocalizedString("Usage statistics are on: system/app versions, system timezone, daily reading time and view counts. No document names or contents. You can turn this off in Settings.", comment: "Telemetry disclosure"))
        banner.addArrangedSubview(text)
        let actions = NSStackView()
        for (key, disable) in [("Turn Off Usage Statistics", true), ("Dismiss", false)] {
            let button = UsageActionButton(title: NSLocalizedString(key, comment: "Telemetry action"), target: nil, action: #selector(UsageActionButton.invoke))
            button.target = button
            button.actionBlock = { [weak banner, telemetry] in
                if disable, !telemetry.setEnabled(false) { UsageTelemetry.showPreferenceFailure(); return }
                banner?.removeFromSuperview()
            }
            actions.addArrangedSubview(button)
        }
        banner.addArrangedSubview(actions); banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)
        NSLayoutConstraint.activate([banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            banner.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)])
    }
}
