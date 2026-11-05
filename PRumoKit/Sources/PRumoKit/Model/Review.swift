import Foundation

public enum ReviewState: String, Sendable, Codable, Equatable {
    case approved = "APPROVED"
    case changesRequested = "CHANGES_REQUESTED"
    case commented = "COMMENTED"
    case dismissed = "DISMISSED"
    case pending = "PENDING"
}

public struct Review: Sendable, Codable, Equatable {
    public let id: String
    public let author: String
    public let authorIsBot: Bool
    public let state: ReviewState
    public let submittedAt: Date
    public let body: String
    public let url: URL?

    public init(
        id: String, author: String, authorIsBot: Bool = false, state: ReviewState, submittedAt: Date,
        body: String = "", url: URL? = nil
    ) {
        self.id = id
        self.author = author
        self.authorIsBot = authorIsBot
        self.state = state
        self.submittedAt = submittedAt
        self.body = body
        self.url = url
    }

    public var isComment: Bool {
        state == .commented && !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case id, author, authorIsBot, state, submittedAt, body, url
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        author = try container.decode(String.self, forKey: .author)
        authorIsBot = try container.decodeIfPresent(Bool.self, forKey: .authorIsBot) ?? false
        state = try container.decode(ReviewState.self, forKey: .state)
        submittedAt = try container.decode(Date.self, forKey: .submittedAt)
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        url = try container.decodeIfPresent(URL.self, forKey: .url)
    }
}
