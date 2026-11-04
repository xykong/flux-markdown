import XCTest
import AppKit

final class RendererExportPreparationTests: XCTestCase {
    func testOnlyKnownPreparationPayloadsAreAccepted() {
        XCTAssertEqual(RendererExportPreparation.decode(["status":"mathematics"]), .mathematics)
        XCTAssertEqual(RendererExportPreparation.decode(["status":"ready", "html":"<p>ok</p>"]), .ready(html: "<p>ok</p>"))
        XCTAssertEqual(RendererExportPreparation.decode(["status":"ready"]), .ready(html: nil))
        XCTAssertNil(RendererExportPreparation.decode(["status":"mathematics", "source":"private"]))
        XCTAssertNil(RendererExportPreparation.decode(["status":"ready", "html":42]))
        XCTAssertNil(RendererExportPreparation.decode(["status":"other"]))
    }

    func testExportIncidentKeepsOperationAndUsesMathematicalGuidance() throws {
        for kind in [FailureKind.exportHTML, .exportPDF] {
            var incident=ErrorIncident(kind:kind,source:.app)
            incident.renderingBlocker = .math
            XCTAssertTrue(incident.isValid)
            XCTAssertEqual(incident.kind,kind)
            XCTAssertEqual(incident.guidance,FailureKind.math.guidance)
            let decoded=try JSONDecoder().decode(ErrorIncident.self,from:JSONEncoder().encode(incident))
            XCTAssertEqual(decoded.renderingBlocker,.math)
            XCTAssertEqual(decoded.guidance,FailureKind.math.guidance)
        }
        var invalid=ErrorIncident(kind:.copy,source:.app)
        invalid.renderingBlocker = .math
        XCTAssertFalse(invalid.isValid)
    }
    func testExistingIncidentsDecodeWithoutRenderingBlocker() throws {
        let original = ErrorIncident(kind: .exportPDF, source: .app)
        let decoded = try JSONDecoder().decode(ErrorIncident.self, from: JSONEncoder().encode(original))
        XCTAssertNil(decoded.renderingBlocker)
        XCTAssertEqual(decoded.guidance, FailureKind.exportPDF.guidance)
        var invalid = original
        invalid.renderingBlocker = .copy
        XCTAssertFalse(invalid.isValid)
    }

    func testMathematicalExportNoticeOffersRecoveryAndContextualFeedback() {
        var incident = ErrorIncident(kind: .exportPDF, source: .app)
        incident.renderingBlocker = .math
        var recovered = false
        let notice = IncidentNotice(incident: incident, recoveryTitle: "Open in Editor", recovery: { recovered = true })
        let stack = notice.subviews.first as! NSStackView
        let message = stack.arrangedSubviews.first as! NSTextField
        XCTAssertTrue(message.stringValue.contains(FailureKind.exportPDF.title))
        XCTAssertTrue(message.stringValue.contains(FailureKind.math.guidance))
        let buttons = stack.arrangedSubviews.compactMap { $0 as? NSStackView }.first!
        let actions = buttons.arrangedSubviews.compactMap { $0 as? NSButton }
        XCTAssertEqual(actions.first?.title, "Open in Editor")
        actions.first?.performClick(nil)
        XCTAssertTrue(recovered)
        XCTAssertTrue(actions.contains { $0.title == "Report This Problem" })
        XCTAssertTrue(incident.report.contains("Rendering blocker: math"))
    }

}
