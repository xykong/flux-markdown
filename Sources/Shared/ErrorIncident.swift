import Foundation

/// Wire format shared with the restricted launcher. No document identifiers or raw error text.
enum IncidentSource: String, Codable { case app, quicklook, cli }
enum IncidentReason: String, Codable { case operationFailed, invalidInput, moduleUnavailable, resourceUnavailable }
enum IncidentPhase: String, Codable { case started, failed, completed, timeout }
enum FailureKind: String, Codable, CaseIterable {
    case usageSettings, update, fileRead, fileTooLarge, reload, exportHTML, exportPDF, renderer, rendererResources, source
    case mermaid, typst, graphviz, vega, math, search, quickLook, images, previewLimit, link, browser

    var title: String {
        switch self {
        case .usageSettings: return "Usage statistics preference could not be saved"
        case .update: return "Update could not be completed"
        case .fileRead, .fileTooLarge: return "Document could not be opened"
        case .reload: return "Document could not be reloaded"
        case .exportHTML, .exportPDF: return "Export could not be completed"
        case .rendererResources: return "Preview could not start"
        case .renderer, .source: return "Document could not be displayed"
        case .mermaid, .typst, .graphviz, .vega, .math: return "This diagram or formula could not be displayed"
        case .search: return "Search could not be completed"
        case .quickLook: return "Quick Look could not complete this operation"
        case .images: return "Some images could not be displayed"
        case .previewLimit: return "This preview is incomplete"
        case .link, .browser: return "The destination could not be opened"
        }
    }
    var guidance: String {
        switch self {
        case .usageSettings: return "Close FluxMarkdown and Quick Look to stop this session. Check available disk space, then try turning statistics off again."
        case .update: return "You can download the latest version and install it manually."
        case .fileRead: return "Choose a readable UTF-8 Markdown file, or open it in your editor to check it."
        case .fileTooLarge: return "Open this document in your editor, or split it into smaller files before trying again."
        case .reload: return "Try reloading again when the file is available. Your current document has not been discarded."
        case .exportHTML, .exportPDF: return "Try exporting again and choose another writable folder."
        case .rendererResources: return "Download and reinstall FluxMarkdown, or open the document in your editor."
        case .renderer, .source: return "Try reloading the preview, or open the document in your editor."
        case .mermaid, .typst, .graphviz, .vega, .math: return "Check the source syntax in your editor. The rest of the document is still available."
        case .search: return "Check the search expression, or open the document in FluxMarkdown and press Command-F."
        case .quickLook: return "Open the document in FluxMarkdown. You can also run Repair Quick Look from the Help menu."
        case .images, .previewLimit: return "Open the document in FluxMarkdown to read beyond the preview limits."
        case .link, .browser: return "Open the destination in your browser or editor. You can copy a report if this keeps happening."
        }
    }
}

struct IncidentCode: Codable, Equatable {
    let domain: String
    let code: Int
    static let domains: Set<String> = ["SUSparkleErrorDomain", NSCocoaErrorDomain, NSPOSIXErrorDomain, NSURLErrorDomain, NSOSStatusErrorDomain, "WKErrorDomain", "other"]
}
struct IncidentStep: Codable {
    let kind: FailureKind
    let phase: IncidentPhase
    let date: Date
}

struct IncidentSettingChange: Codable {
    let key: String
    let before: String
    let after: String
    let date: Date
    var isValid: Bool {
        !ErrorIncident.cleanSettings([key: after]).isEmpty &&
        (["missing", "invalid"].contains(before) || !ErrorIncident.cleanSettings([key: before]).isEmpty) && (-62135596800...253402300799).contains(date.timeIntervalSince1970)
    }
}

struct ErrorIncident: Codable {
    let schema: Int
    let id: UUID
    let scope: UUID
    let date: Date
    let kind: FailureKind
    let source: IncidentSource
    let phase: IncidentPhase
    let codes: [IncidentCode]
    let environment: [String: String]
    let settings: [String: String]
    var steps: [IncidentStep]
    var settingChanges: [IncidentSettingChange]
    var previewTest: String?
    var historyUnavailable: Bool?
    var reason: IncidentReason?
    var quickLookCheck: IncidentQuickLookCheck?

