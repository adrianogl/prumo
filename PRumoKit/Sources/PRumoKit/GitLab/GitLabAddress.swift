import Foundation

public enum GitLabAddress {
    public static let defaultHost = AccountConstants.gitlabHost

    private static let secureScheme = "https://"
    private static let insecureScheme = "http://"
    private static let label = "[a-z0-9]([a-z0-9-]*[a-z0-9])?"
    private static let hostPattern = "^\(label)(\\.\(label))*(:[0-9]{1,5})?$"
    private static let portRange = 1...65535

    public static func normalize(_ raw: String) -> Result<String, GitLabAddressError> {
        var host = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if host.isEmpty { return .success(defaultHost) }
        if host.hasPrefix(insecureScheme) { return .failure(.insecure) }
        if host.hasPrefix(secureScheme) { host.removeFirst(secureScheme.count) }
        while host.hasSuffix("/") { host.removeLast() }
        guard host.range(of: hostPattern, options: .regularExpression) != nil, hasValidPort(host) else {
            return .failure(.invalid)
        }
        return .success(host)
    }

    public static func tokenCreationURL(host: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.percentEncodedHost = host.split(separator: ":").first.map(String.init) ?? defaultHost
        components.port = host.split(separator: ":").dropFirst().first.flatMap { Int($0) }
        components.path = "/-/user_settings/personal_access_tokens"
        components.queryItems = [URLQueryItem(name: "name", value: "PRumo"), URLQueryItem(name: "scopes", value: "read_api")]
        return components.url ?? URL(string: "https://\(defaultHost)")!
    }

    private static func hasValidPort(_ host: String) -> Bool {
        let parts = host.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return true }
        return Int(parts[1]).map(portRange.contains) ?? false
    }
}
