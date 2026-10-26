import AppKit
import Foundation

extension UsageTelemetry {
    static func showPreferenceFailure() {
        let incident = ErrorFeedback.capture(.usageSettings)
        ErrorFeedback.present(incident, recoveryTitle: ErrorFeedback.text("Turn Off Usage Statistics"), recovery: {
            if !shared.setEnabled(false) { showPreferenceFailure() }
        })
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
