public struct RepositoryGroup: Equatable, Sendable {
    public let title: String
    public let entries: [RepositoryEntry]
    public let section: String?

    public init(title: String, entries: [RepositoryEntry], section: String? = nil) {
        self.title = title
        self.entries = entries
        self.section = section
    }
}
