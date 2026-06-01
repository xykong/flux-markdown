import Foundation

enum DisplayVersion {
    private static let displayVersionKey = "FMDisplayVersion"
    private static let bundleVersionKey = "CFBundleShortVersionString"

    static func text(from infoDictionary: [String: Any]?) -> String? {
        guard let infoDictionary else { return nil }

        if let override = trimmedString(for: displayVersionKey, in: infoDictionary) {
            return override
        }

        return trimmedString(for: bundleVersionKey, in: infoDictionary)
    }

    static func text(in bundle: Bundle) -> String? {
        text(from: bundle.infoDictionary)
    }

    private static func trimmedString(for key: String, in infoDictionary: [String: Any]) -> String? {
        guard let value = infoDictionary[key] as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
