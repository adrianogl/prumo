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

    public init(
        id: String, number: Int, title: String, url: URL, repository: String, author: String,
        isDraft: Bool, createdAt: Date, updatedAt: Date, headSHA: String, ci: CIStatus,
        reviews: [Review], comments: [Comment], commentCount: Int, additions: Int, deletions: Int,
        mergeable: Mergeable, reviewRequestedAt: Date?
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
    }
}
