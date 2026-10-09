import XCTest

final class LocalizationStringsTests: XCTestCase {

    /// The reload and zoom toast keys must exist in every language.
    /// A missing key makes `NSLocalizedString` fall back to the key text.
    func testReloadAndZoomToastKeysExistInEveryLanguage() throws {
        let expectedKeys = ["Document reloaded", "Reload failed", "Zoom reset"]

        for language in try languageDirectories() {
            let keys = try stringKeys(in: language)
            for key in expectedKeys {
                XCTAssertTrue(
                    keys.contains(key),
                    "Missing key \"\(key)\" in \(language.lastPathComponent)"
                )
            }
        }
    }

    /// Every localization file must define the same key set.
    /// This keeps a new English key from silently missing a translation.
    func testAllLanguagesShareTheSameKeySet() throws {
        let directories = try languageDirectories()
        guard let reference = directories.first else {
            XCTFail("No .lproj directory found")
            return
        }

        let referenceKeys = try stringKeys(in: reference)
        for directory in directories.dropFirst() {
            let keys = try stringKeys(in: directory)
            let missing = referenceKeys.subtracting(keys)
            let extra = keys.subtracting(referenceKeys)
            XCTAssertTrue(
                missing.isEmpty,
                "\(directory.lastPathComponent) is missing keys: \(missing.sorted())"
            )
            XCTAssertTrue(
                extra.isEmpty,
                "\(directory.lastPathComponent) has extra keys: \(extra.sorted())"
            )
        }
    }

    private func languageDirectories() throws -> [URL] {
        let root = try projectRoot()
        let base = root.appendingPathComponent("Sources/Markdown")
        let contents = try FileManager.default.contentsOfDirectory(
            at: base,
            includingPropertiesForKeys: nil
        )
        return contents
            .filter { $0.pathExtension == "lproj" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func stringKeys(in languageDirectory: URL) throws -> Set<String> {
        let file = languageDirectory.appendingPathComponent("Localizable.strings")
        let content = try String(contentsOf: file, encoding: .utf8)
        let pattern = try NSRegularExpression(pattern: "^\\s*\"([^\"]*)\"\\s*=")
        var keys = Set<String>()
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let text = String(line)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = pattern.firstMatch(in: text, range: range),
                  let keyRange = Range(match.range(at: 1), in: text) else {
                continue
            }
            keys.insert(String(text[keyRange]))
        }
        return keys
    }

    private func projectRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.path != "/" {
            let candidate = directory.appendingPathComponent("project.yml")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return directory
            }
            directory.deleteLastPathComponent()
        }
        throw NSError(
            domain: "LocalizationStringsTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Could not locate project root from \(#filePath)"]
        )
    }
}
