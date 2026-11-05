import Foundation

public struct MergedPullRequest: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let number: Int
    public let title: String
    public let url: URL
    public let repository: String
    public let mergedAt: Date

    public init(id: String, number: Int, title: String, url: URL, repository: String, mergedAt: Date) {
        self.id = id
        self.number = number
        self.title = title
        self.url = url
        self.repository = repository
        self.mergedAt = mergedAt
    }
}
