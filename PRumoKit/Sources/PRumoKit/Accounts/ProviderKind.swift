import Foundation

public enum ProviderKind: String, Codable, Sendable {
    case github
    case gitlab

    public func owns(pullRequestID id: String) -> Bool {
        (GitLabID.parse(id) != nil) == (self == .gitlab)
    }

    func reference(number: Int) -> String {
        switch self {
        case .github: "#\(number)"
        case .gitlab: "!\(number)"
        }
    }

    var checksPath: String {
        switch self {
        case .github: "checks"
        case .gitlab: "pipelines"
        }
    }

    func repositoryKey(repository: String, url: URL) -> String {
        switch self {
        case .github: repository
        case .gitlab: [url.host?.lowercased(), repository].compactMap { $0 }.joined(separator: "/")
        }
    }
}
