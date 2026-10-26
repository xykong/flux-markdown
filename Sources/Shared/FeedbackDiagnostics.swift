import Foundation
import CoreFoundation

/// The only settings allowed into diagnostic history. Values are validated both
/// when recording and when exporting (including records loaded from disk).
enum DiagnosticSettings {
    static let defaults: [String: Any] = [
        "preferredAppearanceMode": "system", "uiLanguage": "system",
        "baseFontSize": 14.0, "finderPaneFontSize": 13.0,
        "codeHighlightTheme": "default", "enableMermaid": true,
        "enableKatex": true, "enableEmoji": true, "enableTypst": true,
        "contentsSide": "right", "collapseBlockquotesByDefault": false, "showLineNumbers": false
    ]
    static let sliders: Set<String> = ["baseFontSize", "finderPaneFontSize"]

    static func usesDefault(_ raw: Any?, key: String) -> Bool {
        guard let raw else { return true }
        guard sliders.contains(key), let number = raw as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else { return false }
        return number.doubleValue == 0
    }

    static func effectiveValue(_ raw: Any?, key: String) -> Any? {
        usesDefault(raw, key: key) ? defaults[key] : raw
    }

    static func value(_ raw: Any?, key: String) -> String {
        guard let raw else { return "missing" }
        switch key {
        case "preferredAppearanceMode":
            return enumValue(raw, allowed: ["system", "light", "dark"])
        case "uiLanguage":
            return enumValue(raw, allowed: ["system", "en", "de", "fr", "es", "zh", "zh-Hans", "ar"])
        case "contentsSide":
            return enumValue(raw, allowed: ["left", "right"])
        case "codeHighlightTheme":
            return enumValue(raw, allowed: ["default", "github", "monokai", "atom-one-dark"])
        case "baseFontSize", "finderPaneFontSize":
            guard let number = raw as? NSNumber,
                  CFGetTypeID(number) != CFBooleanGetTypeID(),
                  number.doubleValue.isFinite, (8...72).contains(number.doubleValue) else { return "invalid" }
            return String(format: "%g", locale: Locale(identifier: "en_US_POSIX"), number.doubleValue)
        default:
            guard defaults[key] != nil, let number = raw as? NSNumber,
                  CFGetTypeID(number) == CFBooleanGetTypeID() else { return "invalid" }
            return number.boolValue ? "true" : "false"
        }
    }

    static func storedValue(_ string: String, key: String) -> String {
        if string == "missing" || string == "invalid" { return string }
        if sliders.contains(key) { return value(Double(string), key: key) }
        if defaults[key] is Bool {
            guard string == "true" || string == "false" else { return "invalid" }
            return string
        }
        return value(string, key: key)
    }

    static func sanitize(_ values: [String: Any]) -> [String: String] {
        values.reduce(into: [:]) { result, entry in
            if defaults[entry.key] != nil { result[entry.key] = value(entry.value, key: entry.key) }
        }
    }

    private static func enumValue(_ value: Any, allowed: Set<String>) -> String {
        guard let string = value as? String, allowed.contains(string) else { return "invalid" }
        return string
    }
}

enum SettingChangeSource: String, Codable {
    case settings, toolbar, migration
    case externalObserved = "external-observed"
}

struct SettingChange: Codable {
    var id = UUID()
    var session: UUID
    var date: Date
    var appVersion: String
    var key: String
    var oldValue: String
    var newValue: String
    var oldWasDefault: Bool
    var source: SettingChangeSource
}

struct DiagnosticStartup: Codable {
    var session: UUID
    var date: Date
    var environment: [String: String]
    var settings: [String: String]
}

struct SettingsHistorySnapshot: Codable {
    var schemaVersion = 1
    var events: [SettingChange] = []
    var startups: [DiagnosticStartup] = []
    var knownSettings: [String: String] = [:]
    var warning: String?
}

/// One writer (the host app). Its serial queue keeps disk I/O off the UI thread;
/// flush/snapshot are explicit barriers for shutdown and report generation.
final class SettingsHistoryStore {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.xykong.Markdown.SettingsHistory", qos: .utility)
    private var state = SettingsHistorySnapshot()
    private var session = UUID()
    private let appVersion: String
    private var pending: [String: SettingChange] = [:]
    private var scheduled: DispatchWorkItem?
    private static let byteLimit = 256 * 1024

