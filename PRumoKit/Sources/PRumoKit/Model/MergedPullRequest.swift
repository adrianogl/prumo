import Foundation

public struct MergedPullRequest: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let number: Int
    public let title: String
    public let url: URL
    public let repository: String
    public let mergedAt: Date
    public let accountID: String

    public init(
        id: String, number: Int, title: String, url: URL, repository: String, mergedAt: Date, accountID: String = ""
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.url = url
        self.repository = repository
        self.mergedAt = mergedAt
        self.accountID = accountID
    }

    private enum CodingKeys: String, CodingKey {
        case id, number, title, url, repository, mergedAt, accountID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        number = try container.decode(Int.self, forKey: .number)
        title = try container.decode(String.self, forKey: .title)
        url = try container.decode(URL.self, forKey: .url)
        repository = try container.decode(String.self, forKey: .repository)
        mergedAt = try container.decode(Date.self, forKey: .mergedAt)
        accountID = try container.decodeIfPresent(String.self, forKey: .accountID) ?? ""
    }
}
