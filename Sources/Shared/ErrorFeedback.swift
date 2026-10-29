import AppKit
import os.log

final class IncidentDraft {
    var incident: ErrorIncident
    var includeDiagnostics = true
    var notes = ""
    init(_ incident: ErrorIncident) { self.incident = incident }
    var report: String { "Operation: \(incident.kind.rawValue)\nObserved result: \(incident.kind.title)\n" + notes + (includeDiagnostics ? "\n\n" + incident.report : "") }
}

/// App-owned errors share collection, recovery controls and a single feedback route.
enum ErrorFeedback {
    static let store: ErrorIncidentStore = {
        guard Bundle.main.bundleIdentifier == "com.xykong.Markdown" else { return ErrorIncidentStore() }
        return ErrorIncidentStore(fileURL: SharedPreferenceStore.applicationSupportDirectory().appendingPathComponent("error-incidents.json"))
    }()
    static var supplementProvider: ((ErrorIncident, @escaping (ErrorIncident) -> Void) -> Void)?
    private static var pending = Set<UUID>()
    private static var windows: [UUID: IncidentReportWindow] = [:]
    private static var drafts: [UUID: IncidentDraft] = [:]
    private static var draftOrder: [UUID] = []
    private static func remember(_ incoming: IncidentDraft) -> IncidentDraft {
        if let existing = drafts[incoming.incident.id] {
            if existing !== incoming {
                existing.includeDiagnostics = existing.includeDiagnostics && incoming.includeDiagnostics
                if existing.notes.isEmpty { existing.notes = incoming.notes }
            }
            return existing
        }
        drafts[incoming.incident.id] = incoming; draftOrder.append(incoming.incident.id)
        while draftOrder.count > 100 {
            let oldest = draftOrder.removeFirst()
            if windows[oldest] == nil { drafts.removeValue(forKey: oldest) }
        }
        return incoming
    }
    static func clearHistory() {
        store.clear()
        drafts = drafts.filter { windows[$0.key] != nil }
        draftOrder = draftOrder.filter { drafts[$0] != nil }
    }
    static func text(_ key: String) -> String { NSLocalizedString(key, comment: "Error guidance and contextual feedback") }
    static var disclosure: String { text("Opens GitHub with this error and system information. You confirm publication there.") }

    @discardableResult static func capture(_ kind: FailureKind, error: Error? = nil,
                                          phase: IncidentPhase = .failed, scope: UUID? = nil, reason: IncidentReason? = nil, targetVersion: String? = nil) -> ErrorIncident {
        let source: IncidentSource = Bundle.main.bundleIdentifier == "com.xykong.Markdown.QuickLook" ? .quicklook : .app
        var environment = DiagnosticEnvironment.current()
        if let targetVersion { environment["targetVersion"] = targetVersion }
        let allSettings = DiagnosticSettings.sanitize(AppearancePreference.shared.diagnosticSettings)
        let settings = [.update, .browser, .link, .fileRead, .fileTooLarge].contains(kind)
            ? allSettings.filter { $0.key == "uiLanguage" } : allSettings
        var incident = ErrorIncident(kind: kind, source: source, phase: phase, scope: scope, error: error,
                                     environment: environment, settings: settings)
        incident.reason = reason
        incident.historyUnavailable = store.unavailable
        let contextKeys = Set(incident.settings.keys)
        incident.settingChanges = AppearancePreference.shared.history?.snapshot().events.filter { contextKeys.contains($0.key) }.suffix(5).compactMap {
            let change = IncidentSettingChange(key: $0.key, before: $0.oldValue, after: $0.newValue, date: $0.date)
            return change.isValid ? change : nil
        } ?? []
        if source == .app, [.quickLook, .images, .previewLimit].contains(kind) {
            let result = UserDefaults.standard.string(forKey: "quickLookLastProbeResult") ?? "not-run"
            incident.previewTest = ["rendered", "unconfirmed", "not-run"].contains(result) ? result : "not-run"
        }
        if let scope {
            incident.steps = store.incidents.filter { $0.scope == scope }.suffix(12).map { IncidentStep(kind: $0.kind, phase: $0.phase, date: $0.date) }
        }
        store.record(incident)
        if store.unavailable { incident.historyUnavailable = true }
        os_log("Incident %{public}@ %{public}@ %{public}@", log: OSLog(subsystem: "com.markdownquicklook.app", category: "ErrorFeedback"),
               type: phase == .failed ? .error : .info, incident.id.uuidString, kind.rawValue, phase.rawValue)
        return incident
    }

