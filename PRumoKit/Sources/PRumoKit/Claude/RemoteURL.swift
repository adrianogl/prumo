import Foundation

public enum RemoteURL {
    public static func repository(from url: String) -> String? {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let path: Substring
        if let range = trimmed.range(of: "git@github.com:") {
            path = trimmed[range.upperBound...]
        } else if let components = URLComponents(string: trimmed),
                  let host = components.host?.lowercased(),
                  host == "github.com" || host == "www.github.com",
                  ["https", "http", "ssh", "git"].contains(components.scheme?.lowercased() ?? "") {
            path = components.path.dropFirst()
        } else {
            return nil
        }
        var value = String(path)
        if value.hasSuffix("/") { value.removeLast() }
        if value.hasSuffix(".git") { value.removeLast(4) }
        let parts = value.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty }) else { return nil }
        return value.lowercased()
    }
}
