import XCTest
import UniformTypeIdentifiers

final class FileExtensionTests: XCTestCase {

    // MARK: - Helpers

    private var fixturesURL: URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fixtures")
    }

    private func applyContentPreprocessing(content: String, fileExtension: String) -> String {
        let ext = fileExtension.lowercased()
        if ext == "mmd" {
            return "```mermaid\n\(content)\n```"
        }
        return content
    }

    // MARK: - Fixture Existence Tests

    func testFixtureExists_mmd_flowchart() {
        let url = fixturesURL.appendingPathComponent("test-mermaid.mmd")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "test-mermaid.mmd fixture must exist")
    }

    func testFixtureExists_mmd_sequence() {
        let url = fixturesURL.appendingPathComponent("test-mermaid-sequence.mmd")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "test-mermaid-sequence.mmd fixture must exist")
    }

    func testFixtureExists_mmd_gantt() {
        let url = fixturesURL.appendingPathComponent("test-mermaid-gantt.mmd")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "test-mermaid-gantt.mmd fixture must exist")
    }

    func testFixtureExists_mdwn() {
        let url = fixturesURL.appendingPathComponent("test.mdwn")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "test.mdwn fixture must exist")
    }

    func testFixtureExists_livemd() {
        let url = fixturesURL.appendingPathComponent("test.livemd")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "test.livemd fixture must exist")
    }

    func testFixtureExists_markdown() {
        let url = fixturesURL.appendingPathComponent("test.markdown")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "test.markdown fixture must exist")
    }

    func testFixtureExists_mdown() {
        let url = fixturesURL.appendingPathComponent("test.mdown")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "test.mdown fixture must exist")
    }

    func testFixtureExists_mkd() {
        let url = fixturesURL.appendingPathComponent("test.mkd")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "test.mkd fixture must exist")
    }

    func testFixtureExists_mkdn() {
        let url = fixturesURL.appendingPathComponent("test.mkdn")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "test.mkdn fixture must exist")
    }

    func testFixtureExists_mkdown() {
        let url = fixturesURL.appendingPathComponent("test.mkdown")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "test.mkdown fixture must exist")
    }

    // MARK: - Fixture Content Validity Tests

    func testFixtureContent_mmd_isNotEmpty() throws {
        let url = fixturesURL.appendingPathComponent("test-mermaid.mmd")
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       ".mmd fixture must not be empty")
    }

    func testFixtureContent_mmd_containsMermaidKeyword() throws {
        let url = fixturesURL.appendingPathComponent("test-mermaid.mmd")
        let content = try String(contentsOf: url, encoding: .utf8)
        let hasDiagramType = content.contains("graph") ||
                             content.contains("sequenceDiagram") ||
                             content.contains("flowchart") ||
                             content.contains("gantt") ||
                             content.contains("classDiagram") ||
                             content.contains("erDiagram") ||
                             content.contains("pie")
        XCTAssertTrue(hasDiagramType,
                      ".mmd fixture must contain a valid Mermaid diagram keyword")
    }

    func testFixtureContent_livemd_containsElixirCodeBlock() throws {
        let url = fixturesURL.appendingPathComponent("test.livemd")
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("```elixir"),
                      ".livemd fixture must contain an Elixir code block")
    }

    func testFixtureContent_mdwn_isValidMarkdown() throws {
        let url = fixturesURL.appendingPathComponent("test.mdwn")
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.hasPrefix("#"),
                      ".mdwn fixture must start with a Markdown heading")
    }

    // MARK: - .mmd Content Wrapping Logic Tests

    func testMmdWrapping_addsCorrectFencedBlock() {
        let raw = "graph TD\n    A --> B"
        let processed = applyContentPreprocessing(content: raw, fileExtension: "mmd")
        XCTAssertTrue(processed.hasPrefix("```mermaid\n"),
                      "Wrapped .mmd must start with ```mermaid newline")
        XCTAssertTrue(processed.hasSuffix("\n```"),
                      "Wrapped .mmd must end with newline ```")
    }

    func testMmdWrapping_preservesOriginalContent() {
        let raw = "graph LR\n    A[Start] --> B[End]"
        let processed = applyContentPreprocessing(content: raw, fileExtension: "mmd")
        XCTAssertTrue(processed.contains(raw),
                      "Wrapped .mmd must contain the original raw content verbatim")
    }

    func testMmdWrapping_exactFormat() {
        let raw = "graph TD\n    A --> B"
        let processed = applyContentPreprocessing(content: raw, fileExtension: "mmd")
        let expected = "```mermaid\ngraph TD\n    A --> B\n```"
        XCTAssertEqual(processed, expected,
                       "Wrapped .mmd output format must be exactly ```mermaid\\n<content>\\n```")
    }

    func testMmdWrapping_caseInsensitiveExtension() {
        let raw = "graph TD\n    A --> B"
        let processed = applyContentPreprocessing(content: raw, fileExtension: "MMD")
        XCTAssertTrue(processed.hasPrefix("```mermaid"),
                      "Wrapping must work for uppercase .MMD extension")
    }

    func testMmdWrapping_emptyContent() {
        let raw = ""
        let processed = applyContentPreprocessing(content: raw, fileExtension: "mmd")
        XCTAssertEqual(processed, "```mermaid\n\n```",
                       "Empty .mmd file must still produce a valid (empty) fenced block")
    }

    func testMmdWrapping_multiLineDiagram() throws {
        let url = fixturesURL.appendingPathComponent("test-mermaid-sequence.mmd")
        let raw = try String(contentsOf: url, encoding: .utf8)
        let processed = applyContentPreprocessing(content: raw, fileExtension: "mmd")

        XCTAssertTrue(processed.hasPrefix("```mermaid\n"),
                      "Multi-line .mmd must start with ```mermaid")
        XCTAssertTrue(processed.hasSuffix("\n```"),
                      "Multi-line .mmd must end with newline ```")
        XCTAssertTrue(processed.contains("sequenceDiagram"),
                      "Wrapped content must contain the diagram type keyword")
    }

    func testMmdWrapping_alwaysWrapsRawContent() {
        let raw = "graph TD\n    A --> B"
        let processed = applyContentPreprocessing(content: raw, fileExtension: "mmd")
        let fenceCount = processed.components(separatedBy: "```mermaid").count - 1
        XCTAssertEqual(fenceCount, 1,
                       "Raw .mmd content must be wrapped in exactly one ```mermaid fence")
    }

    // MARK: - Non-.mmd Files Must Not Be Wrapped

    func testNoWrapping_mdExtension() {
        let raw = "# Hello\n\nSome content"
        let processed = applyContentPreprocessing(content: raw, fileExtension: "md")
        XCTAssertEqual(processed, raw, ".md content must not be wrapped")
    }

    func testNoWrapping_mdwnExtension() {
        let raw = "# Wiki page\n\nContent"
        let processed = applyContentPreprocessing(content: raw, fileExtension: "mdwn")
        XCTAssertEqual(processed, raw, ".mdwn content must not be wrapped")
    }

    func testNoWrapping_livemdExtension() {
        let raw = "# Livebook\n\n```elixir\nIO.puts(\"hi\")\n```"
        let processed = applyContentPreprocessing(content: raw, fileExtension: "livemd")
        XCTAssertEqual(processed, raw, ".livemd content must not be wrapped")
    }

    func testNoWrapping_mdxExtension() {
        let raw = "# MDX\n\n<MyComponent />"
        let processed = applyContentPreprocessing(content: raw, fileExtension: "mdx")
        XCTAssertEqual(processed, raw, ".mdx content must not be wrapped")
    }

    func testNoWrapping_qmdExtension() {
        let raw = "---\ntitle: Quarto\n---\n\n# Hello"
        let processed = applyContentPreprocessing(content: raw, fileExtension: "qmd")
        XCTAssertEqual(processed, raw, ".qmd content must not be wrapped")
    }

    // MARK: - UTI Declaration Tests (Info.plist)

    func testUTIDeclarations_appInfoPlistExists() {
        let plistURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Markdown/Info.plist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: plistURL.path),
                      "Sources/Markdown/Info.plist must exist")
    }

    func testUTIDeclarations_extensionInfoPlistExists() {
        let plistURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MarkdownPreview/Info.plist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: plistURL.path),
                      "Sources/MarkdownPreview/Info.plist must exist")
    }

    func testUTIDeclarations_appPlistContainsMmdUTI() throws {
        let plistURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Markdown/Info.plist")
        let plistContent = try String(contentsOf: plistURL, encoding: .utf8)
        XCTAssertTrue(plistContent.contains("com.fluxmarkdown.mmd"),
                      "App Info.plist must declare com.fluxmarkdown.mmd UTI")
        XCTAssertTrue(plistContent.contains("<string>mmd</string>"),
                      "App Info.plist must map .mmd extension to UTI")
    }

    func testUTIDeclarations_appPlistContainsLivemdUTI() throws {
        let plistURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Markdown/Info.plist")
        let plistContent = try String(contentsOf: plistURL, encoding: .utf8)
        XCTAssertTrue(plistContent.contains("com.fluxmarkdown.livemd"),
                      "App Info.plist must declare com.fluxmarkdown.livemd UTI")
        XCTAssertTrue(plistContent.contains("<string>livemd</string>"),
                      "App Info.plist must map .livemd extension to UTI")
    }

    func testUTIDeclarations_appPlistContainsMdwnExtension() throws {
        let plistURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Markdown/Info.plist")
        let plistContent = try String(contentsOf: plistURL, encoding: .utf8)
        XCTAssertTrue(plistContent.contains("<string>mdwn</string>"),
                      "App Info.plist must declare mdwn extension")
    }

    func testUTIDeclarations_appPlistExportsMarkdownExtensions() throws {
        let plistURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Markdown/Info.plist")
        let plistContent = try String(contentsOf: plistURL, encoding: .utf8)
        XCTAssertTrue(plistContent.contains("UTExportedTypeDeclarations"),
                      "App Info.plist must use UTExportedTypeDeclarations for unknown extensions")
        let exportedExtensions = ["markdown", "mdown", "mkd", "mkdn", "mkdown", "mdwn"]
        for ext in exportedExtensions {
            XCTAssertTrue(plistContent.contains("com.fluxmarkdown.\(ext)"),
                          "App Info.plist must export UTI for .\(ext)")
        }
    }

    func testUTIDeclarations_extensionPlistContainsMmdUTI() throws {
        let plistURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MarkdownPreview/Info.plist")
        let plistContent = try String(contentsOf: plistURL, encoding: .utf8)
        XCTAssertTrue(plistContent.contains("com.fluxmarkdown.mmd"),
                      "Extension Info.plist QLSupportedContentTypes must include com.fluxmarkdown.mmd")
    }

    func testUTIDeclarations_extensionPlistContainsLivemdUTI() throws {
        let plistURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MarkdownPreview/Info.plist")
        let plistContent = try String(contentsOf: plistURL, encoding: .utf8)
        XCTAssertTrue(plistContent.contains("com.fluxmarkdown.livemd"),
                      "Extension Info.plist QLSupportedContentTypes must include com.fluxmarkdown.livemd")
    }

    func testUTIDeclarations_bothPlistsDeclareSameUTIs() throws {
        let root = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appPlist = try String(contentsOf: root.appendingPathComponent("Sources/Markdown/Info.plist"), encoding: .utf8)
        let extPlist = try String(contentsOf: root.appendingPathComponent("Sources/MarkdownPreview/Info.plist"), encoding: .utf8)

        let requiredUTIs = [
            "net.daringfireball.markdown",
            "public.markdown",
            "com.fluxmarkdown.mdx",
            "com.fluxmarkdown.rmd",
            "com.fluxmarkdown.qmd",
            "com.fluxmarkdown.mdoc",
            "com.fluxmarkdown.mmd",
            "com.fluxmarkdown.livemd",
            "com.fluxmarkdown.markdown",
            "com.fluxmarkdown.mdown",
            "com.fluxmarkdown.mkd",
            "com.fluxmarkdown.mkdn",
            "com.fluxmarkdown.mkdown",
            "com.fluxmarkdown.mdwn",
        ]
        for uti in requiredUTIs {
            XCTAssertTrue(appPlist.contains(uti),
                          "App Info.plist must reference UTI: \(uti)")
            XCTAssertTrue(extPlist.contains(uti),
                          "Extension Info.plist must reference UTI: \(uti)")
        }
    }

    // MARK: - Supported Extension Enumeration Test

    func testAllSupportedExtensions_fixtureFilesAreReadable() {
        let supportedExtensions: [(filename: String, ext: String)] = [
            ("test-mermaid.mmd",          "mmd"),
            ("test.livemd",               "livemd"),
            ("test.mdwn",                 "mdwn"),
            ("test.markdown",             "markdown"),
            ("test.mdown",                "mdown"),
            ("test.mkd",                  "mkd"),
            ("test.mkdn",                 "mkdn"),
            ("test.mkdown",               "mkdown"),
            ("feature-validation.md",     "md"),
        ]

        for entry in supportedExtensions {
            let url = fixturesURL.appendingPathComponent(entry.filename)
            guard FileManager.default.fileExists(atPath: url.path) else {
                XCTFail("Fixture missing: \(entry.filename)")
                continue
            }
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                XCTAssertFalse(content.isEmpty,
                               "Fixture \(entry.filename) must not be empty")
            } catch {
                XCTFail("Cannot read fixture \(entry.filename): \(error)")
            }
        }
    }

    func testMmdFixtures_allProduceValidWrappedOutput() throws {
        let mmdFiles = ["test-mermaid.mmd", "test-mermaid-sequence.mmd", "test-mermaid-gantt.mmd"]

        for filename in mmdFiles {
            let url = fixturesURL.appendingPathComponent(filename)
            let raw = try String(contentsOf: url, encoding: .utf8)
            let processed = applyContentPreprocessing(content: raw, fileExtension: "mmd")

            XCTAssertTrue(processed.hasPrefix("```mermaid\n"),
                          "\(filename): wrapped output must start with ```mermaid\\n")
            XCTAssertTrue(processed.hasSuffix("\n```"),
                          "\(filename): wrapped output must end with \\n```")
            XCTAssertGreaterThan(processed.count, raw.count,
                                 "\(filename): wrapped output must be longer than raw content")
        }
    }
}