    static func report(_ requestDraft: IncidentDraft, review: Bool = false, failure: ((IncidentDraft) -> Void)? = nil, openURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) }, collectSupplement: Bool = true) {
        precondition(Thread.isMainThread)
        let draft = remember(requestDraft)
        guard pending.count < 100 else { failure?(draft); return }
        guard pending.insert(draft.incident.id).inserted else { return }
        if collectSupplement, draft.includeDiagnostics, draft.incident.quickLookCheck == nil,
           [.quickLook, .images, .previewLimit, .fileRead].contains(draft.incident.kind),
           let provider = supplementProvider, Bundle.main.bundleIdentifier != "com.xykong.Markdown.QuickLook" {
            var finished = false
            let finish: (ErrorIncident) -> Void = { incident in
                guard !finished else { return }; finished = true
                if incident.id == draft.incident.id && incident.isValid { draft.incident = incident }
                pending.remove(draft.incident.id)
                report(draft, review: review, failure: failure, openURL: openURL, collectSupplement: false)
            }
            provider(draft.incident) { incident in DispatchQueue.main.async { finish(incident) } }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                guard !finished else { return }
                var partial = draft.incident; partial.historyUnavailable = true
                finish(partial)
            }
            return
        }
        store.record(draft.incident)
        if Bundle.main.bundleIdentifier == "com.xykong.Markdown.QuickLook" {
            var request = IncidentFeedbackRequest(incident: draft.incident, includeDiagnostics: draft.includeDiagnostics, notes: String(draft.notes.prefix(600)))
            request.review = review
            guard let data = try? JSONEncoder().encode(request), data.count <= 16384 else {
                pending.remove(draft.incident.id); failure?(draft); return
            }
            SearchLaunchClient.reportError(data) { success in
                pending.remove(draft.incident.id)
                if !success { failure?(draft) }
            }
        } else {
            if review { pending.remove(draft.incident.id); showDraft(draft); return }
            let opened = openURL(draft.incident.feedbackURL(includeDiagnostics: draft.includeDiagnostics, notes: draft.notes))
            // Keep the same draft reachable even if the browser later fails to load/sign in.
            if !opened { if let failure { failure(draft) } else { showDraft(draft, failed: true) } }
            else { windows[draft.incident.id]?.updateStatus(failed: false) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { pending.remove(draft.incident.id) }
        }
    }

    static func receive(_ url: URL) -> Bool {
        guard url.scheme == "markdownpreview", url.host == "report-error" else { return false }
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              items.count == 1, items[0].name == "payload", let value = items[0].value, value.utf8.count <= 24000,
              let data = Data(base64Encoded: value), let request = IncidentFeedbackRequest.decode(data) else { return true }
        let draft = IncidentDraft(request.incident)
        draft.includeDiagnostics = request.includeDiagnostics; draft.notes = request.notes
        report(draft, review: request.review)
        return true
    }

    static func present(_ incident: ErrorIncident, recoveryTitle: String? = nil, recovery: (() -> Void)? = nil) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { present(incident, recoveryTitle: recoveryTitle, recovery: recovery) }; return
        }
        let draft = IncidentDraft(incident), alert = NSAlert()
        alert.messageText = text(incident.kind.title)
        alert.informativeText = text(incident.kind.guidance)
        if let recoveryTitle, recovery != nil { alert.addButton(withTitle: text(recoveryTitle)) }
        alert.addButton(withTitle: text("Report This Problem"))
        alert.addButton(withTitle: text("Close"))
        alert.accessoryView = IncidentFeedbackControls(draft: draft)
        let response = alert.runModal()
        let reportIndex = recovery == nil || recoveryTitle == nil ? 0 : 1
        let selected = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        // Complete the original modal before presenting an editor or browser handoff.
        if selected == reportIndex {
            report(draft, failure: { draft in
                showDraft(draft, failed: true)
            })
        }
        else if selected == 0 && reportIndex == 1 { recovery?() }
    }

    static func showDraft(_ incoming: IncidentDraft, failed: Bool = false, bringForward: Bool = true) {
        let draft = remember(incoming)
        if let existing = windows[draft.incident.id] {
            existing.updateStatus(failed: failed)
            if bringForward { existing.showWindow(nil); existing.window?.makeKeyAndOrderFront(nil) }
            return
        }
        let controller = IncidentReportWindow(draft: draft)
        windows[draft.incident.id] = controller
        controller.onClose = { windows.removeValue(forKey: draft.incident.id) }
        controller.updateStatus(failed: failed)
        if bringForward { controller.showWindow(nil); NSApp.activate(ignoringOtherApps: true); controller.window?.makeKeyAndOrderFront(nil) }
    }
    static func showLatest() {
        guard let incident = store.incidents.last(where: { $0.phase == .failed || $0.phase == .timeout }) else { return }
        showDraft(IncidentDraft(incident))
    }
}

