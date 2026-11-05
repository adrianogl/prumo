public struct RepositoryEntry: Equatable, Sendable {
    public let name: String
    public let count: Int
    public let isFavorite: Bool
    public let displayName: String

    public init(name: String, count: Int, isFavorite: Bool, displayName: String? = nil) {
        self.name = name
        self.count = count
        self.isFavorite = isFavorite
        self.displayName = displayName ?? name
    }
}
