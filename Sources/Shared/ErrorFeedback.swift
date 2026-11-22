import AppKit
import os.log

final class IncidentDraft {
    var incident: ErrorIncident
    var includeDiagnostics = true
    var notes = ""
    private var didPrepareDefaultContent = false
    var materialContext: FeedbackMaterialContext?
    var includeDocument = true
    var attachmentURL: URL?
    var shareAttachment = false
    var uploadedAttachmentReference: String?
    var uploadedAttachment: URL?
    var attachmentResources: [URL] = []
    var attachmentFingerprint: String?
    var restoredUpload = false
    var documentName: String { materialContext?.displayName ?? materialContext?.originalURL?.lastPathComponent ?? "document.md" }
    func prepareDefaultContent() {
        guard !didPrepareDefaultContent else { return }; didPrepareDefaultContent = true
        guard notes.isEmpty else { return }
        notes = ErrorFeedback.text("Observed problem:") + " " + ErrorFeedback.text(incident.kind.title)
            + "\n" + ErrorFeedback.text("Source:") + " " + incident.source.rawValue
            + "\n" + ErrorFeedback.text("Operation:") + " " + incident.kind.rawValue
            + "\n" + ErrorFeedback.text("Failure category:") + " " + (incident.reason?.rawValue ?? "operationFailed")
            + "\n" + ErrorFeedback.text("App version:") + " " + (incident.environment["appVersion"] ?? "unknown")
    }
    func restoreNotes(_ value: String) { notes = value; didPrepareDefaultContent = true }
    static var attachmentDirectory: URL { FileManager.default.temporaryDirectory.appendingPathComponent("FluxMarkdown-FeedbackAttachments", isDirectory: true) }
    func prepareDocumentAttachment(in root: URL = IncidentDraft.attachmentDirectory) throws -> URL {
        guard includeDocument, let document = materialContext?.document else { throw CocoaError(.fileReadNoSuchFile) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        guard try root.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw CocoaError(.fileWriteNoPermission) }
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        for child in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey]) where UUID(uuidString: child.lastPathComponent) != nil {
            if let date = try child.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, date < Date().addingTimeInterval(-86400) { try FileManager.default.removeItem(at: child) }
        }
        let folder = root.appendingPathComponent(incident.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let package = try FeedbackReproduction.prepare(source: document, mode: "document", diagnostics: includeDiagnostics ? report : "", incident: incident.id, originalURL: materialContext?.originalURL, resources: attachmentResources, provenance: materialContext?.provenance ?? "unknown")
        let url = folder.appendingPathComponent("FluxMarkdown-reproduction.zip")
        try package.writeZIP(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        attachmentURL = url
        attachmentFingerprint = FeedbackAttachmentClient.digest(package.entries.reduce(into: Data()) { data, entry in
            data.append(Data(entry.name.utf8)); data.append(0); data.append(Data(FeedbackAttachmentClient.digest(entry.data).utf8))
        })
        return url
    }
    init(_ incident: ErrorIncident) { self.incident = incident }
    var report: String { "Operation: \(incident.kind.rawValue)\nObserved result: \(incident.kind.title)\n" + notes + (includeDiagnostics ? "\n\n" + incident.report : "") }
}