final class IncidentFeedbackControls: NSStackView {
    private let draft: IncidentDraft
    init(draft: IncidentDraft) {
        self.draft = draft
        super.init(frame: NSRect(x: 0, y: 0, width: 420, height: 90))
        orientation = .vertical; alignment = .leading; spacing = 8
        let info = NSTextField(wrappingLabelWithString: ErrorFeedback.disclosure)
        info.font = .systemFont(ofSize: 11); info.textColor = .secondaryLabelColor
        let include = NSButton(checkboxWithTitle: ErrorFeedback.text("Include diagnostics"), target: self, action: #selector(toggle(_:)))
        include.state = draft.includeDiagnostics ? .on : .off
        let inspect = NSButton(title: ErrorFeedback.text("Review Feedback…"), target: self, action: #selector(review))
        addArrangedSubview(info); addArrangedSubview(include); addArrangedSubview(inspect)
        info.widthAnchor.constraint(equalToConstant: 420).isActive = true
    }
    required init?(coder: NSCoder) { nil }
    @objc private func toggle(_ sender: NSButton) { draft.includeDiagnostics = sender.state == .on }
    @objc private func review() {
        // Optional inspection works even while an error alert has a modal runloop.
        let alert = NSAlert(); alert.messageText = ErrorFeedback.text("Review Feedback…")
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 520, height: 300))
        let view = NSTextView(frame: scroll.bounds); view.isEditable = false; view.string = draft.report
        view.font = .monospacedSystemFont(ofSize: 11, weight: .regular); scroll.documentView = view; scroll.hasVerticalScroller = true
        let notesScroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 520, height: 80))
        let notes = NSTextView(frame: notesScroll.bounds); notes.isRichText = false; notes.string = draft.notes
        notesScroll.documentView = notes; notesScroll.hasVerticalScroller = true
        let stack = NSStackView(views: [scroll, NSTextField(labelWithString: ErrorFeedback.text("Additional details (optional)")), notesScroll])
        stack.orientation = .vertical; stack.frame = NSRect(x: 0, y: 0, width: 520, height: 410)
        scroll.widthAnchor.constraint(equalToConstant: 520).isActive = true; scroll.heightAnchor.constraint(equalToConstant: 300).isActive = true
        notesScroll.widthAnchor.constraint(equalToConstant: 520).isActive = true; notesScroll.heightAnchor.constraint(equalToConstant: 80).isActive = true
        alert.accessoryView = stack; alert.addButton(withTitle: ErrorFeedback.text("Done")); alert.runModal()
        draft.notes = notes.string
    }
}

