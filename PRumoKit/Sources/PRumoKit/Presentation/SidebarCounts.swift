public struct RepositoryCount: Equatable, Sendable, Identifiable {
    public let key: String
    public let displayName: String
    public let count: Int

    public var id: String { key }

    public init(key: String, displayName: String, count: Int) {
        self.key = key
        self.displayName = displayName
        self.count = count
    }
}

public enum SidebarCounts {
    public static func repositories(_ prs: [PullRequest]) -> [RepositoryCount] {
        var counts: [String: Int] = [:]
        for pr in prs { counts[pr.repositoryKey, default: 0] += 1 }
        return counts
            .map { RepositoryCount(key: $0.key, displayName: RepositoryCatalog.displayName($0.key), count: $0.value) }
            .sorted {
                $0.count != $1.count
                    ? $0.count > $1.count
                    : $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
    }
}
