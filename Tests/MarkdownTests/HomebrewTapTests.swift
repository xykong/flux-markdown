import XCTest

final class HomebrewTapTests: XCTestCase {
    func testHomebrewUpdateScriptKeepsOfficialDraftOutOfTapCasksDirectory() throws {
        let root = projectRoot()
        let updateScript = try String(
            contentsOf: root.appendingPathComponent("scripts/update-homebrew-cask.sh"),
            encoding: .utf8
        )
        let submitScript = try String(
            contentsOf: root.appendingPathComponent("scripts/submit-to-homebrew.sh"),
            encoding: .utf8
        )

        XCTAssertTrue(updateScript.contains("../homebrew-tap/Drafts/flux-markdown-official.rb"))
        XCTAssertTrue(submitScript.contains("../homebrew-tap/Drafts/flux-markdown-official.rb"))
        XCTAssertFalse(updateScript.contains("../homebrew-tap/Casks/flux-markdown-official.rb"))
        XCTAssertFalse(submitScript.contains("../homebrew-tap/Casks/flux-markdown-official.rb"))
    }

    func testOfficialCaskDraftIsNotStoredInTapCasksDirectory() throws {
        let tapRoot = projectRoot()
            .deletingLastPathComponent()
            .appendingPathComponent("homebrew-tap")
        guard FileManager.default.fileExists(atPath: tapRoot.path) else {
            throw XCTSkip("Adjacent homebrew-tap checkout is not available in this environment.")
        }

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: tapRoot.appendingPathComponent("Casks/flux-markdown-official.rb").path),
            "The official cask draft uses cask \"flux-markdown\", so storing it under Casks/flux-markdown-official.rb breaks tap validation."
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: tapRoot.appendingPathComponent("Drafts/flux-markdown-official.rb").path)
        )
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
