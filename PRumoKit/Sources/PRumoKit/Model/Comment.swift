import Foundation

public struct Comment: Sendable, Codable, Equatable {
    public let id: String
    public let author: String
    public let authorIsBot: Bool
    public let body: String
    public let url: URL
    public let createdAt: Date

    public init(id: String, author: String, authorIsBot: Bool, body: String, url: URL, createdAt: Date) {
        self.id = id
        self.author = author
        self.authorIsBot = authorIsBot
        self.body = body
        self.url = url
        self.createdAt = createdAt
    }
}