    init(fileURL: URL, appVersion: String = "unknown") {
        self.fileURL = fileURL
        self.appVersion = DiagnosticEnvironment.version(appVersion)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                guard (attributes[.size] as? NSNumber)?.intValue ?? 0 <= Self.byteLimit else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                state = try JSONDecoder().decode(SettingsHistorySnapshot.self, from: Data(contentsOf: fileURL))
                guard state.schemaVersion == 1 else { throw CocoaError(.fileReadCorruptFile) }
                state.events = Array(state.events.filter { DiagnosticSettings.defaults[$0.key] != nil }.suffix(200))
                state.startups = Array(state.startups.suffix(20))
            } catch {
                state = SettingsHistorySnapshot()
                state.warning = "history-unavailable-or-incomplete"
            }
        }
    }

    static func production() -> SettingsHistoryStore? {
        // Tests and extensions never write to the user's history.
        guard Bundle.main.bundleIdentifier == "com.xykong.Markdown" else { return nil }
        let url = SharedPreferenceStore.applicationSupportDirectory().appendingPathComponent("settings-history.json")
        return SettingsHistoryStore(fileURL: url, appVersion: DisplayVersion.text(in: .main) ?? "unknown")
    }

    func record(key: String, oldValue: Any?, newValue: Any?, source: SettingChangeSource,
                oldWasDefault: Bool = false, date: Date = Date()) {
        guard DiagnosticSettings.defaults[key] != nil else { return }
        let old = DiagnosticSettings.value(oldValue, key: key)
        let new = DiagnosticSettings.value(newValue, key: key)
        queue.async {
            self.recordUnsafe(key: key, old: old, new: new, source: source,
                              oldWasDefault: oldWasDefault, date: date)
            self.scheduleWrite()
        }
    }

    private func recordUnsafe(key: String, old: String, new: String, source: SettingChangeSource,
                              oldWasDefault: Bool, date: Date) {
        state.knownSettings[key] = new
        guard old != new else { return }
        if DiagnosticSettings.sliders.contains(key), var event = pending[key], event.source == source {
            event.newValue = new
            event.date = date
            pending[key] = event
        } else {
            let event = SettingChange(session: session, date: date, appVersion: appVersion, key: key,
                                      oldValue: old, newValue: new, oldWasDefault: oldWasDefault, source: source)
            if DiagnosticSettings.sliders.contains(key) {
                if let earlier = pending.removeValue(forKey: key), earlier.oldValue != earlier.newValue {
                    state.events.append(earlier)
                }
                pending[key] = event
            } else {
                state.events.append(event)
            }
        }
    }

    func observe(settings: [String: Any]) {
        let safe = DiagnosticSettings.sanitize(settings)
        queue.async {
            if self.observeUnsafe(safe) { self.scheduleWrite() }
        }
    }

    @discardableResult
    private func observeUnsafe(_ settings: [String: String]) -> Bool {
        let changed = state.knownSettings != settings
        for key in settings.keys.sorted() {
            if let previous = state.knownSettings[key], previous != settings[key]! {
                recordUnsafe(key: key, old: previous, new: settings[key]!, source: .externalObserved,
                             oldWasDefault: false, date: Date())
            }
        }
        state.knownSettings = settings
        return changed
    }

    func startSession(settings: [String: Any], environment: [String: String]) {
        let safe = DiagnosticSettings.sanitize(settings)
        let env = DiagnosticEnvironment.sanitize(environment)
        queue.async {
            self.observeUnsafe(safe)
            self.state.startups.append(DiagnosticStartup(session: self.session, date: Date(),
                                                         environment: env, settings: safe))
            self.scheduleWrite()
        }
    }

    private func scheduleWrite() {
        scheduled?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.writeUnsafe() }
        scheduled = work
        queue.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func flush() {
        queue.sync {
            scheduled?.cancel()
            scheduled = nil
            writeUnsafe()
        }
    }

    func snapshot() -> SettingsHistorySnapshot {
        flush()
        return queue.sync { state }
    }

    func clear(settings: [String: Any]) {
        queue.sync {
            scheduled?.cancel()
            scheduled = nil
            pending = [:]
            state = SettingsHistorySnapshot()
            state.knownSettings = DiagnosticSettings.sanitize(settings)
            writeUnsafe()
        }
    }

    private func writeUnsafe() {
        state.events.append(contentsOf: pending.values.filter { $0.oldValue != $0.newValue })
        pending = [:]
        state.events.sort { $0.date < $1.date }
        state.events = Array(state.events.suffix(200))
        state.startups = Array(state.startups.suffix(20))
        // Sanitize decoded state as well as newly recorded values.
        state.knownSettings = state.knownSettings.filter { DiagnosticSettings.defaults[$0.key] != nil }
        for key in state.knownSettings.keys {
            state.knownSettings[key] = DiagnosticSettings.storedValue(state.knownSettings[key]!, key: key)
        }
        for index in state.events.indices {
            let key = state.events[index].key
            state.events[index].oldValue = DiagnosticSettings.storedValue(state.events[index].oldValue, key: key)
            state.events[index].newValue = DiagnosticSettings.storedValue(state.events[index].newValue, key: key)
            state.events[index].appVersion = DiagnosticEnvironment.version(state.events[index].appVersion)
        }
        for index in state.startups.indices {
            state.startups[index].environment = DiagnosticEnvironment.sanitize(state.startups[index].environment)
            state.startups[index].settings = state.startups[index].settings.filter { DiagnosticSettings.defaults[$0.key] != nil }
            for key in state.startups[index].settings.keys {
                state.startups[index].settings[key] = DiagnosticSettings.storedValue(state.startups[index].settings[key]!, key: key)
            }
        }
        if state.warning != nil { state.warning = "history-unavailable-or-incomplete" }
        do {
            let encoder = JSONEncoder()
            var data = try encoder.encode(state)
            while data.count > Self.byteLimit, !state.events.isEmpty || !state.startups.isEmpty {
                if let event = state.events.first, let startup = state.startups.first {
                    if event.date <= startup.date { state.events.removeFirst() } else { state.startups.removeFirst() }
                } else if !state.events.isEmpty { state.events.removeFirst() } else { state.startups.removeFirst() }
                data = try encoder.encode(state)
            }
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Atomic replacement preserves a private mode on the replacement file.
            try data.write(to: fileURL, options: [.atomic])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            state.warning = "history-unavailable-or-incomplete"
        }
    }
}

