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
    public let reviewTarget: ReviewRequestTarget
    public let reviewDecision: ReviewDecision?
    public let accountID: String
    public let provider: ProviderKind
    public let mergeReady: Bool?
    public let failedJobID: Int?

    public init(
        id: String, number: Int, title: String, url: URL, repository: String, author: String,
        isDraft: Bool, createdAt: Date, updatedAt: Date, headSHA: String, ci: CIStatus,
        reviews: [Review], comments: [Comment], commentCount: Int, additions: Int, deletions: Int,
        mergeable: Mergeable, reviewRequestedAt: Date?,
        headRefName: String = "", baseRefName: String = "", isCrossRepository: Bool = false, failedRunID: Int? = nil,
        failedRunName: String? = nil, reviewTarget: ReviewRequestTarget = .you, reviewDecision: ReviewDecision? = nil,
        accountID: String = "", provider: ProviderKind = .github, mergeReady: Bool? = nil, failedJobID: Int? = nil
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
        self.reviewTarget = reviewTarget
        self.reviewDecision = reviewDecision
        self.accountID = accountID
        self.provider = provider
        self.mergeReady = mergeReady
        self.failedJobID = failedJobID
    }

    public func with(mergeable: Mergeable) -> PullRequest {
        PullRequest(
            id: id, number: number, title: title, url: url, repository: repository, author: author,
            isDraft: isDraft, createdAt: createdAt, updatedAt: updatedAt, headSHA: headSHA, ci: ci,
            reviews: reviews, comments: comments, commentCount: commentCount, additions: additions,
            deletions: deletions, mergeable: mergeable, reviewRequestedAt: reviewRequestedAt,
            headRefName: headRefName, baseRefName: baseRefName, isCrossRepository: isCrossRepository,
            failedRunID: failedRunID, failedRunName: failedRunName,
            reviewTarget: reviewTarget, reviewDecision: reviewDecision, accountID: accountID,
            provider: provider, mergeReady: mergeReady, failedJobID: failedJobID
        )
    }

    public func with(accountID: String) -> PullRequest {
        PullRequest(
            id: id, number: number, title: title, url: url, repository: repository, author: author,
            isDraft: isDraft, createdAt: createdAt, updatedAt: updatedAt, headSHA: headSHA, ci: ci,
            reviews: reviews, comments: comments, commentCount: commentCount, additions: additions,
            deletions: deletions, mergeable: mergeable, reviewRequestedAt: reviewRequestedAt,
            headRefName: headRefName, baseRefName: baseRefName, isCrossRepository: isCrossRepository,
            failedRunID: failedRunID, failedRunName: failedRunName,
            reviewTarget: reviewTarget, reviewDecision: reviewDecision, accountID: accountID,
            provider: provider, mergeReady: mergeReady, failedJobID: failedJobID
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, number, title, url, repository, author, isDraft, createdAt, updatedAt, headSHA, ci
        case reviews, comments, commentCount, additions, deletions, mergeable, reviewRequestedAt
        case headRefName, baseRefName, isCrossRepository, failedRunID, failedRunName
        case reviewTarget, reviewDecision, accountID, provider, mergeReady, failedJobID
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
        reviewTarget = try container.decodeIfPresent(ReviewRequestTarget.self, forKey: .reviewTarget) ?? .you
        reviewDecision = try container.decodeIfPresent(ReviewDecision.self, forKey: .reviewDecision)
        accountID = try container.decodeIfPresent(String.self, forKey: .accountID) ?? ""
        provider = container.decodeLossy(ProviderKind.self, forKey: .provider, default: .github)
        mergeReady = container.decodeLossy(Bool?.self, forKey: .mergeReady, default: nil)
        failedJobID = container.decodeLossy(Int?.self, forKey: .failedJobID, default: nil)
    }

    public var reference: String {
        provider.reference(number: number)
    }

    public var checksURL: URL {
        url.appendingPathComponent(provider.checksPath)
    }

    public var repositoryKey: String {
        provider.repositoryKey(repository: repository, url: url)
    }
}