/// Native, persistent fallback for failed WebViews as well as lightweight notices.
final class IncidentNotice: NSView {
    private let draft: IncidentDraft
    private let recovery: (() -> Void)?
    private var buttonStack: NSStackView?
    init(incident: ErrorIncident, recoveryTitle: String? = nil, recovery: (() -> Void)? = nil) {
        draft = IncidentDraft(incident); self.recovery = recovery
        super.init(frame: .zero)
        wantsLayer = true; layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor; layer?.cornerRadius = 8
        let message = NSTextField(wrappingLabelWithString: ErrorFeedback.text(incident.kind.title) + ". " + ErrorFeedback.text(incident.kind.guidance))
        let buttons = NSStackView(); buttons.orientation = .horizontal; buttons.spacing = 8
        buttonStack = buttons
        if let recoveryTitle, recovery != nil { buttons.addArrangedSubview(NSButton(title: ErrorFeedback.text(recoveryTitle), target: self, action: #selector(recover))) }
        buttons.addArrangedSubview(NSButton(title: ErrorFeedback.text("Report This Problem"), target: self, action: #selector(report)))
        buttons.addArrangedSubview(NSButton(title: ErrorFeedback.text("Review Feedback…"), target: self, action: #selector(review)))
        buttons.addArrangedSubview(NSButton(title: ErrorFeedback.text("Close"), target: self, action: #selector(close)))
        let disclosure = NSTextField(wrappingLabelWithString: ErrorFeedback.disclosure)
        disclosure.font = .systemFont(ofSize: 11)
        let content = NSStackView(views: [message, buttons, disclosure])
        content.orientation = .vertical; content.alignment = .leading; content.spacing = 6; content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        message.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        disclosure.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        NSLayoutConstraint.activate([content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12), content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12), content.topAnchor.constraint(equalTo: topAnchor, constant: 10), content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)])
    }
    required init?(coder: NSCoder) { nil }
    override func layout() {
        let orientation: NSUserInterfaceLayoutOrientation = bounds.width < 660 ? .vertical : .horizontal
        if buttonStack?.orientation != orientation { buttonStack?.orientation = orientation; buttonStack?.alignment = orientation == .vertical ? .leading : .centerY }
        super.layout()
    }
    @objc private func recover() { removeFromSuperview(); recovery?() }
    @objc private func report() { ErrorFeedback.report(draft, failure: { [weak self] draft in self?.showFallback(draft) }) }
    @objc private func review() { ErrorFeedback.report(draft, review: true, failure: { [weak self] draft in self?.showFallback(draft) }) }
    private func showFallback(_ draft: IncidentDraft) {
        guard let parent = superview else { return }
        Self.fallback(in: parent, draft: draft)
    }
    static func fallback(in view: NSView, draft: IncidentDraft) {
        let notice = IncidentNotice(incident: draft.incident, recoveryTitle: "Copy Report", recovery: {
            NSPasteboard.general.clearContents(); NSPasteboard.general.setString(draft.report, forType: .string)
        })
        for old in view.subviews.compactMap({ $0 as? IncidentNotice }) { old.removeFromSuperview() }
        let status = NSTextField(wrappingLabelWithString: ErrorFeedback.text("The feedback page could not be opened. Copy the report, then use Help → Report an Issue in FluxMarkdown."))
        if let stack = notice.subviews.first as? NSStackView { stack.insertArrangedSubview(status, at: 0) }
        notice.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(notice)
        NSLayoutConstraint.activate([notice.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12), notice.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12), notice.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)])
    }
    @objc private func close() { removeFromSuperview() }
    static func attach(to view: NSView, incident: ErrorIncident, recoveryTitle: String? = nil, recovery: (() -> Void)? = nil) {
        for existing in view.subviews.compactMap({ $0 as? IncidentNotice }) { existing.removeFromSuperview() }
        let notice = IncidentNotice(incident: incident, recoveryTitle: recoveryTitle, recovery: recovery)
        notice.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(notice)
        NSLayoutConstraint.activate([notice.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12), notice.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12), notice.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)])
    }
}

