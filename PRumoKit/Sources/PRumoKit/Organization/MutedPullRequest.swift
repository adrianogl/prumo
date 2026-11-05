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

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        number = c.decodeLossy(Int.self, forKey: .number, default: 0)
        title = c.decodeLossy(String.self, forKey: .title, default: "")
        repository = c.decodeLossy(String.self, forKey: .repository, default: "")
        mutedAt = c.decodeLossy(Date.self, forKey: .mutedAt, default: Date(timeIntervalSince1970: 0))
    }
}
