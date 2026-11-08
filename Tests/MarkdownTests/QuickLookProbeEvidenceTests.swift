import XCTest

final class QuickLookProbeEvidenceTests: XCTestCase {
    func testOnlyDedicatedUUIDFixtureGetsProbeMarker() {
        let id = UUID().uuidString
        XCTAssertEqual(QuickLookProbeEvidence.token(for: URL(fileURLWithPath: "/tmp/flux-quicklook-probe-\(id).md")), id)
        XCTAssertNil(QuickLookProbeEvidence.token(for: URL(fileURLWithPath: "/tmp/personal.md")))
        XCTAssertNil(QuickLookProbeEvidence.token(for: URL(fileURLWithPath: "/tmp/flux-quicklook-probe-invalid.md")))
    }
    func testOnlyMatchingRenderedExtensionEventIsSuccess() throws {
        let id = UUID().uuidString
        let executable = URL(fileURLWithPath: "/Applications/FluxMarkdown.app/Contents/PlugIns/MarkdownPreview.appex/Contents/MacOS/MarkdownPreview")
        func evidence(_ stage: String, version: String = "1.36.561", build: String = "561", process: String = "/Applications/FluxMarkdown.app/Contents/PlugIns/MarkdownPreview.appex/Contents/MacOS/MarkdownPreview") throws -> String {
            let data = try JSONSerialization.data(withJSONObject: [["eventMessage": QuickLookProbeEvidence.marker(token: id, version: version, build: build, stage: stage), "subsystem":"com.markdownquicklook.app", "processImagePath":process]])
            return String(decoding: data, as: UTF8.self)
        }
        XCTAssertFalse(QuickLookProbeEvidence.rendered(in: try evidence("rendered", build: "562"), token: id, version: "1.36.561", build: "561", executableURL: executable))
        XCTAssertFalse(QuickLookProbeEvidence.rendered(in: "not JSON", token: id, version: "1.36.561", build: "561", executableURL: executable))
        XCTAssertTrue(QuickLookProbeEvidence.rendered(in: try evidence("rendered"), token: id, version: "1.36.561", build: "561", executableURL: executable))
        XCTAssertFalse(QuickLookProbeEvidence.rendered(in: try evidence("prepared"), token: id, version: "1.36.561", build: "561", executableURL: executable))
        XCTAssertFalse(QuickLookProbeEvidence.rendered(in: try evidence("rendered", version: "old"), token: id, version: "1.36.561", build: "561", executableURL: executable))
        XCTAssertFalse(QuickLookProbeEvidence.rendered(in: try evidence("rendered", process: "/tmp/development/FluxMarkdown.app/Contents/PlugIns/MarkdownPreview.appex/Contents/MacOS/MarkdownPreview"), token: id, version: "1.36.561", build: "561", executableURL: executable))
        XCTAssertFalse(QuickLookProbeEvidence.rendered(in: try evidence("rendered", process: "/usr/bin/log"), token: id, version: "1.36.561", build: "561", executableURL: executable))
        XCTAssertFalse(QuickLookProbeEvidence.rendered(in: try evidence("rendered"), token: UUID().uuidString, version: "1.36.561", build: "561", executableURL: executable))
    }
}
