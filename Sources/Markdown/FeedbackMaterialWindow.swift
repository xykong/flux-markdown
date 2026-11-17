import AppKit

/// Optional content-sharing UI. Nothing is uploaded by package preparation.
final class FeedbackMaterialWindow: NSWindowController, NSWindowDelegate {
    private static var retained: [UUID: FeedbackMaterialWindow] = [:]
    private let draft: IncidentDraft
    private let source = NSTextView()
    private let mode = NSPopUpButton()
    private let include = NSButton(checkboxWithTitle: ErrorFeedback.text("Include diagnostics"), target: nil, action: nil)
    private let status = NSTextField(wrappingLabelWithString: "")
    private let files = NSTextField(wrappingLabelWithString: "")
    private var originalURL: URL?
    private var resources: [URL] = []
    private var packageURL: URL?
    private var provenance = "user-edited-sample"
    private var editedFragment: String?
    private var editedDocument: String?
    private var previousMode = 0
    static func show(_ draft: IncidentDraft) {
        if let existing = retained[draft.incident.id] { existing.showWindow(nil); existing.window?.makeKeyAndOrderFront(nil); return }
        if retained.count >= 20, let victim = retained.first(where: { $0.value.window?.isVisible != true })?.key { retained.removeValue(forKey: victim) }
        let controller = FeedbackMaterialWindow(draft); retained[draft.incident.id] = controller
        controller.showWindow(nil); NSApp.activate(ignoringOtherApps: true); controller.window?.makeKeyAndOrderFront(nil)
    }
    init(_ draft: IncidentDraft) {
        self.draft = draft
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 780), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        super.init(window: window); window.delegate = self; window.minSize = NSSize(width: 780, height: 780); window.title = ErrorFeedback.text("Attach Reproduction Materials…"); window.isReleasedWhenClosed = false
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10; stack.translatesAutoresizingMaskIntoConstraints = false
        let disclosure = NSTextField(wrappingLabelWithString: ErrorFeedback.text("Choose a sample or the complete document. Contents and selected resources may be public on GitHub. Review them before attaching. Creating a ZIP does not upload it."))
        stack.addArrangedSubview(disclosure)
        disclosure.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        mode.addItems(withTitles: [ErrorFeedback.text("Failed fragment"), ErrorFeedback.text("Complete document")]); mode.target = self; mode.action = #selector(changeMaterialMode)
        stack.addArrangedSubview(mode)
        let choose = NSButton(title: ErrorFeedback.text("Choose Document…"), target: self, action: #selector(chooseDocument)); stack.addArrangedSubview(choose)
        let scroll = NSScrollView(); scroll.documentView = source; scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        source.isRichText = false; source.isVerticallyResizable = true; source.autoresizingMask = [.width]; source.textContainer?.widthTracksTextView = true
        source.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        source.setAccessibilityLabel(ErrorFeedback.text("Reproduction content"))
        source.string = draft.materialContext?.document ?? draft.materialContext?.sample ?? ""
        if draft.materialContext?.document != nil { mode.selectItem(at: 1); previousMode = 1 }
        stack.addArrangedSubview(scroll); scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 230).isActive = true; scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        include.state = draft.includeDiagnostics ? .on : .off; stack.addArrangedSubview(include)
        let resourceActions = NSStackView(views: [NSButton(title: ErrorFeedback.text("Choose Referenced Resources…"), target: self, action: #selector(chooseResources)), NSButton(title: ErrorFeedback.text("Remove Resources"), target: self, action: #selector(removeResources))]); stack.addArrangedSubview(resourceActions)
        files.isSelectable = true; stack.addArrangedSubview(files); status.isSelectable = true; stack.addArrangedSubview(status)
        let actions = NSStackView(views: [NSButton(title: ErrorFeedback.text("Save Reproduction ZIP…"), target: self, action: #selector(saveZIP)), NSButton(title: ErrorFeedback.text("Show ZIP in Finder"), target: self, action: #selector(showZIP)), NSButton(title: ErrorFeedback.text("Open Feedback Page"), target: self, action: #selector(openPage))]); actions.orientation = .vertical; actions.alignment = .leading; stack.addArrangedSubview(actions)
        let instructions = NSTextField(wrappingLabelWithString: ErrorFeedback.text("Attach the ZIP on GitHub by dragging it from Finder. GitHub uploads attachments immediately; you publish the Issue there. No attachment is required to report."))
        stack.addArrangedSubview(instructions); instructions.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -20), stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 20), stack.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -20)])
        originalURL = draft.materialContext?.originalURL
        provenance = draft.materialContext?.provenance ?? "user-edited-sample"
        updateFiles(); window.center()
    }
    required init?(coder: NSCoder) { nil }
    @objc private func changeMaterialMode() {
        if previousMode == 0 { editedFragment = source.string } else { editedDocument = source.string }
        resources = []; packageURL = nil
        if mode.indexOfSelectedItem == 1 {
            if let context = draft.materialContext, let full = editedDocument ?? context.document {
                source.string = full; originalURL = context.originalURL; provenance = context.provenance
            } else {
                mode.selectItem(at: 0)
                chooseDocument()
            }
        } else { source.string = editedFragment ?? draft.materialContext?.sample ?? ""; provenance = "user-edited-sample" }
        previousMode = mode.indexOfSelectedItem
        updateFiles()
    }
    @objc private func chooseDocument() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.allowedFileTypes = ["md", "markdown", "mdown", "mdx", "txt", "tsv"]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let snapshot = try FeedbackReproduction.document(url)
            source.string = snapshot.source; originalURL = url; resources = []; packageURL = nil
            provenance = "selected-at-report-time"; mode.selectItem(at: 1); previousMode = 1; editedDocument = snapshot.source
            status.stringValue = ErrorFeedback.text("This is the file selected now, not a verified snapshot from the failure."); updateFiles()
        } catch { status.stringValue = ErrorFeedback.text("Could not read this document within the 20 MB limit. Choose another file or paste a smaller sample.") }
    }
    @objc private func chooseResources() {
        guard originalURL != nil else { status.stringValue = ErrorFeedback.text("Choose a document first to resolve its referenced resources."); return }
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = true; panel.canChooseDirectories = false; panel.directoryURL = originalURL?.deletingLastPathComponent()
        guard panel.runModal() == .OK else { return }
        do {
            _ = try FeedbackReproduction.prepare(source: source.string, mode: "document", diagnostics: "", incident: draft.incident.id, originalURL: originalURL, resources: panel.urls)
            resources = panel.urls; packageURL = nil; updateFiles()
        } catch { status.stringValue = ErrorFeedback.text("Select only files referenced by this document inside its folder, without symbolic links, within the 20 MB limit.") }
    }
    @objc private func removeResources() { resources = []; packageURL = nil; updateFiles() }
    private func updateFiles() {
        files.stringValue = ErrorFeedback.text("Selected resources:") + " " + (resources.isEmpty ? "0" : resources.map(\.lastPathComponent).joined(separator: ", "))
    }
    @objc private func saveZIP() {
        do {
            let package = try FeedbackReproduction.prepare(source: source.string, mode: mode.indexOfSelectedItem == 1 ? "document" : "sample", diagnostics: include.state == .on ? draft.report : "", incident: draft.incident.id, originalURL: originalURL, resources: resources, provenance: provenance + "-reviewable-editable-copy")
            let summary = package.entries.map { "\($0.name) · \($0.data.count) bytes" }.joined(separator: "\n")
            let alert = NSAlert(); alert.messageText = ErrorFeedback.text("Review Package Contents")
            alert.informativeText = summary + "\n\n" + ErrorFeedback.text("References not included:") + " \(package.missing.count)\n" + package.missing.joined(separator: "\n")
            alert.addButton(withTitle: ErrorFeedback.text("Save Reproduction ZIP…")); alert.addButton(withTitle: ErrorFeedback.text("Cancel"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            let panel = NSSavePanel(); panel.nameFieldStringValue = "FluxMarkdown-reproduction.zip"; panel.allowedFileTypes = ["zip"]
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try package.writeZIP(to: url); packageURL = url
            status.stringValue = ErrorFeedback.text("ZIP prepared locally. Attach it on GitHub; it has not been uploaded.")
        } catch { status.stringValue = ErrorFeedback.text("Could not prepare the ZIP. Remove resources, use a smaller sample, or choose another save location. Your report is preserved.") }
    }
    @objc private func showZIP() {
        guard let url = packageURL, FileManager.default.fileExists(atPath: url.path) else { status.stringValue = ErrorFeedback.text("Save a ZIP first, then attach it from Finder."); return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    @objc private func openPage() { draft.includeDiagnostics = include.state == .on; ErrorFeedback.report(draft) }
}
