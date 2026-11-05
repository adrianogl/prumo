public struct RowSection: Equatable, Sendable {
    public let repository: String?
    public let items: [PullRequest]

    public init(repository: String?, items: [PullRequest]) {
        self.repository = repository
        self.items = items
    }
}
