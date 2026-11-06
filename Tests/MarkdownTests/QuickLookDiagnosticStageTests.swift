import XCTest

final class QuickLookDiagnosticStageTests: XCTestCase {
    func testStagesCarryOnlyValidatedIdentityAndSafeErrors() {
        let token = UUID().uuidString
        let attempt = UUID()
        let error = NSError(domain: "private/path?credential=SECRET", code: 513, userInfo: [NSLocalizedDescriptionKey: "private document SECRET"])
        let event = QuickLookProbeEvidence.diagnosticMarker(token: token, version: "1.44.761", build: "761", stage: .fileReadFailed, attempt: attempt, context: .quicklook, error: error)
        XCTAssertEqual(event, "FluxQuickLookStage schema=2 token=\(token) version=1.44.761 build=761 attempt=\(attempt.uuidString) context=quicklook stage=fileReadFailed error=other code=513")
        XCTAssertFalse(event?.contains("SECRET") ?? true)
        XCTAssertNil(QuickLookProbeEvidence.diagnosticMarker(token: "bad", version: "1.44.761", build: "761", stage: .prepared, attempt: attempt, context: .quicklook))
        XCTAssertNil(QuickLookProbeEvidence.diagnosticMarker(token: token, version: "SECRET\n", build: "761", stage: .prepared, attempt: attempt, context: .quicklook))
        XCTAssertNil(QuickLookProbeEvidence.diagnosticMarker(token: token, version: "1.44.761", build: "unknown", stage: .prepared, attempt: attempt, context: .quicklook))
    }
    func testStageVocabularyIncludesEachFailureAndSuccess() {
        XCTAssertEqual(Set(QuickLookDiagnosticStage.allCases.map(\.rawValue)), Set(["prepared", "fileRead", "fileReadFailed", "handshake", "handshakeTimeout", "renderStarted", "rendered", "rendererFailed", "renderUnverified", "sourceMode"]))
        let marker = QuickLookProbeEvidence.diagnosticMarker(token: UUID().uuidString, version: "1.44.761", build: "761", stage: .rendererFailed, attempt: UUID(), context: .compact, error: NSError(domain: NSCocoaErrorDomain, code: 260))
        XCTAssertTrue(marker?.hasSuffix("error=NSCocoaErrorDomain code=260") == true)
    }
}
