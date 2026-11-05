import Foundation

public enum JiraKeyDetector {
    private static let token = try! NSRegularExpression(pattern: #"(?<![A-Za-z0-9])([A-Za-z][A-Za-z0-9]*)-(\d+)(?![A-Za-z0-9])"#)

    public static func key(title: String, branch: String, prefixes: Set<String>) -> String? {
        let valid = Set(prefixes.compactMap(normalizedPrefix))
        return firstKey(in: title, prefixes: valid) ?? firstKey(in: branch, prefixes: valid)
    }

    public static func normalizedPrefix(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespaces).uppercased()
        guard value.range(of: #"^[A-Z][A-Z0-9]*$"#, options: .regularExpression) != nil else { return nil }
        return value
    }

    private static func firstKey(in text: String, prefixes: Set<String>) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        for match in token.matches(in: text, range: range) {
            guard let prefixRange = Range(match.range(at: 1), in: text),
                  let numberRange = Range(match.range(at: 2), in: text) else { continue }
            let prefix = text[prefixRange].uppercased()
            if prefixes.contains(prefix) { return "\(prefix)-\(text[numberRange])" }
        }
        return nil
    }
}
