import XCTest
import AppKit
import WebKit

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
        let notice = IncidentNotice(incident: incident, recoveryTitle: "Open in External Editor", recovery: { recovered = true })
        let stack = notice.subviews.first as! NSStackView
        let message = stack.arrangedSubviews.first as! NSTextField
        XCTAssertTrue(message.stringValue.contains(FailureKind.exportPDF.title))
        XCTAssertTrue(message.stringValue.contains(FailureKind.math.guidance))
        let buttons = stack.arrangedSubviews.compactMap { $0 as? NSStackView }.first!
        let actions = buttons.arrangedSubviews.compactMap { $0 as? NSButton }
        XCTAssertEqual(actions.first?.title, "Open in External Editor")
        actions.first?.performClick(nil)
        XCTAssertTrue(recovered)
        XCTAssertTrue(actions.contains { $0.title == "Report This Problem" })
        XCTAssertTrue(incident.report.contains("Rendering blocker: math"))
    }

}

extension RendererExportPreparationTests {
    func testNativeWebViewExposesIncidentActionsToAccessibility() throws {
        let webView = NativeMagnifyingWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 700), configuration: WKWebViewConfiguration())
        IncidentNotice.attach(to: webView, incident: ErrorIncident(kind: .exportHTML, source: .app), recoveryTitle: "Open in External Editor", recovery: {})
        let notice = try XCTUnwrap(webView.subviews.compactMap { $0 as? IncidentNotice }.first)
        XCTAssertTrue((webView.accessibilityChildren() ?? []).contains { ($0 as? NSView) === notice })
        XCTAssertEqual(notice.accessibilityRole(), .group)
        notice.removeFromSuperview()
        XCTAssertFalse((webView.accessibilityChildren() ?? []).contains { ($0 as? NSView) === notice })
    }

    func testExportEditorRecoveryTranslationExistsInEveryAppLanguage() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        for language in ["en", "zh-Hans", "de", "fr", "es", "ar"] {
            let data = try Data(contentsOf: root.appendingPathComponent("Sources/Markdown/\(language).lproj/Localizable.strings"))
            let strings = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String:String])
            XCTAssertNotNil(strings["Open in External Editor"])
        }
    }
}
