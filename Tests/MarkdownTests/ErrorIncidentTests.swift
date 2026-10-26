import XCTest

final class ErrorIncidentTests: XCTestCase {
    func testSafeSnapshotRoundTripAndPrivateValuesExcluded() throws {
        let error = NSError(domain: "SUSparkleErrorDomain", code: 4005, userInfo: [NSLocalizedDescriptionKey: "secret /Users/name/private.md", NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: 13)])
        let incident = ErrorIncident(kind: .update, source: .app, error: error,
                                     environment: ["appVersion": "1.36.582", "macOS": "27.0.1", "path": "/Users/name/private.md"],
                                     settings: ["baseFontSize": "14", "uiLanguage": "secret"])
        let data = try incident.encoded()
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("private.md"))
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("secret"))
        let decoded = try XCTUnwrap(ErrorIncident.decode(data))
        XCTAssertEqual(decoded.id, incident.id)
        XCTAssertEqual(decoded.codes.map(\.code), [4005, 13])
        XCTAssertTrue(decoded.report.contains("SUSparkleErrorDomain:4005"))
    }

    func testRejectsMaliciousAndOversizedHandoff() throws {
        let incident = ErrorIncident(kind: .renderer, source: .quicklook)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: incident.encoded()) as? [String: Any])
        json["environment"] = ["appVersion": "/Users/private/file"]
        XCTAssertNil(ErrorIncident.decode(try JSONSerialization.data(withJSONObject: json)))
        XCTAssertNil(ErrorIncident.decode(Data(repeating: 65, count: 16385)))
        XCTAssertNil(ErrorIncident.decode(Data("{}".utf8)))
    }

    func testReportURLContainsSelectedIncidentAndHonorsExclusion() throws {
        let incident = ErrorIncident(kind: .exportPDF, source: .app, environment: ["appVersion": "1.36.582"])
        let url = incident.feedbackURL(includeDiagnostics: true, notes: "Expected a PDF", useTemplate: true)
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.first { $0.name == "template" }?.value, "app_error.yml")
        XCTAssertTrue(items.first { $0.name == "description" }?.value?.contains("exportPDF") == true)
        XCTAssertTrue(items.first { $0.name == "diagnostics" }?.value?.contains(incident.id.uuidString) == true)
        XCTAssertLessThanOrEqual(url.absoluteString.utf8.count, 6000)
        let excluded = URLComponents(url: incident.feedbackURL(includeDiagnostics: false), resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertNil(excluded.first { $0.name == "diagnostics" })
    }

    func testHistoryIsBoundedPersistentAndClearedWithoutSettings() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("incidents.json")
        let store = ErrorIncidentStore(fileURL: file)
        for _ in 0..<120 { store.record(ErrorIncident(kind: .renderer, source: .app)) }
        XCTAssertLessThanOrEqual(store.incidents.count, 100)
        XCTAssertLessThanOrEqual(try Data(contentsOf: file).count, 65536)
        XCTAssertEqual(ErrorIncidentStore(fileURL: file).incidents.last?.id, store.incidents.last?.id)
        store.clear()
        XCTAssertTrue(ErrorIncidentStore(fileURL: file).incidents.isEmpty)
    }

    func testStaleOrUntrustedRendererEventIsRejected() {
        let registry = RendererErrorRegistry()
        let generation = registry.beginDocument()
        XCTAssertNil(registry.receive(["action": "report", "kind": "mermaid", "generation": "old", "id": "1"]))
        XCTAssertNil(registry.receive(["action": "report", "kind": "mermaid", "generation": generation, "id": "1"]))
        XCTAssertNotNil(registry.receive(["action": "record", "kind": "mermaid", "generation": generation, "id": "1"]))
        XCTAssertNotNil(registry.receive(["action": "report", "kind": "mermaid", "generation": generation, "id": "1"]))
        _ = registry.beginDocument()
        XCTAssertNil(registry.receive(["action": "report", "kind": "mermaid", "generation": generation, "id": "1"]))
    }
}