/// App-owned errors share collection, recovery controls and a single feedback route.
enum ErrorFeedback {
    static let store: ErrorIncidentStore = {
        guard Bundle.main.bundleIdentifier == "com.xykong.Markdown" else { return ErrorIncidentStore() }
        return ErrorIncidentStore(fileURL: SharedPreferenceStore.applicationSupportDirectory().appendingPathComponent("error-incidents.json"))
    }()
    static var materialPresenter: ((IncidentDraft) -> Void)?
    static var reportPrepared: ((ErrorIncident) -> Void)?
    static var showFollowUp: (() -> Void)?
    static var followRepliesEnabled: (() -> Bool)?
    static var setFollowReplies: ((Bool) -> Void)?
    static var supplementProvider: ((ErrorIncident, @escaping (ErrorIncident) -> Void) -> Void)?
    private static var pending = Set<UUID>()
    private static var windows: [UUID: IncidentReportWindow] = [:]
    private static var drafts: [UUID: IncidentDraft] = [:]
    private static var draftOrder: [UUID] = []
    private static func remember(_ incoming: IncidentDraft) -> IncidentDraft {
        if let existing = drafts[incoming.incident.id] {
            if existing !== incoming {
                existing.includeDiagnostics = existing.includeDiagnostics && incoming.includeDiagnostics
                existing.includeDocument = existing.includeDocument && incoming.includeDocument
                if existing.notes.isEmpty { existing.notes = incoming.notes }
                if existing.materialContext == nil { existing.materialContext = incoming.materialContext }
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
    static func restorePendingUploads() {
        for job in FeedbackAttachmentJob.all().filter({ !$0.opened }).prefix(3) { showDraft(job.draft()) }
    }
    static func clearHistory() {
        store.clear()
        drafts = drafts.filter { windows[$0.key] != nil }
        draftOrder = draftOrder.filter { drafts[$0] != nil }
    }
    static func text(_ key: String) -> String { NSLocalizedString(key, comment: "Error guidance and contextual feedback") }
    static var disclosure: String { text("Opens GitHub with this error and system information. You confirm publication there.") + " " + text("FluxMarkdown can check this public Issue for replies while running. Manage reminders in My Feedback.") }

    @discardableResult static func capture(_ kind: FailureKind, error: Error? = nil,
                                          phase: IncidentPhase = .failed, scope: UUID? = nil, reason: IncidentReason? = nil, targetVersion: String? = nil, renderingBlocker: FailureKind? = nil) -> ErrorIncident {
        let source: IncidentSource = Bundle.main.bundleIdentifier == "com.xykong.Markdown.QuickLook" ? .quicklook : .app
        var environment = DiagnosticEnvironment.current()
        if let targetVersion { environment["targetVersion"] = targetVersion }
        let allSettings = DiagnosticSettings.sanitize(AppearancePreference.shared.diagnosticSettings)
        let settings = [.attribution, .update, .browser, .link, .fileRead, .fileTooLarge].contains(kind)
            ? allSettings.filter { $0.key == "uiLanguage" } : allSettings
        var incident = ErrorIncident(kind: kind, source: source, phase: phase, scope: scope, error: error,
                                     environment: environment, settings: settings)
        if kind == .update, let error {
            incident.updateSession = UpdateDiagnostics.shared.freeze(error: error)
        }
        incident.reason = reason
        incident.renderingBlocker = renderingBlocker
        incident.historyUnavailable = store.unavailable
        let contextKeys = Set(incident.settings.keys)
        incident.settingChanges = AppearancePreference.shared.history?.snapshot().events.filter { contextKeys.contains($0.key) }.suffix(5).compactMap {
            let change = IncidentSettingChange(key: $0.key, before: $0.oldValue, after: $0.newValue, date: $0.date)
            return change.isValid ? change : nil
        } ?? []
        if source == .app, [.quickLook, .images, .previewLimit, .previewLimitBeyondApp].contains(kind) {
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
           [.quickLook, .images, .previewLimit, .previewLimitBeyondApp, .fileRead].contains(draft.incident.kind),
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
            request.review = review; request.includeDocument = draft.includeDocument
            if review, draft.includeDocument, let document = draft.materialContext?.document {
                let transfer = IncidentDocumentTransfer(request: request, document: document, sample: draft.materialContext?.sample, displayName: draft.documentName.replacingOccurrences(of: "\\", with: "_"))
                guard let data = try? JSONEncoder().encode(transfer), IncidentDocumentTransfer.decode(data) != nil else {
                    pending.remove(draft.incident.id); failure?(draft); return
                }
                SearchLaunchClient.reportDocumentError(data) { success in
                    pending.remove(draft.incident.id)
                    if !success { failure?(draft) }
                }
                return
            }
            guard let data = try? JSONEncoder().encode(request), data.count <= 16384 else {
                pending.remove(draft.incident.id); failure?(draft); return
            }
            SearchLaunchClient.reportError(data) { success in
                pending.remove(draft.incident.id)
                if !success { failure?(draft) }
            }
        } else {
            if review { pending.remove(draft.incident.id); showDraft(draft); return }
            reportPrepared?(draft.incident)
            let opened = openURL(draft.incident.feedbackURL(includeDiagnostics: draft.includeDiagnostics, notes: draft.notes, attachment: draft.includeDocument && draft.shareAttachment ? draft.uploadedAttachment : nil, attachmentReference: draft.includeDocument && !draft.shareAttachment ? draft.uploadedAttachmentReference : nil))
            // Keep the same draft reachable even if the browser later fails to load/sign in.
            if !opened { if let failure { failure(draft) } else { showDraft(draft, failed: true) } }
            else {
                windows[draft.incident.id]?.updateStatus(failed: false)
                if var job = try? FeedbackAttachmentJob.load(draft.incident.id) { job.opened = true; try? job.save() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { pending.remove(draft.incident.id) }
        }
    }

    static func receive(_ url: URL) -> Bool {
        guard url.scheme == "markdownpreview", url.host == "report-error" else { return false }
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              items.count == 1, items[0].name == "payload", let value = items[0].value, value.utf8.count <= 24000,
              let data = Data(base64Encoded: value), let request = IncidentFeedbackRequest.decode(data) else { return true }
        let draft = IncidentDraft(request.incident)
        draft.includeDiagnostics = request.includeDiagnostics; draft.notes = request.notes; draft.includeDocument = request.includeDocument ?? true
        if let token = request.transferToken,
           let transfer = try? IncidentDocumentTransfer.consume(token: token), transfer.request.incident.id == request.incident.id {
            draft.materialContext = FeedbackMaterialContext(document: transfer.document, sample: transfer.sample, originalURL: nil, provenance: "captured-quicklook-render-input", displayName: transfer.displayName)
        }
        if request.materialReview == true {
            if draft.materialContext == nil { draft.materialContext = FeedbackMaterialContext(document: nil, sample: request.sample, originalURL: nil, provenance: "user-reviewed-fragment") }
            materialPresenter?(draft)
            return true
        }
        if request.followUp == true { showFollowUp?(); return true }
        report(draft, review: request.review)
        return true
    }

    static func prepareMaterials(_ draft: IncidentDraft) {
        if Bundle.main.bundleIdentifier != "com.xykong.Markdown.QuickLook" { materialPresenter?(draft); return }
        let alert = NSAlert()
        alert.messageText = text("Attach Reproduction Materials…")
        alert.informativeText = text("Continue in FluxMarkdown to choose what to share. The displayed fragment will be passed to FluxMarkdown only if you continue. Nothing is uploaded yet.")
        if let sample = draft.materialContext?.sample {
            let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 500, height: 160))
            let view = NSTextView(frame: scroll.bounds); view.string = sample; view.isEditable = false
            scroll.documentView = view; scroll.hasVerticalScroller = true; alert.accessoryView = scroll
        }
        alert.addButton(withTitle: text("Continue in FluxMarkdown")); alert.addButton(withTitle: text("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        var request = IncidentFeedbackRequest(incident: draft.incident, includeDiagnostics: draft.includeDiagnostics, notes: String(draft.notes.prefix(600)))
        request.materialReview = true; request.sample = draft.materialContext?.sample
        guard let data = try? JSONEncoder().encode(request) else { showDraft(draft, failed: true); return }
        SearchLaunchClient.reportError(data) { success in if !success { showDraft(draft, failed: true) } }
    }
    static func openFollowUp(_ incident: ErrorIncident) {
        if Bundle.main.bundleIdentifier != "com.xykong.Markdown.QuickLook" { showFollowUp?(); return }
        var request = IncidentFeedbackRequest(incident: incident, includeDiagnostics: false, notes: "")
        request.followUp = true
        guard let data = try? JSONEncoder().encode(request) else { return }
        SearchLaunchClient.reportError(data) { success in if !success { showDraft(IncidentDraft(incident), failed: true) } }
    }

    static func present(_ incident: ErrorIncident, recoveryTitle: String? = nil, recovery: (() -> Void)? = nil) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { present(incident, recoveryTitle: recoveryTitle, recovery: recovery) }; return
        }
        let draft = IncidentDraft(incident), alert = NSAlert()
        alert.messageText = text(incident.kind.title)
        alert.informativeText = text(incident.guidance)
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
        draft.prepareDefaultContent()
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
        addArrangedSubview(ErrorActionButton(title: ErrorFeedback.text("Attach Reproduction Materials…")) { ErrorFeedback.prepareMaterials(draft) })
        if Bundle.main.bundleIdentifier != "com.xykong.Markdown.QuickLook" {
            let follow = NSButton(checkboxWithTitle: ErrorFeedback.text("Check my submitted Issues for replies"), target: self, action: #selector(toggleFollow(_:)))
            follow.state = ErrorFeedback.followRepliesEnabled?() == false ? .off : .on; addArrangedSubview(follow)
        }
        info.widthAnchor.constraint(equalToConstant: 420).isActive = true
    }
    required init?(coder: NSCoder) { nil }
    @objc private func toggleFollow(_ sender: NSButton) { ErrorFeedback.setFollowReplies?(sender.state == .on) }
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
    var failureKind: FailureKind { draft.incident.kind }
    private let draft: IncidentDraft
    private let recovery: (() -> Void)?
    private var buttonStack: NSStackView?
    override var wantsUpdateLayer: Bool { true }
    /// A CGColor is fixed when it is made; resolve it in this view's appearance, again whenever that changes.
    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance { layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor }
    }
    init(incident: ErrorIncident, guidance: String? = nil, recoveryTitle: String? = nil, recovery: (() -> Void)? = nil) {
        draft = IncidentDraft(incident); self.recovery = recovery
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(ErrorFeedback.text(incident.kind.title))
        wantsLayer = true; layer?.cornerRadius = 8
        let message = NSTextField(wrappingLabelWithString: ErrorFeedback.text(incident.kind.title) + ". " + ErrorFeedback.text(guidance ?? incident.guidance))
        let buttons = NSStackView(); buttons.orientation = .horizontal; buttons.spacing = 8
        buttonStack = buttons
        if let recoveryTitle, recovery != nil { buttons.addArrangedSubview(NSButton(title: ErrorFeedback.text(recoveryTitle), target: self, action: #selector(recover))) }
        let reportButton = NSButton(title: ErrorFeedback.text("Report This Problem"), target: self, action: #selector(report))
        let reportHelp = ErrorFeedback.text("Opens GitHub with this error and system information. You confirm publication there.")
        reportButton.toolTip = reportHelp
        reportButton.setAccessibilityHelp(reportHelp)
        buttons.addArrangedSubview(reportButton)

        let options = NSPopUpButton(frame: .zero, pullsDown: true)
        let optionsTitle = ErrorFeedback.text("Feedback Options")
        options.addItem(withTitle: optionsTitle)
        options.setAccessibilityLabel(optionsTitle)
        options.toolTip = ErrorFeedback.disclosure
        options.setAccessibilityHelp(ErrorFeedback.disclosure)
        for (title, action) in [("Review Feedback…", #selector(review)),
                                ("Attach Reproduction Materials…", #selector(prepareMaterials)),
                                ("My Feedback", #selector(openFollowUp))] {
            let item = NSMenuItem(title: ErrorFeedback.text(title), action: action, keyEquivalent: "")
            item.target = self
            options.menu?.addItem(item)
        }
        buttons.addArrangedSubview(options)
        buttons.addArrangedSubview(NSButton(title: ErrorFeedback.text("Close"), target: self, action: #selector(close)))
        let content = NSStackView(views: [message, buttons])
        content.orientation = .vertical; content.alignment = .leading; content.spacing = 6; content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        message.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
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
    @objc private func prepareMaterials() { ErrorFeedback.prepareMaterials(draft) }
    @objc private func openFollowUp() { ErrorFeedback.openFollowUp(draft.incident) }
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
    static func attach(to view: NSView, incident: ErrorIncident, guidance: String? = nil, recoveryTitle: String? = nil, recovery: (() -> Void)? = nil) {
        for existing in view.subviews.compactMap({ $0 as? IncidentNotice }) { existing.removeFromSuperview() }
        let notice = IncidentNotice(incident: incident, guidance: guidance, recoveryTitle: recoveryTitle, recovery: recovery)
        notice.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(notice)
        NSLayoutConstraint.activate([notice.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12), notice.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12), notice.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)])
    }
}

final class IncidentReportWindow: NSWindowController, NSWindowDelegate {
    let draft: IncidentDraft
    var attachmentClient: () -> FeedbackAttachmentClient = { FeedbackAttachmentClient() }
    var openFeedback: (IncidentDraft) -> Void = { ErrorFeedback.report($0) }
    private let notes = NSTextView()
    private let details = NSTextView()
    private let technical = NSStackView()
    private let failureActions = NSStackView()
    private let attachmentInfo = NSTextField(wrappingLabelWithString: "")
    private let includeFile = NSButton(checkboxWithTitle: ErrorFeedback.text("Include current document"), target: nil, action: nil)
    private let revealFile = NSButton(title: ErrorFeedback.text("Review Attachment…"), target: nil, action: nil)
    private let shareFile = NSButton(checkboxWithTitle: ErrorFeedback.text("Share attachment download link publicly"), target: nil, action: nil)
    private var preparingAttachment = false
    private var uploadTask: Task<Void, Never>?
    private let submit = NSButton()
    private let deleteAttachment = NSButton()
    private var continueWhenReady = false
    private var isClosed = false
    private let status = NSTextField(wrappingLabelWithString: "")
    var onClose: (() -> Void)?
    init(draft: IncidentDraft) {
        self.draft = draft
        draft.prepareDefaultContent()
        let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 580, height: 700), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        super.init(window: window); window.delegate = self; window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false; window.isFloatingPanel = false
        window.title = ErrorFeedback.text("Report This Problem"); window.minSize = NSSize(width: 540, height: 700)
        let content = NSStackView(); content.orientation = .vertical; content.alignment = .leading; content.spacing = 12; content.translatesAutoresizingMaskIntoConstraints = false
        let heading = NSTextField(wrappingLabelWithString: ErrorFeedback.text(draft.incident.kind.title)); heading.font = .boldSystemFont(ofSize: 16)
        content.addArrangedSubview(heading)
        let guidance = NSTextField(wrappingLabelWithString: ErrorFeedback.text(draft.incident.guidance)); guidance.textColor = .secondaryLabelColor
        content.addArrangedSubview(guidance)
        content.addArrangedSubview(NSTextField(labelWithString: ErrorFeedback.text("Feedback description")))
        var scrollViews: [NSScrollView] = []
        func scroll(_ view: NSTextView, height: CGFloat) -> NSScrollView {
            let scroll = NSScrollView(); scroll.documentView = view; scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
            view.isRichText = false; view.isVerticallyResizable = true; view.autoresizingMask = [.width]; view.textContainer?.widthTracksTextView = true
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: height).isActive = true
            scrollViews.append(scroll)
            return scroll
        }
        notes.string = draft.notes; notes.setAccessibilityLabel(ErrorFeedback.text("Feedback description"))
        content.addArrangedSubview(scroll(notes, height: 100))
        includeFile.target = self; includeFile.action = #selector(toggleDocument(_:)); includeFile.state = draft.includeDocument ? .on : .off
        content.addArrangedSubview(includeFile)
        shareFile.target = self; shareFile.action = #selector(toggleSharing(_:)); shareFile.state = draft.shareAttachment ? .on : .off; shareFile.isEnabled = draft.includeDocument
        content.addArrangedSubview(shareFile)
        attachmentInfo.font = .systemFont(ofSize: 11); attachmentInfo.textColor = .secondaryLabelColor; attachmentInfo.isSelectable = true
        content.addArrangedSubview(attachmentInfo)
        let attachmentActions = NSStackView()
        revealFile.target = self; revealFile.action = #selector(reviewAttachment); revealFile.isEnabled = false
        attachmentActions.addArrangedSubview(revealFile)
        attachmentActions.addArrangedSubview(NSButton(title: ErrorFeedback.text("Choose Another Document…"), target: self, action: #selector(chooseDocument)))
        deleteAttachment.title = ErrorFeedback.text("Delete Uploaded Attachment"); deleteAttachment.target = self; deleteAttachment.action = #selector(revokeAttachment); deleteAttachment.isHidden = (try? FeedbackAttachmentJob.load(draft.incident.id)) == nil
        content.addArrangedSubview(attachmentActions)
        content.addArrangedSubview(deleteAttachment)
        let sharing = NSTextField(wrappingLabelWithString: ErrorFeedback.text("Attachments go to FluxMarkdown (t.xykong.cc), privately by default. Only maintainers can retrieve private files; GitHub shows a reference only. Enable public sharing to publish a download link. Unlinked files expire in 7 days; private files within 30 days. You can delete uploaded files here.")); sharing.font = .systemFont(ofSize: 11); sharing.textColor = .secondaryLabelColor
        content.addArrangedSubview(sharing); sharing.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        let disclosure = NSButton(title: "▸ " + ErrorFeedback.text("Diagnostic report"), target: self, action: #selector(toggleTechnical(_:)))
        disclosure.setButtonType(.pushOnPushOff); disclosure.bezelStyle = .inline; disclosure.setAccessibilityValue("collapsed")
        content.addArrangedSubview(disclosure)
        technical.orientation = .vertical; technical.alignment = .leading; technical.spacing = 8
        let include = NSButton(checkboxWithTitle: ErrorFeedback.text("Include diagnostics"), target: self, action: #selector(toggle(_:))); include.state = draft.includeDiagnostics ? .on : .off
        technical.addArrangedSubview(include)
        details.string = draft.incident.report; details.isEditable = false; details.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        technical.addArrangedSubview(scroll(details, height: 160)); technical.isHidden = true
        content.addArrangedSubview(technical)
        status.font = .systemFont(ofSize: 11); status.textColor = .secondaryLabelColor; status.isSelectable = true
        content.addArrangedSubview(status)
        for (title, action) in [("Copy Report", #selector(copyReport)), ("Save Report…", #selector(saveReport))] {
            failureActions.addArrangedSubview(NSButton(title: ErrorFeedback.text(title), target: self, action: action))
        }
        failureActions.isHidden = true; content.addArrangedSubview(failureActions)
        let actions = NSStackView(); actions.spacing = 10
        let cancel = NSButton(title: ErrorFeedback.text("Cancel"), target: self, action: #selector(dismiss)); cancel.keyEquivalent = "\u{1b}"
        submit.title = ErrorFeedback.text(draft.includeDocument ? "Upload Attachment and Continue…" : "Continue Without Attachment…"); submit.target = self; submit.action = #selector(openPage); submit.keyEquivalent = "\r"
        actions.addArrangedSubview(cancel); actions.addArrangedSubview(submit); content.addArrangedSubview(actions)
        for text in [heading, guidance, status, attachmentInfo] { text.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true }
        window.contentView!.addSubview(content)
        for scroll in scrollViews { scroll.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true }
        NSLayoutConstraint.activate([content.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24), content.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24), content.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 20), content.bottomAnchor.constraint(lessThanOrEqualTo: window.contentView!.bottomAnchor, constant: -20)])
        window.initialFirstResponder = notes; window.center()
        prepareAttachment()
    }
    required init?(coder: NSCoder) { nil }
    func updateStatus(failed: Bool) {
        failureActions.isHidden = !failed
        status.stringValue = ErrorFeedback.text(failed ? "The feedback page could not be opened. Copy or save this report and try again later." : "Opens GitHub with this error and system information. You confirm publication there.")
    }
    @objc private func toggleTechnical(_ sender: NSButton) {
        technical.isHidden = sender.state != .on; sender.title = (technical.isHidden ? "▸ " : "▾ ") + ErrorFeedback.text("Diagnostic report"); sender.setAccessibilityValue(technical.isHidden ? "collapsed" : "expanded")
        if !technical.isHidden, let window { var frame = window.frame; frame.size.height = max(frame.height, 860); window.setFrame(frame, display: true) }
    }
    @objc private func toggle(_ sender: NSButton) { draft.includeDiagnostics = sender.state == .on; prepareAttachment() }
    @objc private func dismiss() { window?.close() }
    private func prepareAttachment(continueToGitHub: Bool = false) {
        guard uploadTask == nil else { return }
        submit.title = ErrorFeedback.text(draft.includeDocument ? "Upload Attachment and Continue…" : "Continue Without Attachment…")
        shareFile.isEnabled = draft.includeDocument
        guard draft.includeDocument else { draft.uploadedAttachment = nil; draft.uploadedAttachmentReference = nil; attachmentInfo.stringValue = ErrorFeedback.text("Document excluded."); revealFile.isEnabled = false; if continueToGitHub { openFeedback(draft) }; return }
        if draft.restoredUpload, let job = try? FeedbackAttachmentJob.load(draft.incident.id),
           job.document == draft.materialContext?.document, job.notes == notes.string,
           job.includeDiagnostics == draft.includeDiagnostics, (job.sharePublic ?? false) == draft.shareAttachment, FileManager.default.fileExists(atPath: job.zip.path) {
            draft.attachmentURL = job.zip; draft.attachmentFingerprint = job.fingerprint
            attachmentInfo.stringValue = draft.documentName + " · " + ErrorFeedback.text(job.receipt == nil ? "ZIP ready locally; not uploaded." : "A previous upload is saved. Continue to verify its receipt.")
            revealFile.isEnabled = true
            if continueToGitHub { uploadAttachment(job.zip) }; return
        }
        if preparingAttachment { continueWhenReady = continueWhenReady || continueToGitHub; return }
        preparingAttachment = true; continueWhenReady = continueToGitHub; revealFile.isEnabled = false
        attachmentInfo.stringValue = ErrorFeedback.text("Preparing current document…")
        draft.notes = notes.string
        let snapshot = IncidentDraft(draft.incident)
        snapshot.notes = draft.notes; snapshot.includeDiagnostics = draft.includeDiagnostics
        snapshot.materialContext = draft.materialContext; snapshot.attachmentResources = draft.attachmentResources
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = Result { try snapshot.prepareDocumentAttachment() }
            DispatchQueue.main.async {
                guard let self, !self.isClosed else { return }
                self.preparingAttachment = false
                let shouldContinue = self.continueWhenReady; self.continueWhenReady = false
                guard self.draft.includeDocument else {
                    self.attachmentInfo.stringValue = ErrorFeedback.text("Document excluded."); self.revealFile.isEnabled = false
                    if shouldContinue { self.openFeedback(self.draft) }; return
                }
                if self.draft.materialContext?.document != snapshot.materialContext?.document || self.draft.attachmentResources != snapshot.attachmentResources || self.draft.includeDiagnostics != snapshot.includeDiagnostics || (shouldContinue && self.notes.string != snapshot.notes) {
                    self.prepareAttachment(continueToGitHub: shouldContinue); return
                }
                switch result {
                case .success(let url):
                    self.draft.attachmentURL = url; self.draft.attachmentFingerprint = snapshot.attachmentFingerprint
                    self.attachmentInfo.stringValue = self.draft.documentName + " · " + ErrorFeedback.text("ZIP ready locally; not uploaded.")
                    self.revealFile.isEnabled = true
                    if shouldContinue { self.uploadAttachment(url) }
                case .failure:
                    self.attachmentInfo.stringValue = ErrorFeedback.text("Current document unavailable. Choose a document or uncheck its attachment to continue.")
                    self.revealFile.isEnabled = false
                }
            }
        }
    }
    private func uploadAttachment(_ url: URL) {
        guard uploadTask == nil else { return }
        draft.notes = notes.string
        let job: FeedbackAttachmentJob
        do { job = try FeedbackAttachmentJob.prepare(draft, zip: url) }
        catch { status.stringValue = ErrorFeedback.text("Could not prepare upload. Delete the previous uploaded attachment before changing it, or exclude the file to continue."); return }
        submit.isEnabled = false; includeFile.isEnabled = false; shareFile.isEnabled = false; deleteAttachment.isHidden = false
        attachmentInfo.stringValue = ErrorFeedback.text("Uploading and verifying attachment…")
        uploadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.uploadTask = nil; self.submit.isEnabled = true; self.includeFile.isEnabled = true; self.shareFile.isEnabled = self.draft.includeDocument }
            do {
                let bytes = try Data(contentsOf: job.zip)
                let receipt = try await self.attachmentClient().upload(bytes, incident: job.incident.id, key: job.key, sharePublic: job.sharePublic ?? false)
                var saved = job; saved.receipt = receipt; try saved.save()
                self.deleteAttachment.isHidden = false
                guard !self.isClosed, !Task.isCancelled else { return }
                // Never open a form with stale text, selection or diagnostics after a long upload.
                guard self.draft.includeDocument, self.draft.materialContext?.document == job.document,
                      self.notes.string == job.notes, self.draft.includeDiagnostics == job.includeDiagnostics, self.draft.shareAttachment == (job.sharePublic ?? false) else {
                    self.status.stringValue = ErrorFeedback.text("Attachment uploaded. Your edits changed; delete the uploaded attachment before replacing it, or continue without a file."); return
                }
                self.draft.uploadedAttachment = receipt.url
                self.draft.uploadedAttachmentReference = receipt.visibility == "private" ? receipt.reference : nil
                self.attachmentInfo.stringValue = ErrorFeedback.text(receipt.visibility == "private" ? "Attachment submitted privately; only maintainers can retrieve it." : "Attachment uploaded and download verified.")
                self.openFeedback(self.draft)
            } catch {
                guard !self.isClosed else { return }
                self.status.stringValue = ErrorFeedback.text("Attachment upload or verification failed. Your draft is saved. Retry, or uncheck the attachment to continue.")
            }
        }
    }
    @objc private func revokeAttachment() {
        guard uploadTask == nil, let job = try? FeedbackAttachmentJob.load(draft.incident.id) else { return }
        submit.isEnabled = false
        uploadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.uploadTask = nil; self.submit.isEnabled = true }
            do {
                let client = self.attachmentClient()
                let receipt: FeedbackAttachmentReceipt?
                if let saved = job.receipt { receipt = saved }
                else { receipt = try await client.lookup(Data(contentsOf: job.zip), key: job.key) }
                if let receipt { try await client.delete(receipt) }
                try FileManager.default.removeItem(at: job.folder)
                self.draft.uploadedAttachment = nil; self.draft.uploadedAttachmentReference = nil; self.deleteAttachment.isHidden = true
                self.attachmentInfo.stringValue = ErrorFeedback.text("Uploaded attachment deleted.")
            } catch { self.status.stringValue = ErrorFeedback.text("Could not delete attachment. Keep this window and retry.") }
        }
    }
    @objc private func toggleSharing(_ sender: NSButton) {
        guard uploadTask == nil else { sender.state = draft.shareAttachment ? .on : .off; return }
        draft.shareAttachment = sender.state == .on
        draft.uploadedAttachment = nil; draft.uploadedAttachmentReference = nil
        prepareAttachment()
    }
    @objc private func toggleDocument(_ sender: NSButton) { draft.includeDocument = sender.state == .on; prepareAttachment() }
    @objc private func reviewAttachment() { if let url = draft.attachmentURL { NSWorkspace.shared.activateFileViewerSelecting([url]) } }
    @objc private func chooseDocument() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false; panel.allowedFileTypes = ["md", "markdown", "mdx", "txt", "tsv"]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let snapshot = try FeedbackReproduction.document(url)
            draft.materialContext = .captured(document: snapshot.source, url: url, first: nil, last: nil)
            draft.includeDocument = true; draft.restoredUpload = false; draft.attachmentResources = []; includeFile.state = .on; prepareAttachment()
        } catch { attachmentInfo.stringValue = ErrorFeedback.text("Could not read this document within the 20 MB limit. Choose another file or paste a smaller sample.") }
    }
    @objc private func openPage() { draft.notes = notes.string; prepareAttachment(continueToGitHub: true) }
    @objc private func copyReport() { draft.notes = notes.string; NSPasteboard.general.clearContents(); NSPasteboard.general.setString(draft.report, forType: .string) }
    @objc private func saveReport() {
        draft.notes = notes.string
        let panel = NSSavePanel(); panel.nameFieldStringValue = "FluxMarkdown-report.md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try draft.report.write(to: url, atomically: true, encoding: .utf8) }
        catch { status.stringValue = ErrorFeedback.text("Could not save the report. You can copy it instead.") }
    }
    func windowWillClose(_ notification: Notification) { isClosed = true; uploadTask?.cancel(); draft.notes = notes.string; onClose?() }
}

final class RendererErrorRegistry {
    var onFailure: ((IncidentDraft) -> Void)?
    var onRecover: ((ErrorIncident) -> Void)?
    private(set) var scope = UUID()
    private var incidents: [String: ErrorIncident] = [:]
    var sourceContext: (() -> (String, URL?)?)?
    private var contexts: [String: FeedbackMaterialContext] = [:]
    func beginDocument() -> String { scope = UUID(); incidents.removeAll(); contexts.removeAll(); sourceContext = nil; return scope.uuidString }
    func nativeFailure(_ kind: FailureKind, error: Error? = nil, renderingBlocker: FailureKind? = nil) -> ErrorIncident {
        let key = "native:" + kind.rawValue + ":" + (renderingBlocker?.rawValue ?? "none")
        let codes = ErrorIncident(kind: kind, source: .app, error: error).codes
        if let existing = incidents[key], existing.codes == codes { return existing }
        let incident = ErrorFeedback.capture(kind, error: error, scope: scope, renderingBlocker: renderingBlocker)
        incidents[key] = incident
        return incident
    }
    func receive(_ body: [String: Any]) -> (incident: ErrorIncident, action: String)? {
        guard Set(body.keys).isSubset(of: Set(["action", "kind", "generation", "id", "reason", "lineStart", "lineEnd"])),
              let action = body["action"] as? String, ["record", "report", "inspect", "recover", "materials", "followUp"].contains(action),
              let generation = body["generation"] as? String, generation == scope.uuidString,
              let id = body["id"] as? String, id.utf8.count <= 32, !id.isEmpty, id.allSatisfy(\.isNumber),
              let rawKind = body["kind"] as? String, let kind = FailureKind(rawValue: rawKind),
              [.renderer, .source, .mermaid, .typst, .graphviz, .vega, .math, .search, .images, .copy].contains(kind) else { return nil }
        if body["lineStart"] != nil || body["lineEnd"] != nil {
            guard let first = body["lineStart"] as? Int, let last = body["lineEnd"] as? Int,
                  first > 0, first <= 1_000_000, last >= first, last <= 1_000_000, last - first < 100 else { return nil }
        }
        let reason: IncidentReason?
        if let raw = body["reason"] {
            guard let value = raw as? String, let parsed = IncidentReason(rawValue: value) else { return nil }
            reason = parsed
        } else { reason = nil }
        if action == "record" {
            if incidents[id] == nil {
                guard incidents.count < 100 else { return nil }
                incidents[id] = ErrorFeedback.capture(kind, scope: scope, reason: reason)
                if let (document, url) = sourceContext?() {
                    let first = body["lineStart"] as? Int, last = body["lineEnd"] as? Int
                    contexts[id] = FeedbackMaterialContext.captured(document: document, url: url, first: first, last: last)
                }
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
        let draft = IncidentDraft(event.incident)
        if let id = body["id"] as? String { draft.materialContext = contexts[id] }
        if event.action == "report" { ErrorFeedback.report(draft, failure: failure) }
        if event.action == "inspect" { ErrorFeedback.report(draft, review: true, failure: failure) }
        if event.action == "materials" { ErrorFeedback.prepareMaterials(draft) }
        if event.action == "followUp" { ErrorFeedback.openFollowUp(event.incident) }
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
    var recoverySuggestion: String? { ErrorFeedback.text(incident.guidance) + "\n\n" + ErrorFeedback.disclosure }
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