private final class IncidentReportWindow: NSWindowController, NSWindowDelegate {
    let draft: IncidentDraft
    private let notes = NSTextView()
    private let details = NSTextView()
    private let status = NSTextField(wrappingLabelWithString: "")
    var onClose: (() -> Void)?
    init(draft: IncidentDraft) {
        self.draft = draft
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 590), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        super.init(window: window); window.delegate = self; window.isReleasedWhenClosed = false; window.title = ErrorFeedback.text("Report This Problem")
        let content = NSStackView(); content.orientation = .vertical; content.alignment = .leading; content.spacing = 10; content.translatesAutoresizingMaskIntoConstraints = false
        let heading = NSTextField(labelWithString: ErrorFeedback.text(draft.incident.kind.title)); heading.font = .boldSystemFont(ofSize: 15)
        content.addArrangedSubview(heading); content.addArrangedSubview(status)
        content.addArrangedSubview(NSTextField(labelWithString: ErrorFeedback.text("Additional details (optional)")))
        for (view, height) in [(notes, CGFloat(95)), (details, CGFloat(240))] {
            let scroll = NSScrollView(); scroll.documentView = view; scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
            view.isRichText = false; view.isVerticallyResizable = true; view.autoresizingMask = [.width]; view.textContainer?.widthTracksTextView = true
            content.addArrangedSubview(scroll); scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: height).isActive = true
            scroll.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        }
        notes.string = draft.notes; details.string = draft.incident.report; details.isEditable = false; details.isHidden = !draft.includeDiagnostics; details.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        let include = NSButton(checkboxWithTitle: ErrorFeedback.text("Include diagnostics"), target: self, action: #selector(toggle(_:))); include.state = draft.includeDiagnostics ? .on : .off
        content.addArrangedSubview(include)
        let actions = NSStackView()
        for (title, action) in [("Open Feedback Page", #selector(openPage)), ("Copy Report", #selector(copyReport)), ("Save Report…", #selector(saveReport))] {
            actions.addArrangedSubview(NSButton(title: ErrorFeedback.text(title), target: self, action: action))
        }
        content.addArrangedSubview(actions)
        if draft.incident.kind == .update {
            content.addArrangedSubview(ErrorActionButton(title: ErrorFeedback.text("Download Latest Version")) { [weak self] in
                guard NSWorkspace.shared.open(URL(string: "https://github.com/xykong/flux-markdown/releases/latest")!) else {
                    self?.status.stringValue = ErrorFeedback.text("Copy the download link and paste it into your browser to download the latest version.") + "\nhttps://github.com/xykong/flux-markdown/releases/latest"
                    self?.status.isSelectable = true; return
                }
            })
        }
        window.contentView!.addSubview(content)
        NSLayoutConstraint.activate([content.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 20), content.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -20), content.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 20), content.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -20)])
        window.center()
    }
    required init?(coder: NSCoder) { nil }
    func updateStatus(failed: Bool) {
        status.stringValue = ErrorFeedback.text(failed ? "The feedback page could not be opened. Copy or save this report and try again later." : "The report is ready. GitHub requires you to confirm publication. You can reopen, copy or save it here.")
    }
    @objc private func toggle(_ sender: NSButton) { draft.includeDiagnostics = sender.state == .on; details.isHidden = !draft.includeDiagnostics }
    @objc private func openPage() { draft.notes = notes.string; ErrorFeedback.report(draft) }
    @objc private func copyReport() { draft.notes = notes.string; NSPasteboard.general.clearContents(); NSPasteboard.general.setString(draft.report, forType: .string) }
    @objc private func saveReport() {
        draft.notes = notes.string
        let panel = NSSavePanel(); panel.nameFieldStringValue = "FluxMarkdown-report.md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try draft.report.write(to: url, atomically: true, encoding: .utf8) }
        catch { status.stringValue = ErrorFeedback.text("Could not save the report. You can copy it instead.") }
    }
    func windowWillClose(_ notification: Notification) { draft.notes = notes.string; onClose?() }
}

final class RendererErrorRegistry {
    var onFailure: ((IncidentDraft) -> Void)?
    var onRecover: ((ErrorIncident) -> Void)?
    private(set) var scope = UUID()
    private var incidents: [String: ErrorIncident] = [:]
    func beginDocument() -> String { scope = UUID(); incidents.removeAll(); return scope.uuidString }
    func nativeFailure(_ kind: FailureKind, error: Error? = nil) -> ErrorIncident {
        let key = "native:" + kind.rawValue
        let codes = ErrorIncident(kind: kind, source: .app, error: error).codes
        if let existing = incidents[key], existing.codes == codes { return existing }
        let incident = ErrorFeedback.capture(kind, error: error, scope: scope)
        incidents[key] = incident
        return incident
    }
    func receive(_ body: [String: Any]) -> (incident: ErrorIncident, action: String)? {
        guard Set(body.keys).isSubset(of: Set(["action", "kind", "generation", "id", "reason"])),
              let action = body["action"] as? String, ["record", "report", "inspect", "recover"].contains(action),
              let generation = body["generation"] as? String, generation == scope.uuidString,
              let id = body["id"] as? String, id.utf8.count <= 32, !id.isEmpty, id.allSatisfy(\.isNumber),
              let rawKind = body["kind"] as? String, let kind = FailureKind(rawValue: rawKind),
              [.renderer, .source, .mermaid, .typst, .graphviz, .vega, .math, .search, .images, .copy].contains(kind) else { return nil }
        let reason: IncidentReason?
        if let raw = body["reason"] {
            guard let value = raw as? String, let parsed = IncidentReason(rawValue: value) else { return nil }
            reason = parsed
        } else { reason = nil }
        if action == "record" {
            if incidents[id] == nil {
                guard incidents.count < 100 else { return nil }
                incidents[id] = ErrorFeedback.capture(kind, scope: scope, reason: reason)
            }
        }
        guard let incident = incidents[id], incident.kind == kind else { return nil }
        return (incident, action)
    }
    func handle(_ body: Any) {
        guard let body = body as? [String: Any], let event = receive(body) else { return }
        if event.action == "recover" { onRecover?(event.incident); return }
        let generation = scope
        let failure: (IncidentDraft) -> Void = { [weak self] draft in
            guard let self, self.scope == generation else { return }
            self.onFailure?(draft)
        }
        if event.action == "report" { ErrorFeedback.report(IncidentDraft(event.incident), failure: failure) }
        if event.action == "inspect" { ErrorFeedback.report(IncidentDraft(event.incident), review: true, failure: failure) }
    }
}