extension ErrorIncidentTests {
    func testUnicodeNotesAndLargeReportAlwaysRespectURLBudget() throws {
        var incident = ErrorIncident(kind: .renderer, source: .app, environment: ["appVersion": "1.36.582"])
        incident.steps = (0..<12).map { _ in IncidentStep(kind: .renderer, phase: .started, date: Date()) }
        let url = incident.feedbackURL(notes: String(repeating: "😀", count: 6000), useTemplate: true)
        XCTAssertLessThanOrEqual(url.absoluteString.utf8.count, 6000)
        let description = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "description" }!.value!
        XCTAssertTrue(description.contains("omitted"))
        XCTAssertTrue(description.contains("Operation: renderer"))
    }

    func testRelatedEventsDoNotIncludeAnotherDocument() {
        let scopeA = UUID(), scopeB = UUID()
        _ = ErrorFeedback.capture(.renderer, phase: .started, scope: scopeA)
        _ = ErrorFeedback.capture(.exportPDF, phase: .started, scope: scopeB)
        let failure = ErrorFeedback.capture(.renderer, scope: scopeA)
        XCTAssertFalse(failure.steps.contains { $0.kind == .exportPDF })
    }

    func testFoundationDocumentErrorProvidesRecoveryAndFeedback() {
        let error = DocumentReadFailure(kind: .fileRead, error: CocoaError(.fileReadCorruptFile))
        XCTAssertTrue(error.recoveryOptions.contains("Report This Problem"))
        XCTAssertTrue(error.recoveryOptions.contains("Choose Another File"))
        XCTAssertFalse(error.attemptRecovery(optionIndex: 3))
    }

    func testRequestRoundTripHonorsDiagnosticsOptOutAndReviewMode() throws {
        var request = IncidentFeedbackRequest(incident: ErrorIncident(kind: .renderer, source: .quicklook), includeDiagnostics: false, notes: "optional explanation")
        request.review = true
        let url = try XCTUnwrap(request.hostURL)
        XCTAssertEqual(url.host, "report-error")
        let data = Data(base64Encoded: URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems![0].value!)!
        let decoded = try XCTUnwrap(IncidentFeedbackRequest.decode(data))
        XCTAssertFalse(decoded.includeDiagnostics)
        XCTAssertTrue(decoded.review)
    }
}

extension ErrorIncidentTests {
    func testNativeFailuresDeduplicateOnlyWithinOneDocumentGeneration() {
        let registry = RendererErrorRegistry()
        let first = registry.nativeFailure(.reload, error: CocoaError(.fileReadNoPermission))
        XCTAssertEqual(first.id, registry.nativeFailure(.reload, error: CocoaError(.fileReadNoPermission)).id)
        _ = registry.beginDocument()
        XCTAssertNotEqual(first.id, registry.nativeFailure(.reload, error: CocoaError(.fileReadNoPermission)).id)
    }
    func testDefaultURLWorksWithoutAnUnpublishedTemplate() {
        let incident = ErrorIncident(kind: .renderer, source: .app)
        let items = URLComponents(url: incident.feedbackURL(), resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertNil(items.first { $0.name == "template" })
        XCTAssertTrue(items.first { $0.name == "body" }!.value!.contains(incident.id.uuidString))
        let excluded = URLComponents(url: incident.feedbackURL(includeDiagnostics: false), resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertFalse(excluded.first { $0.name == "body" }!.value!.contains(incident.id.uuidString))
    }
    func testUnavailableStoreRetainsCurrentIncidentInMemory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ErrorIncidentStore(fileURL: root)
        let incident = ErrorIncident(kind: .renderer, source: .app)
        store.record(incident)
        XCTAssertTrue(store.unavailable)
        XCTAssertEqual(store.incidents.first?.id, incident.id)
    }
}

extension ErrorIncidentTests {
    func testOneClickOpensTheSelectedReportAndDoubleClickDoesNotOpenAnother() {
        let draft = IncidentDraft(ErrorIncident(kind: .exportHTML, source: .app))
        draft.includeDiagnostics = false
        var urls: [URL] = []
        ErrorFeedback.report(draft, openURL: { urls.append($0); return true })
        ErrorFeedback.report(draft, openURL: { urls.append($0); return true })
        XCTAssertEqual(urls.count, 1)
        let body = URLComponents(url: urls[0], resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "body" }!.value!
        XCTAssertTrue(body.contains("exportHTML"))
        XCTAssertFalse(body.contains(draft.incident.id.uuidString))
    }
    func testBrowserFailurePreservesTheSameDraftAndOptionalNotes() {
        let draft = IncidentDraft(ErrorIncident(kind: .update, source: .app))
        draft.notes = "User explanation"
        var received: IncidentDraft?
        ErrorFeedback.report(draft, failure: { received = $0 }, openURL: { _ in false })
        XCTAssertTrue(received === draft)
        XCTAssertEqual(received?.notes, "User explanation")
    }
    func testLongOptionalNotesHaveAnOmissionNotice() {
        let incident = ErrorIncident(kind: .renderer, source: .app)
        let url = incident.feedbackURL(notes: String(repeating: "a", count: 1000))
        let body = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "body" }!.value!
        XCTAssertTrue(body.contains("omitted"))
    }
}