enum DiagnosticEnvironment {
    static let keys: Set<String> = ["appVersion", "appBuild", "macOS", "macOSBuild", "architecture",
                                    "globalLanguages", "applicationLanguages", "preferredLanguages",
                                    "bundleLocalizations", "bundlePreferred", "activeLanguage", "languagePreference",
                                    "applicationLanguagesBeforeBootstrap"]
    static func token(_ string: String) -> String {
        guard !string.isEmpty, string.utf8.count <= 128,
              string.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.").contains($0) }) else { return "invalid" }
        return string
    }
    static func version(_ value: String) -> String {
        sanitize(["appVersion": value])["appVersion"] ?? "invalid"
    }

    static func sanitize(_ values: [String: String]) -> [String: String] {
        values.reduce(into: [:]) { result, pair in
            guard keys.contains(pair.key) else { return }
            let tokens = pair.value.split(separator: ",", omittingEmptySubsequences: false)
            guard tokens.count <= 20 else { result[pair.key] = "invalid"; return }
            result[pair.key] = tokens.map { item in
                let text = String(item)
                let safe = token(text)
                guard safe != "invalid" else { return "invalid" }
                if ["none", "unknown", "invalid"].contains(text) { return text }
                let pattern: String
                switch pair.key {
                case "appVersion": pattern = #"^\d+(\.\d+){1,3}(-dev-[0-9-]+)?$"#
                case "appBuild": pattern = #"^\d+$"#
                case "macOS": pattern = #"^\d+\.\d+\.\d+$"#
                case "macOSBuild": pattern = #"^\d+[A-Z]\d+[a-z]?$"#
                case "architecture": return ["arm64", "x86_64"].contains(text) ? text : "invalid"
                case "languagePreference": return DiagnosticSettings.value(text, key: "uiLanguage")
                default:
                    if text == "Base" || text == "bundle-default" { return text }
                    pattern = #"^[a-z]{2,3}(-[A-Za-z0-9]{2,8})*$"#
                }
                return text.range(of: pattern, options: .regularExpression) != nil ? text : "invalid"
            }.joined(separator: ",")
        }
    }

    static func applicationLanguages(defaults: UserDefaults = .standard, bundle: Bundle = .main) -> String {
        let domain = bundle.bundleIdentifier.flatMap { defaults.persistentDomain(forName: $0) }
        return (domain?["AppleLanguages"] as? [String])?.prefix(20).joined(separator: ",") ?? "none"
    }

    static func current(defaults: UserDefaults = .standard, bundle: Bundle = .main) -> [String: String] {
        func list(_ strings: [String]?) -> String { strings?.prefix(20).joined(separator: ",") ?? "none" }
        let appDomain = bundle.bundleIdentifier.flatMap { defaults.persistentDomain(forName: $0) } ?? [:]
        let os = ProcessInfo.processInfo.operatingSystemVersion
        var buildSize = 0
        sysctlbyname("kern.osversion", nil, &buildSize, nil, 0)
        var bytes = [CChar](repeating: 0, count: max(1, buildSize))
        let readBuild = sysctlbyname("kern.osversion", &bytes, &buildSize, nil, 0) == 0
        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "x86_64"
        #endif
        return sanitize([
            "appVersion": DisplayVersion.text(in: bundle) ?? "unknown",
            "appBuild": bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "macOS": "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            "macOSBuild": readBuild ? String(cString: bytes) : "unknown", "architecture": architecture,
            "globalLanguages": list(defaults.persistentDomain(forName: UserDefaults.globalDomain)?["AppleLanguages"] as? [String]),
            "applicationLanguages": list(appDomain["AppleLanguages"] as? [String]),
            "preferredLanguages": list(Locale.preferredLanguages),
            "bundleLocalizations": list(bundle.localizations), "bundlePreferred": list(bundle.preferredLocalizations),
            "activeLanguage": LocalizationManager.activeLanguage ?? "bundle-default",
            "languagePreference": AppearancePreference.shared.uiLanguage
        ])
    }
}

