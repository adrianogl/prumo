import Foundation

public enum Mergeable: String, Sendable, Codable, Equatable {
    case mergeable = "MERGEABLE"
    case conflicting = "CONFLICTING"
    case unknown = "UNKNOWN"
}

public struct PullRequest: Identifiable, Sendable, Codable, Equatable {
    public let id: String
    public let number: Int
    public let title: String
    public let url: URL
    public let repository: String
    public let author: String
    public let isDraft: Bool
    public let createdAt: Date
    public let updatedAt: Date
    public let headSHA: String
    public let ci: CIStatus
    public let reviews: [Review]
    public let comments: [Comment]
    public let commentCount: Int
    public let additions: Int
    public let deletions: Int
    public let mergeable: Mergeable
    public let reviewRequestedAt: Date?
    public let headRefName: String
    public let baseRefName: String
    public let isCrossRepository: Bool
    public let failedRunID: Int?
    public let failedRunName: String?

    public init(
        id: String, number: Int, title: String, url: URL, repository: String, author: String,
        isDraft: Bool, createdAt: Date, updatedAt: Date, headSHA: String, ci: CIStatus,
        reviews: [Review], comments: [Comment], commentCount: Int, additions: Int, deletions: Int,
        mergeable: Mergeable, reviewRequestedAt: Date?,
        headRefName: String = "", baseRefName: String = "", isCrossRepository: Bool = false, failedRunID: Int? = nil,
        failedRunName: String? = nil
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.url = url
        self.repository = repository
        self.author = author
        self.isDraft = isDraft
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.headSHA = headSHA
        self.ci = ci
        self.reviews = reviews
        self.comments = comments
        self.commentCount = commentCount
        self.additions = additions
        self.deletions = deletions
        self.mergeable = mergeable
        self.reviewRequestedAt = reviewRequestedAt
        self.headRefName = headRefName
        self.baseRefName = baseRefName
        self.isCrossRepository = isCrossRepository
        self.failedRunID = failedRunID
        self.failedRunName = failedRunName
    }

    enum CodingKeys: String, CodingKey {
        case id, number, title, url, repository, author, isDraft, createdAt, updatedAt, headSHA, ci
        case reviews, comments, commentCount, additions, deletions, mergeable, reviewRequestedAt
        case headRefName, baseRefName, isCrossRepository, failedRunID, failedRunName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        number = try container.decode(Int.self, forKey: .number)
        title = try container.decode(String.self, forKey: .title)
        url = try container.decode(URL.self, forKey: .url)
        repository = try container.decode(String.self, forKey: .repository)
        author = try container.decode(String.self, forKey: .author)
        isDraft = try container.decode(Bool.self, forKey: .isDraft)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        headSHA = try container.decode(String.self, forKey: .headSHA)
        ci = try container.decode(CIStatus.self, forKey: .ci)
        reviews = try container.decode([Review].self, forKey: .reviews)
        comments = try container.decode([Comment].self, forKey: .comments)
        commentCount = try container.decode(Int.self, forKey: .commentCount)
        additions = try container.decode(Int.self, forKey: .additions)
        deletions = try container.decode(Int.self, forKey: .deletions)
        mergeable = try container.decode(Mergeable.self, forKey: .mergeable)
        reviewRequestedAt = try container.decodeIfPresent(Date.self, forKey: .reviewRequestedAt)
        headRefName = try container.decodeIfPresent(String.self, forKey: .headRefName) ?? ""
        baseRefName = try container.decodeIfPresent(String.self, forKey: .baseRefName) ?? ""
        isCrossRepository = try container.decodeIfPresent(Bool.self, forKey: .isCrossRepository) ?? false
        failedRunID = try container.decodeIfPresent(Int.self, forKey: .failedRunID)
        failedRunName = try container.decodeIfPresent(String.self, forKey: .failedRunName)
    }
}
