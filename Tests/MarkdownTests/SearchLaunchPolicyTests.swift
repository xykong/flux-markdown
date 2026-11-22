import Foundation
import XCTest

final class SearchLaunchPolicyTests: XCTestCase {
    func testOnlyExplicitLocalDocumentSearchIsAccepted() throws {
        let url = try XCTUnwrap(DocumentOpenRequest.searchURL(for: URL(fileURLWithPath: "/tmp/中文 & notes.md")))
        XCTAssertEqual(SearchLaunchPolicy.request(url.absoluteString)?.fileURL.path, "/tmp/中文 & notes.md")
        for input in ["https://example.com", "markdownpreview://open?path=/tmp/a.md", "markdownpreview://open?path=relative&find=1", "markdownpreview://open?path=/tmp/a.md&find=1&find=1", String(repeating: "a", count: 8193)] {
            XCTAssertNil(SearchLaunchPolicy.request(input))
        }
    }

    func testTSVHandoffAcceptsUppercaseExtension() throws {
        let file = URL(fileURLWithPath: "/tmp/table.TSV")
        let url = try XCTUnwrap(DocumentOpenRequest.searchURL(for: file))
        XCTAssertEqual(SearchLaunchPolicy.request(url.absoluteString)?.fileURL, file)
    }

    func testAnUnverifiedPeerCannotUseTheBroker() {
        XCTAssertTrue(SearchLaunchPolicy.acceptsPeer(sameUser: true, validSignature: true,
            identifier: "com.xykong.Markdown.QuickLook", expectedExecutable: true))
        XCTAssertFalse(SearchLaunchPolicy.acceptsPeer(sameUser: false, validSignature: true,
            identifier: "com.xykong.Markdown.QuickLook", expectedExecutable: true))
        XCTAssertFalse(SearchLaunchPolicy.acceptsPeer(sameUser: true, validSignature: false,
            identifier: "com.xykong.Markdown.QuickLook", expectedExecutable: true))
        XCTAssertFalse(SearchLaunchPolicy.acceptsPeer(sameUser: true, validSignature: true,
            identifier: "com.apple.finder", expectedExecutable: true))
        XCTAssertFalse(SearchLaunchPolicy.acceptsPeer(sameUser: true, validSignature: true,
            identifier: "com.xykong.Markdown.QuickLook", expectedExecutable: false))
    }
}

extension SearchLaunchPolicyTests {
    func testBrokerHasOnlyScopedTelemetryAndFeedbackStorageAndNetworkPermissions() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Sources/SearchLauncher/SearchLauncher.entitlements"))
        let p = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(Set(p.keys), ["com.apple.security.app-sandbox", "com.apple.security.files.user-selected.read-only", "com.apple.security.network.client", "com.apple.security.temporary-exception.files.home-relative-path.read-write"])
        XCTAssertEqual(p["com.apple.security.temporary-exception.files.home-relative-path.read-write"] as? [String], ["/Library/Application Support/FluxMarkdown/Telemetry/", "/Library/Application Support/FluxMarkdown/FeedbackTransfers/"])
        XCTAssertEqual(p["com.apple.security.network.client"] as? Bool, true)
    }
}
