import Foundation
import CoreServices
import AppKit

struct RegistrationCommandResult {
    let status: Int32
    let output: String
}

struct QuickLookRepairResult {
    var errors: [String] = []
    var warnings: [String] = []
    var succeeded: Bool { errors.isEmpty }
}

enum QuickLookRegistration {
    static let identifier = "com.xykong.Markdown.QuickLook"
    static let types = ["net.daringfireball.markdown", "public.markdown", "net.ia.markdown"]
    typealias Runner = (String, [String]) -> RegistrationCommandResult

    static func savedEditorHandlers() -> [[String: Any]] {
        UserDefaults.standard.persistentDomain(forName: "com.apple.LaunchServices/com.apple.launchservices.secure")?["LSHandlers"] as? [[String: Any]] ?? []
    }

    static func editorState(current: (String) -> String? = currentEditor,
                            handlers: [[String: Any]] = savedEditorHandlers()) -> [String: String] {
        var state: [String: String] = [:]
        let appIdentifier = "com.xykong.Markdown"
        for type in types {
            // Homebrew removes the old app before invoking the installer. During
            // that gap LaunchServices resolves a fallback (e.g. Xcode), although
            // the user's explicit preference still points to this application.
            // Retain only that unambiguous self preference; never reinterpret a
            // different editor's or a conflicting role-specific preference.
            let entries = handlers.filter { ($0["LSHandlerContentType"] as? String) == type }
            let explicitSelf = entries.contains {
                ($0["LSHandlerRoleAll"] as? String)?.caseInsensitiveCompare(appIdentifier) == .orderedSame
            }
            let roles = entries.flatMap { entry in
                ["LSHandlerRoleAll", "LSHandlerRoleViewer", "LSHandlerRoleEditor", "LSHandlerRoleShell"].compactMap { entry[$0] }
            }
            if explicitSelf && roles.allSatisfy({ ($0 as? String)?.caseInsensitiveCompare(appIdentifier) == .orderedSame }) {
                state[type] = appIdentifier
            } else if let value = current(type) {
                state[type] = value
            }
        }
        return state
    }

    static func validEditorState(_ state: [String: String]) -> Bool {
        state.allSatisfy { types.contains($0.key) && $0.value.utf8.count <= 128 &&
            $0.value.range(of: "^[A-Za-z0-9_-]+(\\.[A-Za-z0-9_-]+)+$", options: .regularExpression) != nil }
    }

    static func currentEditor(_ type: String) -> String? {
        LSCopyDefaultRoleHandlerForContentType(type as CFString, .all)?.takeRetainedValue() as String?
    }

    static func setEditor(_ type: String, _ editor: String) -> OSStatus {
        LSSetDefaultRoleHandlerForContentType(type as CFString, .all, editor as CFString)
    }

    static func restoreEditors(_ state: [String: String],
                               current: (String) -> String? = currentEditor,
                               set: (String, String) -> OSStatus = setEditor) -> [String] {
        state.keys.sorted().compactMap { type in
            let expected = state[type]!
            if current(type)?.caseInsensitiveCompare(expected) == .orderedSame { return nil }
            let status = set(type, expected)
            guard status == noErr else { return "editor-restore:\(status)" }
            return current(type)?.caseInsensitiveCompare(expected) == .orderedSame ? nil : "editor-restore-unconfirmed"
        }
    }

    static func run(_ executable: String, _ arguments: [String]) -> RegistrationCommandResult {
        let process = Process(), pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe; process.standardError = pipe
        do {
            try process.run()
            let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 15, execute: timeout)
            defer { timeout.cancel() }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return RegistrationCommandResult(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
        } catch { return RegistrationCommandResult(status: -1, output: "command-unavailable") }
    }

    /// A host/installer operation, never run by the sandboxed extension.
    /// Editor restoration is attempted even when registration fails.
    static func repair(appURL: URL, editors: [String: String], order: [String],
                       runner: Runner = run,
                       restore: ([String: String]) -> [String] = { restoreEditors($0) }) -> QuickLookRepairResult {
        var result = QuickLookRepairResult()
        let extensionURL = appURL.appendingPathComponent("Contents/PlugIns/MarkdownPreview.appex")
        guard appURL.isFileURL, appURL.pathExtension == "app", validEditorState(editors),
              FileManager.default.fileExists(atPath: extensionURL.path) else {
            result.errors.append("invalid-app-or-editor-state"); return result
        }
        let commands: [(String, String, [String])] = [
            ("signature", "/usr/bin/codesign", ["--verify", "--deep", "--strict", appURL.path]),
            ("launchservices", "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister", ["-f", appURL.path]),
            ("extension-add", "/usr/bin/pluginkit", ["-a", extensionURL.path]),
            ("extension-enable", "/usr/bin/pluginkit", ["-e", "use", "-i", identifier])
        ]
        for (step, executable, args) in commands {
            let command = runner(executable, args)
            if command.status != 0 {
                if step == "launchservices", command.output.contains("-10822") {
                    result.warnings.append("launchservices-spotlight-scan")
                } else {
                    result.errors.append("\(step):\(command.status)"); break
                }
            }
        }
        if result.errors.isEmpty {
            // Prioritize this preview provider without changing the default editor.
            let preferences = "com.apple.preferences.extensions.QuickLook"
            var seen = Set([identifier])
            let others = order.compactMap { value -> String? in
                let clean = value.trimmingCharacters(in: CharacterSet(charactersIn: "\" \t\n"))
                guard clean.utf8.count <= 128,
                      clean.range(of: "^[A-Za-z0-9_-]+(\\.[A-Za-z0-9_-]+)+$", options: .regularExpression) != nil,
                      seen.insert(clean).inserted else { return nil }
                return clean
            }
            for args in [["write", preferences, "displayOrder", "-array", identifier] + others,
                         ["write", preferences, "userHasOrdered", "-bool", "true"]] {
                let command = runner("/usr/bin/defaults", args)
                if command.status != 0 { result.errors.append("preview-order:\(command.status)") }
            }
            let reset = runner("/usr/bin/qlmanage", ["-r"])
            if reset.status != 0 { result.warnings.append("cache-reset:\(reset.status)") }
        }
        result.errors += restore(editors)
        return result
    }

