import Foundation
@testable import PRumoKit

extension PullRequest {
    static func fixture(
        id: String = "PR_812",
        number: Int = 812,
        title: String = "Corrige cálculo do carrinho",
        url: URL = URL(string: "https://github.com/acme/loja/pull/812")!,
        repository: String = "acme/loja",
        author: String = "adriano",
        isDraft: Bool = false,
        createdAt: Date = .fixed,
        updatedAt: Date = .fixed,
        headSHA: String = "aaa111",
        ci: CIStatus = .none,
        reviews: [Review] = [],
        comments: [Comment] = [],
        commentCount: Int = 0,
        additions: Int = 10,
        deletions: Int = 2,
        mergeable: Mergeable = .mergeable,
        reviewRequestedAt: Date? = nil,
        headRefName: String = "feat/carrinho",
        baseRefName: String = "main",
        isCrossRepository: Bool = false,
        failedRunID: Int? = nil,
        failedRunName: String? = nil,
        reviewTarget: ReviewRequestTarget = .you,
        reviewDecision: ReviewDecision? = nil,
        accountID: String = "",
        provider: ProviderKind = .github,
        mergeReady: Bool? = nil,
        failedJobID: Int? = nil
    ) -> PullRequest {
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
}

extension Snapshot {
    static func fixture(
        viewer: String = "adriano",
        mine: [PullRequest] = [],
        toReview: [PullRequest] = [],
        mergedToday: [MergedPullRequest] = [],
        fetchedAt: Date = .fixed,
        accountViewers: [String: String] = [:]
    ) -> Snapshot {
        Snapshot(
            viewer: viewer, mine: mine, toReview: toReview, mergedToday: mergedToday, fetchedAt: fetchedAt,
            accountViewers: accountViewers
        )
    }
}
