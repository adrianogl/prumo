import Foundation

public enum GlabConfigFile {
    public static func accounts(fromYAML text: String) -> [GlabAccount] {
        var inHosts = false
        var hostIndent: Int?
        var fieldIndent: Int?
        var accounts: [GlabAccount] = []
        var current: (host: String, fields: [String: String])?

        func flush() {
            guard let current else { return }
            accounts.append(GlabAccount(
                host: current.host,
                login: current.fields["user"].flatMap { $0.isEmpty ? nil : $0 },
                isOAuth: current.fields["is_oauth2"] == "true",
                expiresAt: current.fields["oauth2_expiry_date"].flatMap { ISO8601DateFormatter().date(from: $0) }
            ))
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let stripped = rawLine.trimmingCharacters(in: .whitespaces)
            if stripped.isEmpty || stripped.hasPrefix("#") { continue }
            let indent = rawLine.prefix { $0 == " " }.count

            if indent == 0 {
                flush()
                current = nil
                inHosts = stripped == "hosts:"
                hostIndent = nil
                fieldIndent = nil
                continue
            }
            guard inHosts else { continue }

            if hostIndent == nil { hostIndent = indent }
            if indent == hostIndent {
                flush()
                guard stripped.hasSuffix(":") else { current = nil; continue }
                current = (unquote(String(stripped.dropLast())), [:])
                fieldIndent = nil
                continue
            }
            guard current != nil else { continue }
            if fieldIndent == nil { fieldIndent = indent }
            guard indent == fieldIndent, let colon = stripped.firstIndex(of: ":") else { continue }
            let key = String(stripped[..<colon])
            let value = String(stripped[stripped.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            current?.fields[key] = unquote(value)
        }
        flush()
        return accounts
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2,
              let first = value.first, let last = value.last,
              first == last, first == "\"" || first == "'" else { return value }
        return String(value.dropFirst().dropLast())
    }
}
