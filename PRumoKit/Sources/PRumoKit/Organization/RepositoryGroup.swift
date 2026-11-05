public struct RepositoryGroup: Equatable, Sendable {
    public let title: String
    public let entries: [RepositoryEntry]

    public init(title: String, entries: [RepositoryEntry]) {
        self.title = title
        self.entries = entries
    }
}