    init(kind: FailureKind, source: IncidentSource, phase: IncidentPhase = .failed, scope: UUID? = nil,
         error: Error? = nil, environment: [String: String] = [:], settings: [String: String] = [:]) {
        schema = 1; id = UUID(); self.scope = scope ?? id; date = Date()
        self.kind = kind; self.source = source; self.phase = phase
        self.environment = Self.cleanEnvironment(environment)
        self.settings = Self.cleanSettings(settings)
        var chain: [IncidentCode] = [], current = error as NSError?
        while let item = current, chain.count < 8 {
            chain.append(IncidentCode(domain: IncidentCode.domains.contains(item.domain) ? item.domain : "other", code: item.code))
            current = item.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        codes = chain; steps = []; settingChanges = []; previewTest = nil
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        value.utf8.count <= 128 && value.range(of: pattern, options: .regularExpression) != nil
    }
    static func cleanEnvironment(_ values: [String: String]) -> [String: String] {
        values.filter { key, value in
            if value == "unknown" { return ["appVersion", "targetVersion", "appBuild", "macOS", "macOSBuild", "architecture", "languagePreference"].contains(key) }
            switch key {
            case "appVersion", "targetVersion": return matches(value, #"^\d+(\.\d+){1,3}(-dev-[0-9-]+)?$"#)
            case "appBuild": return matches(value, #"^\d+$"#)
            case "macOS": return matches(value, #"^\d+\.\d+(\.\d+)?$"#)
            case "macOSBuild": return matches(value, #"^\d+[A-Z]\d+[a-z]?$"#)
            case "architecture": return ["arm64", "x86_64"].contains(value)
            case "languagePreference": return ["system", "en", "zh-Hans", "zh", "de", "fr", "es", "ar"].contains(value)
            default: return false
            }
        }
    }
    static func cleanSettings(_ values: [String: String]) -> [String: String] {
        values.filter { key, value in
            switch key {
            case "baseFontSize", "finderPaneFontSize": return Double(value).map { $0.isFinite && (8...72).contains($0) } ?? false
            case "enableMermaid", "enableKatex", "enableEmoji", "enableTypst", "showLineNumbers", "collapseBlockquotesByDefault": return ["true", "false"].contains(value)
            case "preferredAppearanceMode": return ["system", "light", "dark"].contains(value)
            case "uiLanguage": return ["system", "en", "zh-Hans", "zh", "de", "fr", "es", "ar"].contains(value)
            case "contentsSide": return ["left", "right"].contains(value)
            case "codeHighlightTheme": return ["default", "github", "monokai", "atom-one-dark"].contains(value)
            default: return false
            }
        }
    }
    var isValid: Bool {
        schema == 1 && (-62135596800...253402300799).contains(date.timeIntervalSince1970) && codes.count <= 8 && steps.count <= 12 &&
        (quickLookCheck?.isValid ?? true) && settingChanges.count <= 5 && settingChanges.allSatisfy(\.isValid) &&
        (previewTest == nil || ["rendered", "unconfirmed", "not-run"].contains(previewTest!)) &&
        codes.allSatisfy { IncidentCode.domains.contains($0.domain) } &&
        steps.allSatisfy { (-62135596800...253402300799).contains($0.date.timeIntervalSince1970) } &&
        environment == Self.cleanEnvironment(environment) && settings == Self.cleanSettings(settings)
    }
    func encoded() throws -> Data { try JSONEncoder().encode(self) }
    static func decode(_ data: Data) -> ErrorIncident? {
        guard data.count <= 16384, let value = try? JSONDecoder().decode(Self.self, from: data), value.isValid else { return nil }
        return value
    }
    var report: String {
        let formatter = ISO8601DateFormatter()
        var lines = ["# FluxMarkdown error report", "Incident: \(id.uuidString)", "Time: \(formatter.string(from: date))",
                     "Source: \(source.rawValue)", "Operation: \(kind.rawValue)", "Phase: \(phase.rawValue)",
                     "Error chain: " + codes.map { "\($0.domain):\($0.code)" }.joined(separator: " → ")]
        lines += ["", "## Environment at failure"] + environment.keys.sorted().map { "- \($0): \(environment[$0]!)" }
        lines += ["", "## Settings at failure"] + settings.keys.sorted().map { "- \($0): \(settings[$0]!)" }
        lines += ["", "## Related operation events"] + steps.map { "- \(formatter.string(from: $0.date)): \($0.kind.rawValue) / \($0.phase.rawValue)" }
        if let reason { lines += ["Failure category: \(reason.rawValue)"] }
        if historyUnavailable == true { lines += ["", "Some diagnostic information is unavailable. This report includes the current incident."] }
        if let previewTest { lines += ["", "Last explicit preview test (historical, not proof of current rendering): \(previewTest)"] }
        lines += ["", "## Recent related settings changes"] + settingChanges.map { "- \(formatter.string(from: $0.date)): \($0.key) \($0.before) → \($0.after)" }
        if let check = quickLookCheck {
            lines += ["", "## Quick Look check collected at report time: \(formatter.string(from: check.date))"]
            lines += check.fields.keys.sorted().map { "- \($0): \(check.fields[$0]!)" }
        }
        return lines.joined(separator: "\n")
    }
    func feedbackURL(includeDiagnostics: Bool = true, notes: String = "", useTemplate: Bool = false) -> URL {
        var c = URLComponents(string: "https://github.com/xykong/flux-markdown/issues/new")!
        var description = "Operation: \(kind.rawValue)\nObserved result: \(titleForReport)\n"
        // Bound user-entered additions. The complete edited report remains local.
        description += String(notes.prefix(600))
        var diagnostic = includeDiagnostics ? report : ""
        func items() -> [URLQueryItem] {
            var items = [URLQueryItem(name: "title", value: "[\(kind.rawValue)] \(titleForReport)")]
            if useTemplate {
                items.append(URLQueryItem(name: "template", value: "app_error.yml"))
                items.append(URLQueryItem(name: "description", value: description))
                if !diagnostic.isEmpty { items.append(URLQueryItem(name: "diagnostics", value: diagnostic)) }
            } else {
                // GitHub's plain issue editor works before a new template is published.
                items.append(URLQueryItem(name: "body", value: description + (diagnostic.isEmpty ? "" : "\n\n" + diagnostic)))
            }
            return items
        }
        c.queryItems = items()
        if notes.count > 600 || c.url!.absoluteString.utf8.count > 6000 { description = "[Some details omitted; the full report is retained locally.]\n" + description }
        c.queryItems = items()
        while c.url!.absoluteString.utf8.count > 6000 && !diagnostic.isEmpty {
            let lines = diagnostic.components(separatedBy: "\n")
            diagnostic = lines.dropLast().joined(separator: "\n")
            c.queryItems = items()
        }
        while c.url!.absoluteString.utf8.count > 6000 && description.count > 120 {
            description.removeLast(); c.queryItems = items()
        }
        return c.url!
    }
    private var titleForReport: String { kind.title }
}

final class ErrorIncidentStore {
    private let fileURL: URL?
    private let lock = NSRecursiveLock()
    private var values: [ErrorIncident] = []
    private(set) var unavailable = false
    var incidents: [ErrorIncident] { lock.lock(); defer { lock.unlock() }; return values }
    init(fileURL: URL? = nil) {
        self.fileURL = fileURL
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           (attrs[.size] as? NSNumber)?.intValue ?? Int.max <= 65536,
           let data = try? Data(contentsOf: fileURL), let decoded = try? JSONDecoder().decode([ErrorIncident].self, from: data),
           decoded.count <= 100, decoded.allSatisfy(\.isValid) { values = decoded }
        else { unavailable = true }
    }
    func record(_ incident: ErrorIncident) {
        guard incident.isValid else { return }
        lock.lock(); defer { lock.unlock() }
        values.removeAll { $0.id == incident.id }; values.append(incident)
        while values.count > 100 { values.removeFirst() }
        persist()
    }
    func clear() { lock.lock(); defer { lock.unlock() }; values.removeAll(); persist() }
    private func persist() {
        do {
            var data = try JSONEncoder().encode(values)
            while data.count > 65536, !values.isEmpty { values.removeFirst(); data = try JSONEncoder().encode(values) }
            guard let fileURL else { return }
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            unavailable = false
        } catch { unavailable = true }
    }
}

struct IncidentFeedbackRequest: Codable {
    let incident: ErrorIncident
    let includeDiagnostics: Bool
    let notes: String
    var review = false
    static func decode(_ data: Data) -> IncidentFeedbackRequest? {
        guard data.count <= 16384, let request = try? JSONDecoder().decode(Self.self, from: data),
              request.incident.isValid, request.notes.utf8.count <= 8000 else { return nil }
        return request
    }
    var hostURL: URL? {
        guard let data = try? JSONEncoder().encode(self), data.count <= 16384 else { return nil }
        var components = URLComponents(); components.scheme = "markdownpreview"; components.host = "report-error"
        components.queryItems = [URLQueryItem(name: "payload", value: data.base64EncodedString())]
        return components.url
    }
}

struct IncidentQuickLookCheck: Codable {
    let date: Date
    let fields: [String: String]
    static func sanitize(_ fields: [String: String]) -> [String: String] {
        fields.filter { key, value in
            switch key {
            case "registeredCopies", "otherRegisteredCopies": return Int(value).map { (0...10000).contains($0) } ?? false
            case "installedCopyRegistered", "installedCopyEnabled", "firstInSavedOrder": return ["true", "false"].contains(value)
            case "signature": return ["valid", "invalid"].contains(value)
            case "registrationQuery": return value == "failed"
            case "extensionVersion", "lastExplicitPreviewTestVersion": return value == "unknown" || ErrorIncident.cleanEnvironment(["appVersion": value])["appVersion"] != nil
            case "lastExplicitPreviewTest": return ["rendered", "unconfirmed", "not-run"].contains(value)
            case "lastExplicitPreviewTestAt": return value.utf8.count <= 40 && ISO8601DateFormatter().date(from: value) != nil
            case "actualFinderProvider": return value == "unknown-registration-is-not-runtime-proof"
            default: return false
            }
        }
    }
    var isValid: Bool { fields == Self.sanitize(fields) && (-62135596800...253402300799).contains(date.timeIntervalSince1970) }
}
