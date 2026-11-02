import XCTest

final class UpdateDiagnosticsTests: XCTestCase {
    func testSessionSnapshotIsFrozenBoundedAndSurvivesRestart() throws {
        let suite = "UpdateSessionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let diagnostics = UpdateDiagnostics(defaults: defaults)
        diagnostics.beginSession()
        diagnostics.event(.downloadStarted)
        diagnostics.event(.downloadCompleted)
        let error = NSError(domain: "SUSparkleErrorDomain", code: 10,
                            userInfo: [NSLocalizedDescriptionKey: "Timeout: agent connection was never initiated"])
        let frozen = diagnostics.freeze(error: error)
        XCTAssertEqual(frozen.events.last?.stage, .failed)
        XCTAssertEqual(frozen.failure, .agentConnectionTimeout)
        diagnostics.event(.cycleFinished)
        XCTAssertEqual(diagnostics.freeze(error: error).events.count, frozen.events.count)
        XCTAssertEqual(UpdateDiagnostics(defaults: defaults).latestSession?.id, frozen.id)
        diagnostics.beginSession()
        for _ in 0..<100 { diagnostics.event(.downloadStarted) }
        let next = diagnostics.freeze(error: error)
        XCTAssertNotEqual(next.id, frozen.id)
        XCTAssertLessThanOrEqual(next.events.count, 32)
        XCTAssertTrue(next.truncated)
        XCTAssertTrue(next.isValid)
        XCTAssertEqual(frozen.events.map(\.stage), [.checkStarted, .downloadStarted, .downloadCompleted, .failed])
    }

    func testSessionDoesNotPersistRawErrorAndUnknownTextIsNotClassified() throws {
        let suite = "UpdateSessionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let diagnostics = UpdateDiagnostics(defaults: defaults)
        let error = NSError(domain: "SUSparkleErrorDomain", code: 10,
                            userInfo: [NSLocalizedDescriptionKey: "Timeout: agent connection was never initiated /Users/private/token"])
        let snapshot = diagnostics.freeze(error: error)
        XCTAssertEqual(snapshot.failure, .unclassified)
        let text = String(decoding: try JSONEncoder().encode(snapshot), as: UTF8.self)
        XCTAssertFalse(text.contains("private"))
        var incident = ErrorIncident(kind: .update, source: .app)
        incident.updateSession = snapshot
        XCTAssertTrue(incident.isValid)
        XCTAssertEqual(ErrorIncident.decode(try incident.encoded())?.updateSession?.id, snapshot.id)
    }

    func testOnlyThreeSessionsPersistAndInvalidHistoryIsIgnored() throws {
        let suite = "UpdateSessionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let diagnostics = UpdateDiagnostics(defaults: defaults)
        for _ in 0..<5 { diagnostics.beginSession(); diagnostics.event(.cancelled) }
        let data = try XCTUnwrap(defaults.data(forKey: "updateSessions.v1"))
        let saved = try JSONDecoder().decode([UpdateSessionSnapshot].self, from: data)
        XCTAssertEqual(saved.count, 3)
        var invalid = saved[0]
        invalid.events = [UpdateSessionEvent(stage: .checkStarted, date: Date(), elapsed: -1)]
        defaults.set(try JSONEncoder().encode([invalid]), forKey: "updateSessions.v1")
        XCTAssertNil(diagnostics.latestSession)
        var incident = ErrorIncident(kind: .update, source: .app)
        incident.updateSession = invalid
        XCTAssertNil(ErrorIncident.decode(try incident.encoded()))
    }

    func testNonSandboxedHostDoesNotEnableSandboxInstaller() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let info = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: root.appendingPathComponent("Sources/Markdown/Info.plist")), format: nil) as? [String: Any])
        XCTAssertNotEqual(info["SUEnableInstallerLauncherService"] as? Bool, true)
        for file in ["Markdown.entitlements", "MarkdownRelease.entitlements"] {
            let entitlements = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: root.appendingPathComponent("Sources/Markdown/\(file)")), format: nil) as? [String: Any])
            XCTAssertNotEqual(entitlements["com.apple.security.app-sandbox"] as? Bool, true)
            XCTAssertNil(entitlements["com.apple.security.temporary-exception.mach-lookup.global-name"])
            XCTAssertNil(entitlements["com.apple.security.temporary-exception.files.absolute-path.read-write"])
        }
    }

    func testFailureSurvivesRestartWithoutExportingPrivateErrorDetails() throws {
        let suite = "UpdateDiagnosticsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let underlying = NSError(domain: NSPOSIXErrorDomain, code: 1,
                                 userInfo: [NSFilePathErrorKey: "/Users/private/document.md"])
        let error = NSError(domain: "SUSparkleErrorDomain", code: 4005,
                            userInfo: [NSUnderlyingErrorKey: underlying,
                                       NSLocalizedDescriptionKey: "Secret URL https://private.example/token"])
        UpdateDiagnostics(defaults: defaults).record(error: error, sourceVersion: "1.36.568", targetVersion: "1.36.582", date: Date(timeIntervalSince1970: 0))
        let report = UpdateDiagnostics(defaults: defaults).summary()
        XCTAssertTrue(report.contains("SUSparkleErrorDomain:4005 → NSPOSIXErrorDomain:1"))
        XCTAssertTrue(report.contains("1.36.568 → 1.36.582"))
        XCTAssertTrue(report.contains("1970-01-01T00:00:00Z"))
        XCTAssertFalse(report.contains("/Users/private"))
        XCTAssertFalse(report.contains("private.example"))
        XCTAssertFalse(report.contains("Secret"))
        XCTAssertFalse(String(describing: defaults.dictionaryRepresentation()).contains("document.md"))
    }

    func testUnknownDomainsAndDeepErrorsAreBounded() throws {
        let suite = "UpdateDiagnosticsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var error = NSError(domain: "secret-domain", code: 42)
        for _ in 0..<20 { error = NSError(domain: "secret-domain", code: 42, userInfo: [NSUnderlyingErrorKey: error]) }
        let diagnostics = UpdateDiagnostics(defaults: defaults)
        diagnostics.record(error: error, sourceVersion: "private", targetVersion: nil)
        let report = diagnostics.summary()
        XCTAssertFalse(report.contains("secret-domain"))
        XCTAssertTrue(report.contains("versions: invalid → unknown"))
        XCTAssertEqual(report.components(separatedBy: "other:42").count - 1, 8)
    }

    func testNoFailureIsExplicit() throws {
        let suite = "UpdateDiagnosticsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertTrue(UpdateDiagnostics(defaults: defaults).summary().contains("No recorded update failure"))
    }
}
