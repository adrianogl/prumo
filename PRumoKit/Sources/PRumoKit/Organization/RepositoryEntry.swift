public struct RepositoryEntry: Equatable, Sendable {
    public let name: String
    public let count: Int
    public let isFavorite: Bool

    public init(name: String, count: Int, isFavorite: Bool) {
        self.name = name
        self.count = count
        self.isFavorite = isFavorite
    }
}
