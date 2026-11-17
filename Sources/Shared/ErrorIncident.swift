import Foundation

/// Wire format shared with the restricted launcher. No document identifiers or raw error text.
enum IncidentSource: String, Codable { case app, quicklook, cli }
enum IncidentReason: String, Codable { case operationFailed, invalidInput, moduleUnavailable, resourceUnavailable, mathSyntax, mathOutput, mathReference, mathLimit }
enum IncidentPhase: String, Codable { case started, failed, completed, timeout }
enum FailureKind: String, Codable, CaseIterable {
    case diagramExport, attribution, copy, usageSettings, update, fileRead, fileTooLarge, reload, exportHTML, exportPDF, renderer, rendererResources, source
    case mermaid, typst, graphviz, vega, math, search, quickLook, images, previewLimit, link, browser

    var title: String {
        switch self {
        case .attribution: return "Promotion source could not be linked"

        case .diagramExport: return "Diagram could not be copied or saved"
        case .copy: return "Text could not be copied"
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
        case .attribution: return "Source association is optional. Try again if the connection failed, or return to the promotion page for a fresh link. Your documents are unaffected."

        case .diagramExport: return "Try the diagram action again, or choose another writable folder. Your document is unchanged."
        case .copy: return "Select the text to copy it manually, or try the copy button again."
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
        case .link: return "The link may point to a file that is not on this Mac, or to a path that is not relative to the document. Copy the link to open it manually, or check the path in your editor."
        case .browser: return "Open the destination in your browser or editor. You can copy a report if this keeps happening."
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

/// Only public callback stages and recognized categories cross the feedback boundary.
enum UpdateStage: String, Codable {
    case observationStarted, checkStarted, appcastLoaded, updateFound, noUpdate, downloadStarted, downloadCompleted
    case downloadFailed, cancelled, extractionStarted, extractionCompleted, installHandoff
    case failed, cycleFinished
}
enum UpdateFailureCategory: String, Codable {
    case agentConnectionTimeout, installationDataTimeout, agentInvalidated, unclassified
}
struct UpdateSessionEvent: Codable {
    let stage: UpdateStage
    let date: Date
    let elapsed: TimeInterval
}
struct UpdateSessionSnapshot: Codable {
    let id: UUID
    var events: [UpdateSessionEvent]
    var failure: UpdateFailureCategory?
    var truncated: Bool
    var isValid: Bool {
        !events.isEmpty && events.count <= 32 && events.allSatisfy {
            (-62135596800...253402300799).contains($0.date.timeIntervalSince1970) &&
            $0.elapsed.isFinite && (0...604800).contains($0.elapsed)
        } && zip(events, events.dropFirst()).allSatisfy { $0.elapsed <= $1.elapsed }
    }
    var report: [String] {
        ["", "## Update session", "Session: \(id.uuidString)",
         "Failure category: \(failure?.rawValue ?? "unclassified")", "Events truncated: \(truncated)"] + events.map {
            "- \(ISO8601DateFormatter().string(from: $0.date)) (+\(String(format: "%.3f", $0.elapsed))s): \($0.stage.rawValue)"
        }
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
    var renderingBlocker: FailureKind?
    var quickLookCheck: IncidentQuickLookCheck?
    var updateSession: UpdateSessionSnapshot?

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
            case "enableMermaid", "enableKatex", "enableEmoji", "enableTypst", "showLineNumbers", "showCopyButtons", "collapseBlockquotesByDefault": return ["true", "false"].contains(value)
            case "preferredAppearanceMode": return ["system", "light", "dark"].contains(value)
            case "uiLanguage": return ["system", "en", "zh-Hans", "zh", "de", "fr", "es", "ar"].contains(value)
            case "contentsSide": return ["left", "right"].contains(value)
            case "codeHighlightTheme": return ["default", "github", "monokai", "atom-one-dark"].contains(value)
            default: return false
            }
        }
    }
    var guidance: String { renderingBlocker == .math ? FailureKind.math.guidance : kind.guidance }

    var isValid: Bool {
        (renderingBlocker == nil || (renderingBlocker == .math && [.exportHTML, .exportPDF].contains(kind))) &&
        schema == 1 && (-62135596800...253402300799).contains(date.timeIntervalSince1970) && codes.count <= 8 && steps.count <= 12 &&
        (quickLookCheck?.isValid ?? true) && (updateSession?.isValid ?? true) && settingChanges.count <= 5 && settingChanges.allSatisfy(\.isValid) &&
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
        if let updateSession { lines += updateSession.report }
        if let reason { lines += ["Failure category: \(reason.rawValue)"] }
        if let renderingBlocker { lines += ["Rendering blocker: \(renderingBlocker.rawValue)"] }
        if historyUnavailable == true { lines += ["", "Some diagnostic information is unavailable. This report includes the current incident."] }
        if let previewTest { lines += ["", "Last explicit preview test (historical, not proof of current rendering): \(previewTest)"] }
        lines += ["", "## Recent related settings changes"] + settingChanges.map { "- \(formatter.string(from: $0.date)): \($0.key) \($0.before) → \($0.after)" }
        if let check = quickLookCheck {
            lines += ["", "## Quick Look check collected at report time: \(formatter.string(from: check.date))"]
            lines += check.fields.keys.sorted().map { "- \($0): \(check.fields[$0]!)" }
        }
        return lines.joined(separator: "\n")
    }
    func feedbackURL(includeDiagnostics: Bool = true, notes: String = "", useTemplate: Bool = false, attachment: URL? = nil, attachmentReference: String? = nil) -> URL {
        var c = URLComponents(string: "https://github.com/xykong/flux-markdown/issues/new")!
        let privateText = attachmentReference.flatMap { value -> String? in
            guard value.hasPrefix("FM-"), value.utf8.count == 67, value.dropFirst(3).utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { return nil }
            return "\n\nAttachment reference: \(value) (private; maintainers only)\n"
        } ?? ""
        let attachmentText = !privateText.isEmpty ? privateText : attachment.map { "\n\n[Download reproduction ZIP](\($0.absoluteString))\n" } ?? ""
        var description = "Operation: \(kind.rawValue)\nObserved result: \(titleForReport)\nIncident: \(id.uuidString)\n"
        // Bound user-entered additions. The complete edited report remains local.
        description += String(notes.prefix(600))
        var diagnostic = includeDiagnostics ? report : ""
        func items() -> [URLQueryItem] {
            var items = [URLQueryItem(name: "title", value: "[\(kind.rawValue)] \(titleForReport)")]
            if useTemplate {
                items.append(URLQueryItem(name: "template", value: "app_error.yml"))
                items.append(URLQueryItem(name: "description", value: attachmentText + description))
                if !diagnostic.isEmpty { items.append(URLQueryItem(name: "diagnostics", value: diagnostic)) }
            } else {
                // GitHub's plain issue editor works before a new template is published.
                items.append(URLQueryItem(name: "body", value: attachmentText + description + (diagnostic.isEmpty ? "" : "\n\n" + diagnostic)))
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
    var materialReview: Bool?
    var sample: String?
    var followUp: Bool?
    var transferToken: UUID?
    var includeDocument: Bool?
    static func decode(_ data: Data) -> IncidentFeedbackRequest? {
        guard data.count <= 16384, let request = try? JSONDecoder().decode(Self.self, from: data),
              request.incident.isValid, request.notes.utf8.count <= 8000,
              (request.sample?.utf8.count ?? 0) <= 6000, request.sample == nil || request.materialReview == true else { return nil }
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

/// Bulk document snapshots use authenticated XPC and a private one-time file.
/// Only the opaque token and ordinary diagnostic request travel in the app URL.
struct IncidentDocumentTransfer: Codable {
    let request: IncidentFeedbackRequest
    let document: String
    let sample: String?
    let displayName: String
    static let maxBytes = 32 * 1024 * 1024
    static var directory: URL { SharedPreferenceStore.applicationSupportDirectory().appendingPathComponent("FeedbackTransfers", isDirectory: true) }
    static func decode(_ data: Data) -> Self? {
        guard data.count <= maxBytes, let value = try? JSONDecoder().decode(Self.self, from: data),
              value.document.utf8.count <= 20 * 1024 * 1024, (value.sample?.utf8.count ?? 0) <= 6000,
              value.displayName.utf8.count <= 255, !value.displayName.contains("/"), !value.displayName.contains("\\"),
              value.request.review || value.request.materialReview == true,
              let metadata = try? JSONEncoder().encode(value.request), IncidentFeedbackRequest.decode(metadata) != nil else { return nil }
        return value
    }
    func persist(in directory: URL = Self.directory) throws -> UUID {
        let data = try JSONEncoder().encode(self)
        guard Self.decode(data) != nil else { throw CocoaError(.fileWriteOutOfSpace) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        guard try directory.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw CocoaError(.fileWriteNoPermission) }
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey])
        var retained = 0
        for file in files where file.pathExtension == "json" && UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil {
            let values = try file.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            if let date = values.contentModificationDate, date < Date().addingTimeInterval(-3600) { try FileManager.default.removeItem(at: file) }
            else { retained += 1 }
        }
        guard retained < 10 else { throw CocoaError(.fileWriteOutOfSpace) }
        let token = UUID(), file = directory.appendingPathComponent(token.uuidString + ".json")
        try data.write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        return token
    }
    static func consume(token: UUID, in directory: URL = Self.directory) throws -> Self {
        let file = directory.appendingPathComponent(token.uuidString + ".json")
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey])
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(),
              (attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600,
              let date = values.contentModificationDate, date > Date().addingTimeInterval(-3600) else { throw CocoaError(.fileReadNoPermission) }
        defer { try? FileManager.default.removeItem(at: file) }
        guard let value = decode(try BoundedFileReader.read(file, maxBytes: maxBytes)) else { throw CocoaError(.fileReadCorruptFile) }
        return value
    }
}
