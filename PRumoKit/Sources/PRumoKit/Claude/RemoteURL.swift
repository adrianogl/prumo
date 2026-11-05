import Foundation

public enum RemoteURL {
    public static func repository(from url: String) -> String? {
        repositoryKey(from: url, gitlabHosts: [])
    }

    public static func repositoryKey(from url: String, gitlabHosts: Set<String>) -> String? {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if let github = githubRepository(from: trimmed) { return github }
        return gitlabKey(from: trimmed, hosts: gitlabHosts)
    }

    private static func githubRepository(from trimmed: String) -> String? {
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
        return normalized(path: String(path), minimumParts: 2, maximumParts: 2)
    }

    private static func gitlabKey(from trimmed: String, hosts: Set<String>) -> String? {
        guard !hosts.isEmpty else { return nil }
        let configured = Set(hosts.map { $0.lowercased() })
        let configuredNames = Set(configured.map { String($0.split(separator: ":").first ?? "") })
        let host: String
        let path: String
        if trimmed.contains("://") {
            guard let components = URLComponents(string: trimmed),
                  let name = components.host?.lowercased(),
                  let scheme = components.scheme?.lowercased()
            else { return nil }
            switch scheme {
            case "https", "http":
                let withPort = components.port.map { "\(name):\($0)" } ?? name
                guard configured.contains(withPort) else { return nil }
            case "ssh", "git":
                guard configuredNames.contains(name) else { return nil }
            default:
                return nil
            }
            host = name
            path = String(components.path.dropFirst())
        } else {
            guard let colon = trimmed.firstIndex(of: ":") else { return nil }
            var name = String(trimmed[..<colon]).lowercased()
            if let at = name.lastIndex(of: "@") { name = String(name[name.index(after: at)...]) }
            guard !name.isEmpty, !name.contains("/"), configuredNames.contains(name) else { return nil }
            host = name
            path = String(trimmed[trimmed.index(after: colon)...])
        }
        guard let normalizedPath = normalized(path: path, minimumParts: 2, maximumParts: nil) else { return nil }
        return "\(host)/\(normalizedPath)"
    }

    private static func normalized(path: String, minimumParts: Int, maximumParts: Int?) -> String? {
        var value = path
        if value.hasSuffix("/") { value.removeLast() }
        if value.hasSuffix(".git") { value.removeLast(4) }
        let parts = value.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count >= minimumParts, parts.count <= (maximumParts ?? parts.count),
              parts.allSatisfy({ !$0.isEmpty })
        else { return nil }
        return value.lowercased()
    }
}
