import Foundation

public struct JiraSettings: Codable, Equatable, Sendable {
    public var sites: [JiraSite]

    public init(sites: [JiraSite]) {
        self.sites = sites
    }

    public static let defaults = JiraSettings(sites: [
        JiraSite(prefix: "ON", host: "empresa.atlassian.net"),
        JiraSite(prefix: "DEV", host: "")
    ])

    public func link(for pr: PullRequest) -> JiraLink? {
        let prefixes = Set(sites.compactMap { JiraKeyDetector.normalizedPrefix($0.prefix) })
        guard let key = JiraKeyDetector.key(title: pr.title, branch: pr.headRefName, prefixes: prefixes),
              let keyPrefix = key.split(separator: "-").first.map(String.init) else { return nil }
        let site = sites.first { JiraKeyDetector.normalizedPrefix($0.prefix) == keyPrefix }
        let host = Self.normalizedHost(site?.host ?? "")
        let url = host.isEmpty ? nil : URL(string: "https://\(host)/browse/\(key)")
        return JiraLink(key: key, url: url)
    }

    static func normalizedHost(_ raw: String) -> String {
        var host = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for scheme in ["https://", "http://"] where host.lowercased().hasPrefix(scheme) {
            host = String(host.dropFirst(scheme.count))
        }
        while host.hasSuffix("/") { host.removeLast() }
        return host.trimmingCharacters(in: .whitespaces)
    }
}