extension ErrorIncidentTests {
    func testExcludingDiagnosticsStillLeavesAnActionableCopiedReport() {
        let draft = IncidentDraft(ErrorIncident(kind: .exportPDF, source: .app))
        draft.includeDiagnostics = false
        XCTAssertTrue(draft.report.contains("exportPDF"))
        XCTAssertFalse(draft.report.contains(draft.incident.id.uuidString))
    }
    func testUpdateCaptureUsesRelevantSettingsAndTargetVersion() {
        let incident = ErrorFeedback.capture(.update, targetVersion: "1.36.582")
        XCTAssertEqual(incident.environment["targetVersion"], "1.36.582")
        XCTAssertNil(incident.settings["enableMermaid"])
    }
    func testNativeNoticeFitsNarrowPreviewAndRemainsUsableWithoutWebKit() {
        let parent = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 700))
        IncidentNotice.attach(to: parent, incident: ErrorIncident(kind: .renderer, source: .quicklook), recoveryTitle: "Reload", recovery: {})
        parent.layoutSubtreeIfNeeded()
        let notice = parent.subviews.compactMap { $0 as? IncidentNotice }.first!
        notice.layoutSubtreeIfNeeded()
        XCTAssertLessThanOrEqual(notice.frame.maxX, parent.bounds.maxX)
        XCTAssertGreaterThan(notice.frame.height, 50)
        let stack = notice.subviews.first as! NSStackView
        let buttons = stack.arrangedSubviews.compactMap { $0 as? NSStackView }.first!
        XCTAssertEqual(buttons.orientation, .vertical)
        XCTAssertTrue(buttons.arrangedSubviews.compactMap { ($0 as? NSButton)?.title }.contains("Report This Problem"))
    }
}

extension ErrorIncidentTests {
    func testNativeGuidanceRecoveryAndDismissalAcrossTheCoverageInventory() {
        for kind in FailureKind.allCases {
            var recovered = false
            let incident = ErrorIncident(kind: kind, source: .app)
            let notice = IncidentNotice(incident: incident, recoveryTitle: "Try Again", recovery: { recovered = true })
            let stack = notice.subviews.first as! NSStackView
            let message = stack.arrangedSubviews.first as! NSTextField
            XCTAssertTrue(message.stringValue.contains(kind.guidance))
            let buttons = stack.arrangedSubviews.compactMap { $0 as? NSStackView }.first!
            let recover = buttons.arrangedSubviews.compactMap { $0 as? NSButton }.first!
            recover.performClick(nil)
            XCTAssertTrue(recovered, kind.rawValue)
            XCTAssertTrue(buttons.arrangedSubviews.compactMap { ($0 as? NSButton)?.title }.contains("Report This Problem"))
        }
    }
    func testAllIncidentGuidanceHasTranslationsForBothBundles() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let keys = FailureKind.allCases.flatMap { [$0.title, $0.guidance] } + ["Report This Problem", "Review Feedback…", "Include diagnostics", "Open Feedback Page", "Copy Report", "Save Report…", "Close"]
        for target in ["Markdown", "MarkdownPreview"] {
            for language in ["en", "zh-Hans", "de", "fr", "es", "ar"] {
                let data = try Data(contentsOf: root.appendingPathComponent("Sources/\(target)/\(language).lproj/Localizable.strings"))
                let strings = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
                for key in keys { XCTAssertNotNil(strings[key], "\(target)/\(language): \(key)") }
            }
        }
    }
}

