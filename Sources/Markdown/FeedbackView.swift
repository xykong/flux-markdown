import SwiftUI
import AppKit

private func feedbackText(_ key: String) -> String {
    NSLocalizedString(key, comment: "Feedback interface")
}

final class FeedbackWindowController {
    static let shared = FeedbackWindowController()
    private var window: NSWindow?

    func show() {
        if let window, window.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 740),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = feedbackText("Report an Issue")
        window.contentView = NSHostingView(rootView: FeedbackView(close: { [weak window] in window?.close() }))
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func showFeatureFallback() {
        let alert = NSAlert()
        alert.messageText = feedbackText("Could not open the browser. Copy the report or save it and try again.")
        alert.informativeText = FeedbackIssueLink.feature.absoluteString
        alert.addButton(withTitle: feedbackText("Copy Link"))
        alert.addButton(withTitle: feedbackText("Cancel"))
        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(FeedbackIssueLink.feature.absoluteString, forType: .string)
        }
    }
}

struct FeedbackView: View {
    let close: () -> Void
    @State private var includeDiagnostics = true
    @State private var notes = ""
    @State private var diagnostics = ""
    @State private var status = ""
    @State private var clearConfirmation = false

    private var fullReport: String {
        notes + (includeDiagnostics ? "\n\n" + diagnostics : "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(feedbackText("Report an Issue")).font(.title2).bold()
            Text(feedbackText("Review your report before continuing. The summary will be sent to GitHub; submitted issues are public."))
                .font(.callout).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            Text(feedbackText("What happened? Include steps to reproduce and what you expected."))
                .font(.headline)
            TextEditor(text: $notes)
                .font(.system(size: 13)).frame(height: 95)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(NSColor.separatorColor)))
                .accessibilityLabel(feedbackText("Problem description"))
            Toggle(feedbackText("Include diagnostics and recent settings changes"), isOn: $includeDiagnostics)
            Text(feedbackText("Stored locally: the latest 200 settings changes, without time expiration. Document contents and file paths are excluded."))
                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            TextEditor(text: $diagnostics)
                .font(.system(size: 11, design: .monospaced))
                .frame(minHeight: 240)
                .disabled(!includeDiagnostics)
                .opacity(includeDiagnostics ? 1 : 0.5)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(NSColor.separatorColor)))
                .accessibilityLabel(feedbackText("Diagnostic report"))
            if !status.isEmpty {
                Text(status).font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button(feedbackText("Clear Settings History…")) { clearConfirmation = true }
                Spacer()
                Button(feedbackText("Copy Report")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(fullReport, forType: .string)
                    status = feedbackText("Report copied.")
                }
                Button(feedbackText("Save Report…"), action: save)
            }
            Divider()
            HStack {
                Text(feedbackText("You submit the issue on GitHub. A GitHub account is required."))
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                Button(feedbackText("Cancel"), action: close)
                Button(feedbackText("Continue on GitHub…"), action: continueOnGitHub)
            }
        }
        .padding(24)
        .frame(minWidth: 740, minHeight: 680)
        .onAppear(perform: refresh)
        .alert(isPresented: $clearConfirmation) {
            Alert(title: Text(feedbackText("Clear Settings History?")),
                  message: Text(feedbackText("This removes recorded changes and startup snapshots. Your current settings stay unchanged.")),
                  primaryButton: .destructive(Text(feedbackText("Clear"))) {
                      let preference = AppearancePreference.shared
                      preference.history?.clear(settings: preference.diagnosticSettings)
                      refresh()
                      status = feedbackText("Settings history cleared.")
                  }, secondaryButton: .cancel(Text(feedbackText("Cancel"))))
        }
        .interfaceLayoutDirection(for: AppearancePreference.shared.uiLanguage)
    }

    private func refresh() {
        let preference = AppearancePreference.shared
        preference.observePreferenceChanges()
        preference.flushSharedPreferences()
        var history = preference.history?.snapshot() ?? SettingsHistorySnapshot()
        if preference.history == nil { history.warning = "history-unavailable-or-incomplete" }
        diagnostics = FeedbackReport.markdown(settings: preference.diagnosticSettings,
                                               environment: DiagnosticEnvironment.current(), history: history)
            + UpdateDiagnostics.shared.summary()
        let base = diagnostics
        let fileURL = NSDocumentController.shared.currentDocument?.fileURL
        DispatchQueue.global(qos: .utility).async {
            let summary = QuickLookRegistration.diagnosticSummary(fileURL: fileURL)
            DispatchQueue.main.async {
                // Do not overwrite user edits while the read-only checks are running.
                if diagnostics == base { diagnostics = base + summary }
            }
        }
    }

    private func save() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "FluxMarkdown-report.md"
        panel.allowedFileTypes = ["md"]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try fullReport.write(to: url, atomically: true, encoding: .utf8)
            status = feedbackText("Report saved.")
        } catch {
            status = feedbackText("Could not save the report. You can copy it instead.")
        }
    }

    private func continueOnGitHub() {
        let report = includeDiagnostics ? diagnostics : nil
        let link = FeedbackIssueLink.bug(version: DisplayVersion.text(in: .main) ?? "unknown", report: report,
                                         description: notes)
        if NSWorkspace.shared.open(link.url) {
            status = feedbackText(link.omitted
                ? "GitHub opened with a shortened summary. Copy or save the full report if needed."
                : "GitHub opened. Review the form and submit when ready.")
        } else {
            status = feedbackText("Could not open the browser. Copy the report or save it and try again.")
        }
    }
}
