import AppKit

// Headless vendor-installation modes run before AppKit/SwiftUI startup.
if CommandLine.arguments.contains("--default-md-state") {
    let data = try JSONSerialization.data(withJSONObject: QuickLookRegistration.editorState(), options: [.sortedKeys])
    FileHandle.standardOutput.write(data)
    exit(0)
}
if CommandLine.arguments.contains("--repair-quicklook") {
    var editors: [String: String]?
    if let index = CommandLine.arguments.firstIndex(of: "--editor-state") {
        guard CommandLine.arguments.indices.contains(index + 1),
              let data = CommandLine.arguments[index + 1].data(using: .utf8),
              let state = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              QuickLookRegistration.validEditorState(state) else { exit(2) }
        editors = state
    }
    let result = QuickLookRegistration.repairCurrentApp(editors: editors)
    for error in result.errors { FileHandle.standardError.write(Data((error + "\n").utf8)) }
    for warning in result.warnings { FileHandle.standardError.write(Data((warning + "\n").utf8)) }
    exit(result.succeeded ? 0 : 1)
}

if CommandLine.arguments.contains("--quicklook-diagnostics") {
    print(QuickLookRegistration.diagnosticSummary())
    exit(0)
}

let applicationLanguagesBeforeBootstrap = DiagnosticEnvironment.applicationLanguages()

// Install the runtime localization swizzle and apply the persisted language
// preference before any view, menu or scene is built.
LocalizationManager.bootstrap(initialPreference: AppearancePreference.shared.uiLanguage)

if CommandLine.arguments.contains("--quicklook-self-test") {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    var probeToken = UUID()
    if let index = CommandLine.arguments.firstIndex(of: "--probe-token") {
        guard CommandLine.arguments.indices.contains(index + 1),
              let token = UUID(uuidString: CommandLine.arguments[index + 1]) else {
            fputs("Invalid --probe-token; use a UUID or omit the option.\n", stderr); exit(2)
        }
        probeToken = token
    }
    DispatchQueue.main.async {
        QuickLookSelfTest.shared.start(probeToken: probeToken) { passed in
            print("quicklook_preview=\(passed ? "rendered" : "unconfirmed")")
            exit(passed ? 0 : 1)
        }
    }
    app.run()
} else if CommandLine.arguments.contains("--export-pdf") {
    let delegate = CLIAppDelegate()
    let app = NSApplication.shared
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
} else {
    let preference = AppearancePreference.shared
    var environment = DiagnosticEnvironment.current()
    environment["applicationLanguagesBeforeBootstrap"] = applicationLanguagesBeforeBootstrap
    preference.history?.startSession(settings: preference.diagnosticSettings, environment: environment)
    _ = RecentDocumentController()
    MarkdownApp.main()
}