extension ErrorIncidentTests {
    func testQuickLookSupplementAcceptsOnlyTypedStatusesAndKeepsItsOwnTime() throws {
        let fields = IncidentQuickLookCheck.sanitize(["registeredCopies": "2", "signature": "valid", "documentUTI": "/private/document", "lastExplicitPreviewTest": "rendered", "lastExplicitPreviewTestAt": "2026-10-18T10:00:00Z"])
        XCTAssertNil(fields["documentUTI"])
        var incident = ErrorIncident(kind: .quickLook, source: .quicklook)
        incident.quickLookCheck = IncidentQuickLookCheck(date: Date(), fields: fields)
        XCTAssertNotNil(ErrorIncident.decode(try incident.encoded()))
        XCTAssertTrue(incident.report.contains("collected at report time"))
        XCTAssertFalse(incident.report.contains("/private"))
    }
}

extension ErrorIncidentTests {
    func testSupplementTimeoutDoesNotBlockOneClickFeedbackOrReplaceUserNotes() {
        let previous = ErrorFeedback.supplementProvider
        defer { ErrorFeedback.supplementProvider = previous }
        ErrorFeedback.supplementProvider = { _, _ in }
        let opened = expectation(description: "feedback opens with available diagnostics")
        let draft = IncidentDraft(ErrorIncident(kind: .quickLook, source: .app))
        draft.notes = "Optional user explanation"
        ErrorFeedback.report(draft, openURL: { url in
            let body = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "body" }!.value!
            XCTAssertTrue(body.contains("Optional user explanation"))
            opened.fulfill(); return true
        })
        wait(for: [opened], timeout: 4)
    }
}

extension ErrorIncidentTests {
    func testDocumentFailureBridgesActualNSErrorRecoveryOptions() {
        let error = DocumentReadFailure(kind: .fileRead, error: CocoaError(.fileReadCorruptFile)) as NSError
        XCTAssertTrue(error.localizedRecoveryOptions?.contains("Report This Problem") == true)
        let attempter = error.userInfo[NSRecoveryAttempterErrorKey] as? NSObject
        XCTAssertNotNil(attempter)
        XCTAssertTrue(attempter?.responds(to: NSSelectorFromString("attemptRecoveryFromError:optionIndex:")) == true)
        XCTAssertTrue(attempter?.responds(to: NSSelectorFromString("attemptRecoveryFromError:optionIndex:delegate:didRecoverSelector:contextInfo:")) == true)
    }
}

private final class RecoveryCallbackProbe: NSObject {
    var calls = 0
    var recovered: Bool?
    var context: UnsafeMutableRawPointer?
    @objc func finished(_ recovered: Bool, contextInfo: UnsafeMutableRawPointer?) {
        calls += 1; self.recovered = recovered; context = contextInfo
    }
}

extension ErrorIncidentTests {
    func testAppKitRecoveryCallbacksCompleteOnceWithoutPresentingOnClose() throws {
        let error = DocumentReadFailure(kind: .fileRead, error: CocoaError(.fileReadCorruptFile)) as NSError
        let attempter = try XCTUnwrap(error.recoveryAttempter as? DocumentErrorRecoveryAttempter)
        XCTAssertFalse(attempter.attemptRecovery(fromError: error, optionIndex: 3))
        let probe = RecoveryCallbackProbe()
        let context = UnsafeMutableRawPointer(bitPattern: 42)
        attempter.attemptRecovery(fromError: error, optionIndex: 3, delegate: probe,
                          didRecoverSelector: #selector(RecoveryCallbackProbe.finished(_:contextInfo:)), contextInfo: context)
        XCTAssertEqual(probe.calls, 1)
        XCTAssertEqual(probe.recovered, false)
        XCTAssertEqual(probe.context, context)
    }
}