    static func registrationSummary(_ output: String, expectedExtension: URL) -> [String: String] {
        let entries = output.split(separator: "\n").filter { $0.contains(identifier + "(") }
        let expected = expectedExtension.standardizedFileURL.path
        let matching = entries.filter { $0.hasSuffix(expected) }
        return ["registeredCopies": String(entries.count),
                "installedCopyRegistered": String(!matching.isEmpty),
                "installedCopyEnabled": String(matching.contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix("+") }),
                "otherRegisteredCopies": String(entries.count - matching.count)]
    }

    static func diagnosticSummary(appURL: URL = Bundle.main.bundleURL, fileURL: URL? = nil,
                                  runner: Runner = run) -> String {
        let ext = appURL.appendingPathComponent("Contents/PlugIns/MarkdownPreview.appex")
        let registration = runner("/usr/bin/pluginkit", ["-m", "-A", "-D", "-v", "-i", identifier])
        var fields = registrationSummary(registration.output, expectedExtension: ext)
        if registration.status != 0 { fields["registrationQuery"] = "failed" }
        fields["signature"] = runner("/usr/bin/codesign", ["--verify", "--deep", "--strict", appURL.path]).status == 0 ? "valid" : "invalid"
        fields["extensionVersion"] = Bundle(url: ext)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        fields["firstInSavedOrder"] = String(currentOrder().first == identifier)
        fields["defaultMarkdownEditor"] = currentEditor("net.daringfireball.markdown") ?? "unknown"
        fields["diagnosticSessionSchema"] = "2"
        fields["actualFinderProvider"] = "unknown-registration-is-not-runtime-proof"
        fields["lastExplicitPreviewTest"] = UserDefaults.standard.string(forKey: "quickLookLastProbeResult") ?? "not-run"
        fields["lastExplicitPreviewTestVersion"] = UserDefaults.standard.string(forKey: "quickLookLastProbeVersion") ?? "unknown"
        if let date = UserDefaults.standard.object(forKey: "quickLookLastProbeDate") as? Date {
            fields["lastExplicitPreviewTestAt"] = ISO8601DateFormatter().string(from: date)
        }
        if let fileURL {
            fields["documentUTI"] = (try? fileURL.resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier ?? "unknown"
        }
        // All exported values are scalar identifiers/status; never include command output or paths.
        return "\n\n## Quick Look diagnostics\n" + fields.keys.sorted().map { key in
            let value = fields[key]!
            let safe = value.count <= 160 && value.range(of: "^[A-Za-z0-9_.:+-]+$", options: .regularExpression) != nil
            return "- \(key): \(safe ? value : "invalid")"
        }.joined(separator: "\n")
    }

    static func currentOrder() -> [String] {
        UserDefaults.standard.persistentDomain(forName: "com.apple.preferences.extensions.QuickLook")?["displayOrder"] as? [String] ?? []
    }

    static func repairCurrentApp(editors: [String: String]? = nil) -> QuickLookRepairResult {
        repair(appURL: Bundle.main.bundleURL, editors: editors ?? editorState(), order: currentOrder())
    }
}

final class QuickLookRepairController {
    static let shared = QuickLookRepairController()
    private var running = false
    func show() {
        guard !running else { return }
        running = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = QuickLookRegistration.repairCurrentApp()
            DispatchQueue.main.async {
                self.running = false
                if !result.succeeded {
                    ErrorFeedback.present(ErrorFeedback.capture(.quickLook), recoveryTitle: "Try Again", recovery: { self.show() })
                    return
                }
                let alert = NSAlert()
                alert.messageText = NSLocalizedString(result.succeeded ? "Quick Look registration repaired" : "Quick Look repair failed", comment: "QuickLook repair result")
                alert.informativeText = result.succeeded
                    ? NSLocalizedString("Try selecting the file in Finder and pressing Space. Your default editor was preserved.", comment: "QuickLook repair advice")
                    : result.errors.joined(separator: "\n")
                if result.succeeded {
                    alert.addButton(withTitle: NSLocalizedString("Test Quick Look", comment: "QuickLook self-test"))
                    alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel"))
                }
                if alert.runModal() == .alertFirstButtonReturn, result.succeeded {
                    NotificationCenter.default.post(name: Notification.Name("FluxMarkdown.TestQuickLook"), object: nil)
                }
            }
        }
    }
}
