import Foundation

public struct WorktreeRecord: Codable, Equatable, Sendable {
    public let pullRequestID: String
    public let number: Int
    public let path: String
    public let clone: String
    public let accountID: String?

    public init(pullRequestID: String, number: Int, path: String, clone: String, accountID: String? = nil) {
        self.pullRequestID = pullRequestID
        self.number = number
        self.path = path
        self.clone = clone
        self.accountID = accountID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pullRequestID = try container.decode(String.self, forKey: .pullRequestID)
        number = try container.decodeIfPresent(Int.self, forKey: .number) ?? 0
        path = try container.decode(String.self, forKey: .path)
        clone = try container.decode(String.self, forKey: .clone)
        accountID = try container.decodeIfPresent(String.self, forKey: .accountID)
    }

    public static func registrable(
        pr: PullRequest, directory: URL, clone: URL, worktreesRoot: URL
    ) -> WorktreeRecord? {
        let rootPath = worktreesRoot.standardizedFileURL.path
        let path = directory.standardizedFileURL.path
        guard path.hasPrefix(rootPath + "/") else { return nil }
        return WorktreeRecord(
            pullRequestID: pr.id, number: pr.number, path: path, clone: clone.standardizedFileURL.path,
            accountID: pr.accountID.isEmpty ? nil : pr.accountID
        )
    }
}
