import Foundation

public struct MutedPullRequest: Codable, Equatable, Sendable {
    public var id: String
    public var number: Int
    public var title: String
    public var repository: String
    public var mutedAt: Date

    public init(id: String, number: Int, title: String, repository: String, mutedAt: Date) {
        self.id = id
        self.number = number
        self.title = title
        self.repository = repository
        self.mutedAt = mutedAt
    }
}
