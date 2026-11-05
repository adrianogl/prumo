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
        reviewRequestedAt: Date? = nil
    ) -> PullRequest {
        PullRequest(
            id: id, number: number, title: title, url: url, repository: repository, author: author,
            isDraft: isDraft, createdAt: createdAt, updatedAt: updatedAt, headSHA: headSHA, ci: ci,
            reviews: reviews, comments: comments, commentCount: commentCount, additions: additions,
            deletions: deletions, mergeable: mergeable, reviewRequestedAt: reviewRequestedAt
        )
    }
}

extension Snapshot {
    static func fixture(
        viewer: String = "adriano",
        mine: [PullRequest] = [],
        toReview: [PullRequest] = [],
        fetchedAt: Date = .fixed
    ) -> Snapshot {
        Snapshot(viewer: viewer, mine: mine, toReview: toReview, fetchedAt: fetchedAt)
    }
}