enum FeedbackReport {
    static func markdown(settings: [String: Any], environment: [String: String], history: SettingsHistorySnapshot,
                         date: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        func section(_ title: String, _ values: [String: String]) -> [String] {
            ["", "## \(title)"] + values.keys.sorted().map { "- \($0): \(values[$0]!)" }
        }
        var lines = ["# FluxMarkdown diagnostics", "Schema: 1", "Generated: \(formatter.string(from: date))"]
        lines += section("Environment", DiagnosticEnvironment.sanitize(environment))
        lines += section("Current settings", DiagnosticSettings.sanitize(settings))
        if history.warning != nil { lines += ["", "History unavailable or incomplete."] }
        lines += ["", "## Settings changes (newest first)", "Source external-observed means the writer and actual write time are unknown."]
        for event in history.events.suffix(200).reversed() where DiagnosticSettings.defaults[event.key] != nil {
            let old = DiagnosticSettings.storedValue(event.oldValue, key: event.key)
            let new = DiagnosticSettings.storedValue(event.newValue, key: event.key)
            lines.append("- \(formatter.string(from: event.date)) | \(event.key): \(old) → \(new) | \(event.source.rawValue) | old-default=\(event.oldWasDefault) | app=\(DiagnosticEnvironment.version(event.appVersion)) | session=\(event.session.uuidString)")
        }
        if history.events.isEmpty { lines.append("No recorded setting changes. History starts with this version; earlier actions cannot be recovered.") }
        lines += ["", "## Recent startups (newest first)"]
        for startup in history.startups.suffix(20).reversed() {
            let env = DiagnosticEnvironment.sanitize(startup.environment)
            let safeSettings = startup.settings.filter { DiagnosticSettings.defaults[$0.key] != nil }
            let detail = env.keys.sorted().map { "\($0)=\(env[$0]!)" }.joined(separator: "; ")
            let preferences = safeSettings.keys.sorted().map { "\($0)=\(DiagnosticSettings.storedValue(safeSettings[$0]!, key: $0))" }.joined(separator: "; ")
            lines.append("- \(formatter.string(from: startup.date)) | \(detail) | \(preferences)")
        }
        return lines.joined(separator: "\n")
    }
}

struct FeedbackIssueLink {
    let url: URL
    let omitted: Bool
    static let feature = URL(string: "https://github.com/xykong/flux-markdown/issues/new?template=feature_request.yml")!

    static func bug(version: String, report: String?, description: String = "") -> FeedbackIssueLink {
        func url(_ text: String?) -> URL {
            var components = URLComponents(string: "https://github.com/xykong/flux-markdown/issues/new")!
            components.queryItems = [URLQueryItem(name: "template", value: "bug_report.yml"),
                                     URLQueryItem(name: "app-version", value: DiagnosticEnvironment.version(version))]
            if !description.isEmpty { components.queryItems!.append(URLQueryItem(name: "description", value: description)) }
            if let text { components.queryItems!.append(URLQueryItem(name: "diagnostics", value: text)) }
            return components.url!
        }
        if url(nil).absoluteString.utf8.count > 6000 {
            var components = URLComponents(url: url(nil), resolvingAgainstBaseURL: false)!
            components.queryItems?.removeAll { $0.name == "description" }
            return FeedbackIssueLink(url: components.url!, omitted: true)
        }
        guard let report else { return FeedbackIssueLink(url: url(nil), omitted: false) }
        if url(report).absoluteString.utf8.count <= 6000 { return FeedbackIssueLink(url: url(report), omitted: false) }
        let lines = report.components(separatedBy: "\n")
        var lower = 0
        var upper = lines.count
        var best: URL?
        while lower <= upper {
            let count = (lower + upper) / 2
            let short = lines.prefix(count).joined(separator: "\n") + "\n[Diagnostic lines omitted: \(lines.count - count). Full report available via Copy or Save.]"
            let candidate = url(short)
            if candidate.absoluteString.utf8.count <= 6000 {
                best = candidate
                lower = count + 1
            } else {
                upper = count - 1
            }
        }
        if let best { return FeedbackIssueLink(url: best, omitted: true) }
        return FeedbackIssueLink(url: url(nil), omitted: true)
    }
}
