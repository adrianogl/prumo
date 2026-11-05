import Foundation

public enum GhHostsFile {
    public static let githubHost = "github.com"

    public static func accounts(fromYAML text: String) -> [GhAccount] {
        var inGithubHost = false
        var hostIndent = 0
        var section: String?
        var usersIndent: Int?
        var logins: [String] = []
        var activeLogin: String?

        for rawLine in text.components(separatedBy: .newlines) {
            let stripped = rawLine.trimmingCharacters(in: .whitespaces)
            if stripped.isEmpty || stripped.hasPrefix("#") { continue }
            let indent = rawLine.prefix { $0 == " " }.count

            if indent == 0 {
                inGithubHost = stripped.hasSuffix(":") && normalizeHost(String(stripped.dropLast())) == githubHost
                hostIndent = 0
                section = nil
                usersIndent = nil
                continue
            }
            guard inGithubHost else { continue }

            if hostIndent == 0 { hostIndent = indent }

            if indent == hostIndent {
                section = nil
                usersIndent = nil
                if stripped == "users:" {
                    section = "users"
                } else if stripped.hasPrefix("user:") {
                    let value = unquote(String(stripped.dropFirst("user:".count)))
                    if !value.isEmpty { activeLogin = value }
                }
            } else if section == "users", indent > hostIndent {
                if usersIndent == nil { usersIndent = indent }
                if indent == usersIndent, let colon = stripped.firstIndex(of: ":") {
                    let login = unquote(String(stripped[..<colon]))
                    if !login.isEmpty { logins.append(login) }
                }
            }
        }

        if logins.isEmpty, let activeLogin {
            logins = [activeLogin]
        }
        return logins.map { GhAccount(host: githubHost, login: $0, isActive: $0 == activeLogin) }
    }

    public static func normalizeHost(_ raw: String) -> String {
        var host = unquote(raw).lowercased()
        if let range = host.range(of: "://") {
            host = String(host[range.upperBound...])
        }
        while host.hasSuffix("/") { host.removeLast() }
        return host
    }

    private static func unquote(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespaces)
        if value.count >= 2,
           let first = value.first, let last = value.last,
           first == last, first == "\"" || first == "'" {
            value = String(value.dropFirst().dropLast())
        }
        return value
    }
}