final class ErrorActionButton: NSButton {
    private let actionBlock: () -> Void
    init(title: String, action: @escaping () -> Void) {
        actionBlock = action
        super.init(frame: .zero)
        self.title = title; bezelStyle = .rounded; target = self; self.action = #selector(activate)
    }
    required init?(coder: NSCoder) { nil }
    @objc private func activate() { actionBlock() }
}

/// Foundation recovery options integrate with system-presented document errors.
struct DocumentReadFailure: LocalizedError, RecoverableError, CustomNSError {
    let incident: ErrorIncident
    init(kind: FailureKind, error: Error) { incident = ErrorFeedback.capture(kind, error: error) }
    var errorDescription: String? { ErrorFeedback.text(incident.kind.title) }
    var recoverySuggestion: String? { ErrorFeedback.text(incident.kind.guidance) + "\n\n" + ErrorFeedback.disclosure }
    var recoveryOptions: [String] { ["Choose Another File", "Report This Problem", "Review Feedback…", "Close"].map(ErrorFeedback.text) }
    static var errorDomain: String { "com.xykong.Markdown.DocumentRead" }
    var errorCode: Int { incident.kind == .fileTooLarge ? CocoaError.fileReadTooLarge.rawValue : CocoaError.fileReadCorruptFile.rawValue }
    var errorUserInfo: [String: Any] {
        [NSLocalizedDescriptionKey: errorDescription ?? "", NSLocalizedRecoverySuggestionErrorKey: recoverySuggestion ?? "",
         NSLocalizedRecoveryOptionsErrorKey: recoveryOptions, NSRecoveryAttempterErrorKey: DocumentErrorRecoveryAttempter(failure: self)]
    }
    func attemptRecovery(optionIndex: Int) -> Bool {
        DispatchQueue.main.async {
            if optionIndex == 0 { NSDocumentController.shared.openDocument(nil) }
            if optionIndex == 1 { ErrorFeedback.report(IncidentDraft(incident)) }
            if optionIndex == 2 { ErrorFeedback.report(IncidentDraft(incident), review: true) }
        }
        // Choosing another file or reporting handles the error, but does not make
        // the original read succeed. Do not ask AppKit to treat it as recovered.
        return false
    }
}

/// AppKit invokes these Objective-C selectors, not the Swift RecoverableError witness.
final class DocumentErrorRecoveryAttempter: NSObject {
    let failure: DocumentReadFailure
    init(failure: DocumentReadFailure) { self.failure = failure }

    override func attemptRecovery(fromError error: Error, optionIndex: Int) -> Bool {
        guard (0...3).contains(optionIndex) else { return false }
        return failure.attemptRecovery(optionIndex: optionIndex)
    }

    override func attemptRecovery(fromError error: Error, optionIndex: Int, delegate: Any?, didRecoverSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        let recovered = attemptRecovery(fromError: error, optionIndex: optionIndex)
        guard let target = delegate as? NSObject, let selector = didRecoverSelector,
              target.responds(to: selector), let implementation = target.method(for: selector) else { return }
        typealias RecoveryCallback = @convention(c) (AnyObject, Selector, Bool, UnsafeMutableRawPointer?) -> Void
        unsafeBitCast(implementation, to: RecoveryCallback.self)(target, selector, recovered, contextInfo)
    }
}
