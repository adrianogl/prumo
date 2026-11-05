import Foundation

enum GitLabReviewRule {
    private static let unreviewedState = "UNREVIEWED"

    static func isPending(reviewState: String?, approvedByMe: Bool, myLastCommentAt: Date?, requestedAt: Date,
                          capabilities: GitLabCapabilities) -> Bool {
        if approvedByMe { return false }
        if capabilities.hasReviewState { return reviewState == unreviewedState }
        let commentedAfterRequest = myLastCommentAt.map { $0 > requestedAt } ?? false
        return !commentedAfterRequest
    }
}
