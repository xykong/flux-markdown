import XCTest

final class ReleaseEntitlementsTests: XCTestCase {
    func testProjectUsesReleaseSpecificEntitlements() throws {
        let project = try String(
            contentsOf: projectRoot().appendingPathComponent("project.yml"),
            encoding: .utf8
        )

        XCTAssertTrue(project.contains("CODE_SIGN_ENTITLEMENTS: Sources/Markdown/MarkdownRelease.entitlements"))
        XCTAssertTrue(project.contains("CODE_SIGN_ENTITLEMENTS: Sources/MarkdownPreview/MarkdownPreviewRelease.entitlements"))
        XCTAssertEqual(
            project.components(separatedBy: "CODE_SIGN_INJECT_BASE_ENTITLEMENTS: NO").count - 1,
            2,
            "Both app and QuickLook Release configurations must disable Xcode's base entitlement injection."
        )
    }

    func testReleaseEntitlementsDoNotAllowDebuggerOrHomeDirectoryException() throws {
        let root = projectRoot()
        let appRelease = try String(
            contentsOf: root.appendingPathComponent("Sources/Markdown/MarkdownRelease.entitlements"),
            encoding: .utf8
        )
        let previewRelease = try String(
            contentsOf: root.appendingPathComponent("Sources/MarkdownPreview/MarkdownPreviewRelease.entitlements"),
            encoding: .utf8
        )

        XCTAssertFalse(appRelease.contains("com.apple.security.get-task-allow"))
        XCTAssertFalse(previewRelease.contains("com.apple.security.get-task-allow"))
        XCTAssertFalse(previewRelease.contains("temporary-exception.files.absolute-path.read-only"))
        XCTAssertFalse(previewRelease.contains("$HOME"))
        XCTAssertFalse(previewRelease.contains("/Users/"))
        XCTAssertTrue(previewRelease.contains("temporary-exception.files.home-relative-path.read-only"))
        XCTAssertTrue(previewRelease.contains("/Library/Application Support/FluxMarkdown/"))
        XCTAssertTrue(previewRelease.contains("com.apple.security.app-sandbox"))
    }

    func testReleaseVerificationRejectsDebugEntitlements() throws {
        let script = try String(
            contentsOf: projectRoot().appendingPathComponent("scripts/verify-release-entitlements.sh"),
            encoding: .utf8
        )

        XCTAssertTrue(script.contains("com.apple.security.get-task-allow"))
        XCTAssertTrue(script.contains("com.apple.security.temporary-exception.files.absolute-path.read-only"))
        XCTAssertTrue(script.contains("/Users/"))
        XCTAssertTrue(script.contains("release entitlements must not include"))
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
