import XCTest

final class FeedbackDiagnosticsTests: XCTestCase {
    private var directory: URL!
    private var file: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        file = directory.appendingPathComponent("history.json")
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testHistorySurvivesYearsAndRestartAndRetainsLatest200() {
        let store = SettingsHistoryStore(fileURL: file)
        for i in 0..<205 {
            store.record(key: "uiLanguage", oldValue: "en", newValue: "de", source: .settings,
                         date: Date(timeIntervalSince1970: Double(i)))
        }
        store.flush()
        let reloaded = SettingsHistoryStore(fileURL: file).snapshot()
        XCTAssertEqual(reloaded.events.count, 200)
        XCTAssertEqual(reloaded.events.first?.date, Date(timeIntervalSince1970: 5))
        XCTAssertEqual(reloaded.events.last?.newValue, "de")
    }

    func testSliderCoalescesAndUnchangedValuesAreIgnored() {
        let store = SettingsHistoryStore(fileURL: file)
        store.record(key: "baseFontSize", oldValue: 14.0, newValue: 15.0, source: .settings)
        store.record(key: "baseFontSize", oldValue: 15.0, newValue: 18.0, source: .settings)
        store.record(key: "uiLanguage", oldValue: "en", newValue: "en", source: .settings)
        store.flush()
        let events = store.snapshot().events
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.oldValue, "14")
        XCTAssertEqual(events.first?.newValue, "18")
    }

    func testSliderReturningToInitialValueDoesNotRecordChange() {
        let store = SettingsHistoryStore(fileURL: file)
        store.record(key: "baseFontSize", oldValue: 14.0, newValue: 18.0, source: .settings)
        store.record(key: "baseFontSize", oldValue: 18.0, newValue: 14.0, source: .settings)
        store.flush()
        XCTAssertTrue(store.snapshot().events.isEmpty)
    }

    func testBaselineExternalObservationAndOwnWritesAreDistinct() {
        let store = SettingsHistoryStore(fileURL: file)
        store.observe(settings: ["uiLanguage": "en"])
        XCTAssertTrue(store.snapshot().events.isEmpty)
        store.record(key: "uiLanguage", oldValue: "en", newValue: "de", source: .toolbar)
        store.observe(settings: ["uiLanguage": "de"])
        store.flush()
        store.observe(settings: ["uiLanguage": "fr"])
        store.flush()
        let events = SettingsHistoryStore(fileURL: file).snapshot().events
        XCTAssertEqual(events.map(\.source), [.toolbar, .externalObserved])
    }

    func testWhitelistFiltersPrivateAndInvalidValues() {
        let safe = DiagnosticSettings.sanitize(["uiLanguage": "/Users/alice/private.md",
                                                "baseFontSize": Double.infinity,
                                                "lastOpenedFilePath": "/Users/alice/private.md"])
        XCTAssertEqual(safe["uiLanguage"], "invalid")
        XCTAssertEqual(safe["baseFontSize"], "invalid")
        XCTAssertNil(safe["lastOpenedFilePath"])
        let store = SettingsHistoryStore(fileURL: file)
        store.record(key: "lastOpenedFilePath", oldValue: "a", newValue: "b", source: .settings)
        store.record(key: "uiLanguage", oldValue: "en", newValue: "/Users/alice/private.md", source: .settings)
        store.flush()
        XCTAssertFalse((try! String(contentsOf: file)).contains("alice"))
    }

    func testArabicLanguagePreferenceSurvivesDiagnosticSanitizing() {
        let safe = DiagnosticSettings.sanitize(["uiLanguage": "ar"])
        XCTAssertEqual(safe["uiLanguage"], "ar")
    }

    func testCorruptHistoryAndWriteFailureAreReportedWithoutThrowing() throws {
        try Data("broken".utf8).write(to: file)
        let corrupt = SettingsHistoryStore(fileURL: file)
        XCTAssertNotNil(corrupt.snapshot().warning)
        corrupt.record(key: "uiLanguage", oldValue: "en", newValue: "de", source: .settings)
        corrupt.flush()
        XCTAssertNotNil(SettingsHistoryStore(fileURL: file).snapshot().warning)
        let blocked = SettingsHistoryStore(fileURL: directory)
        blocked.record(key: "uiLanguage", oldValue: "en", newValue: "de", source: .settings)
        blocked.flush()
        XCTAssertNotNil(blocked.snapshot().warning)
    }

    func testSnapshotsRetainLatest20AndClearingPreservesBaselineOnly() {
        let store = SettingsHistoryStore(fileURL: file)
        for i in 0..<25 {
            store.startSession(settings: ["uiLanguage": "en"], environment: ["macOS": "27.0.\(i)"])
        }
        store.flush()
        XCTAssertEqual(store.snapshot().startups.count, 20)
        store.clear(settings: ["uiLanguage": "en"])
        let reloaded = SettingsHistoryStore(fileURL: file).snapshot()
        XCTAssertTrue(reloaded.events.isEmpty)
        XCTAssertTrue(reloaded.startups.isEmpty)
    }

    func testBugFormEncodingExclusionAndLengthFallback() {
        let text = "中文诊断 & # ?\n第二行"
        let link = FeedbackIssueLink.bug(version: "1.2.3", report: text)
        let query = URLComponents(url: link.url, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(query.first(where: { $0.name == "diagnostics" })?.value, text)
        let excluded = FeedbackIssueLink.bug(version: "1.2.3", report: nil)
        XCTAssertFalse(excluded.url.absoluteString.contains("diagnostics"))
        let long = FeedbackIssueLink.bug(version: "1.2.3", report: String(repeating: "中文\n", count: 5000))
        XCTAssertLessThanOrEqual(long.url.absoluteString.utf8.count, 6000)
        XCTAssertTrue(long.omitted)
        XCTAssertTrue(FeedbackIssueLink.feature.absoluteString.contains("feature_request.yml"))
        XCTAssertFalse(FeedbackIssueLink.feature.absoluteString.contains("diagnostics"))
    }

    func testAppearanceSettingsIntegrationRecordsDefaultsAndAllSettings() throws {
        let shared = SharedPreferenceStore(fileURL: directory.appendingPathComponent("preferences.plist"))
        let suite = "FeedbackDiagnosticsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let history = SettingsHistoryStore(fileURL: file)
        let prefs = AppearancePreference(sharedStore: shared, localStore: defaults,
                                         migrateFromAppGroup: false, history: history)
        let previousLanguageOverride = UserDefaults.standard.object(forKey: "AppleLanguages")
        defer {
            if let previousLanguageOverride { UserDefaults.standard.set(previousLanguageOverride, forKey: "AppleLanguages") }
            else { UserDefaults.standard.removeObject(forKey: "AppleLanguages") }
            LocalizationManager.apply(languageCode: "system")
        }
        prefs.uiLanguage = "zh"
        prefs.currentMode = .dark
        prefs.baseFontSize = 18
        prefs.codeHighlightTheme = "github"
        prefs.enableMermaid = false
        prefs.enableKatex = false
        prefs.enableEmoji = false
        prefs.enableTypst = false
        prefs.collapseBlockquotesByDefault = true
        prefs.showLineNumbers = true
        prefs.finderPaneFontSize = 16
        prefs.contentsSide = .left
        prefs.flushSharedPreferences()
        let events = history.snapshot().events
        XCTAssertEqual(Set(events.map(\.key)), Set(DiagnosticSettings.defaults.keys))
        XCTAssertTrue(events.allSatisfy(\.oldWasDefault))
        XCTAssertEqual(shared.string(forKey: "preferredAppearanceMode"), "dark")
    }
    func testMigrationAndToolbarSourcesAndExternalChangeAcrossRestart() {
        let store = SettingsHistoryStore(fileURL: file)
        store.record(key: "uiLanguage", oldValue: "system", newValue: "de", source: .migration, oldWasDefault: true)
        store.observe(settings: ["uiLanguage": "de"])
        store.flush()
        let restarted = SettingsHistoryStore(fileURL: file)
        restarted.startSession(settings: ["uiLanguage": "en"], environment: ["macOS": "27.0.1"])
        let events = restarted.snapshot().events
        XCTAssertEqual(events.map(\.source), [.migration, .externalObserved])
        XCTAssertEqual(events.last?.oldValue, "de")
    }

    func testPrivateValuesInLoadedHistoryAndEnvironmentNeverReachReport() throws {
        var history = SettingsHistorySnapshot()
        history.events = [SettingChange(session: UUID(), date: Date(), appVersion: "private-token",
            key: "uiLanguage", oldValue: "en", newValue: "secret-language", oldWasDefault: false, source: .settings)]
        history.startups = [DiagnosticStartup(session: UUID(), date: Date(), environment: ["appVersion": "private-token", "globalLanguages": "secret", "username": "alice"],
                                              settings: ["uiLanguage": "/Users/alice/private.md"])]
        try JSONEncoder().encode(history).write(to: file)
        let snapshot = SettingsHistoryStore(fileURL: file).snapshot()
        let report = FeedbackReport.markdown(settings: ["uiLanguage": "en", "lastOpenedFilePath": "private.md"],
                                             environment: ["username": "alice", "appVersion": "private-token"], history: snapshot)
        for forbidden in ["alice", "private", "secret", "lastOpenedFilePath"] { XCTAssertFalse(report.contains(forbidden)) }
    }

    func testOversizedUserDescriptionRemainsLocalAndURLIsBounded() {
        let link = FeedbackIssueLink.bug(version: "1.2.3", report: nil, description: String(repeating: "中文", count: 5000))
        XCTAssertLessThanOrEqual(link.url.absoluteString.utf8.count, 6000)
        XCTAssertTrue(link.omitted)
    }

    func testReportIncludesUpgradeSnapshotsAndNewestChangesFirst() {
        let store = SettingsHistoryStore(fileURL: file)
        store.startSession(settings: ["uiLanguage": "en"], environment: ["macOS": "26.0.0"])
        store.startSession(settings: ["uiLanguage": "en"], environment: ["macOS": "27.0.1"])
        store.record(key: "uiLanguage", oldValue: "en", newValue: "de", source: .settings)
        store.record(key: "uiLanguage", oldValue: "de", newValue: "fr", source: .settings)
        let report = FeedbackReport.markdown(settings: ["uiLanguage": "fr"], environment: [:], history: store.snapshot())
        XCTAssertTrue(report.contains("26.0.0"))
        XCTAssertTrue(report.contains("27.0.1"))
        XCTAssertLessThan(report.range(of: "de → fr")!.lowerBound, report.range(of: "en → de")!.lowerBound)
        let permissions = (try! FileManager.default.attributesOfItem(atPath: file.path))[.posixPermissions] as! NSNumber
        XCTAssertEqual(permissions.intValue, 0o600)
    }

    func testLegacyMigrationCallbackCapturesActualCopiedLanguageOnlyOnce() throws {
        let suite = "FeedbackMigrationTests.\(UUID().uuidString)"
        let legacy = UserDefaults(suiteName: suite)!
        defer { legacy.removePersistentDomain(forName: suite) }
        legacy.set("de", forKey: "uiLanguage")
        let shared = SharedPreferenceStore(fileURL: directory.appendingPathComponent("preferences.plist"))
        let history = SettingsHistoryStore(fileURL: file)
        func migrate() {
            shared.migrateFromAppGroupIfNeeded(legacyDefaults: legacy) { key, value in
                history.record(key: key, oldValue: DiagnosticSettings.defaults[key], newValue: value,
                               source: .migration, oldWasDefault: true)
            }
        }
        migrate()
        migrate()
        XCTAssertEqual(shared.string(forKey: "uiLanguage"), "de")
        let events = history.snapshot().events
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.source, .migration)
    }

    func testByteLimitPrunesOldestSnapshotsAndClearDoesNotChangePreferences() throws {
        let history = SettingsHistoryStore(fileURL: file)
        let language = "en" + String(repeating: "-AAAAAAAA", count: 10)
        let languages = Array(repeating: language, count: 20).joined(separator: ",")
        let environment = Dictionary(uniqueKeysWithValues: ["globalLanguages", "applicationLanguages", "preferredLanguages",
            "bundleLocalizations", "bundlePreferred", "activeLanguage", "applicationLanguagesBeforeBootstrap"].map { ($0, languages) })
        for _ in 0..<25 { history.startSession(settings: ["uiLanguage": "de"], environment: environment) }
        history.flush()
        XCTAssertLessThanOrEqual(try Data(contentsOf: file).count, 256 * 1024)
        XCTAssertLessThan(history.snapshot().startups.count, 20)
        let shared = SharedPreferenceStore(fileURL: directory.appendingPathComponent("preferences.plist"))
        shared.set("de", forKey: "uiLanguage")
        shared.synchronize()
        history.clear(settings: ["uiLanguage": "de"])
        XCTAssertEqual(shared.string(forKey: "uiLanguage"), "de")
        XCTAssertEqual(history.snapshot().knownSettings["uiLanguage"], "de")
    }

    func testZeroFontSentinelRecordsEffectiveDefaultValue() {
        let shared = SharedPreferenceStore(fileURL: directory.appendingPathComponent("preferences.plist"))
        shared.set(0.0, forKey: "baseFontSize")
        let suite = "FeedbackSentinelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let history = SettingsHistoryStore(fileURL: file)
        let prefs = AppearancePreference(sharedStore: shared, localStore: defaults,
                                         migrateFromAppGroup: false, history: history)
        XCTAssertEqual(prefs.baseFontSize, 14)
        XCTAssertEqual(prefs.diagnosticSettings["baseFontSize"] as? Double, 14)
        prefs.baseFontSize = 18
        prefs.flushSharedPreferences()
        XCTAssertEqual(history.snapshot().events.first?.oldValue, "14")
        XCTAssertEqual(history.snapshot().events.first?.oldWasDefault, true)
    }

}
