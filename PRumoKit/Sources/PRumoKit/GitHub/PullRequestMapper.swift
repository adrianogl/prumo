import Foundation

public enum PullRequestMapper {
    private static let failingConclusions: Set<String> = ["FAILURE", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED", "STARTUP_FAILURE"]
    private static let failingStates: Set<String> = ["FAILURE", "ERROR"]
    private static let waitingStates: Set<String> = ["PENDING", "EXPECTED"]
    private static let ghost = "ghost"
    private static let botTypename = "Bot"

    public static func snapshot(mineJSON: Data, reviewJSON: Data, now: Date) throws -> Snapshot {
        let mine = try decode(mineJSON)
        let review = try decode(reviewJSON)
        let viewer = mine.data.viewer.login
        return Snapshot(
            viewer: viewer,
            mine: mine.data.search.pullRequests.map { map($0, viewer: viewer) },
            toReview: review.data.search.pullRequests.map { map($0, viewer: viewer) },
            fetchedAt: now
        )
    }

    private static func decode(_ data: Data) throws -> GraphQLResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GraphQLResponse.self, from: data)
    }

    private static func map(_ node: GraphQLResponse.PullRequestNode, viewer: String) -> PullRequest {
        let commit = node.commits.nodes.first?.commit
        return PullRequest(
            id: node.id,
            number: node.number,
            title: node.title,
            url: node.url,
            repository: node.repository.nameWithOwner,
            author: node.author?.login ?? ghost,
            isDraft: node.isDraft,
            createdAt: node.createdAt,
            updatedAt: node.updatedAt,
            headSHA: commit?.oid ?? "",
            ci: ciStatus(commit?.statusCheckRollup),
            reviews: node.reviews.nodes.compactMap(mapReview),
            comments: node.comments.nodes.map(mapComment),
            commentCount: node.comments.totalCount,
            additions: node.additions,
            deletions: node.deletions,
            mergeable: Mergeable(rawValue: node.mergeable) ?? .unknown,
            reviewRequestedAt: node.timelineItems.nodes
                .filter { $0.typename == "ReviewRequestedEvent" && $0.requestedReviewer?.login == viewer }
                .compactMap(\.createdAt)
                .max(),
            headRefName: node.headRefName ?? "",
            isCrossRepository: node.isCrossRepository ?? false,
            failedRunID: failedRunID(commit?.statusCheckRollup)
        )
    }

    private static func mapReview(_ node: GraphQLResponse.ReviewNode) -> Review? {
        guard let state = ReviewState(rawValue: node.state), let submittedAt = node.submittedAt else { return nil }
        return Review(
            id: node.id,
            author: node.author?.login ?? ghost,
            authorIsBot: node.author?.typename == botTypename,
            state: state,
            submittedAt: submittedAt,
            body: node.body ?? "",
            url: node.url
        )
    }

    private static func mapComment(_ node: GraphQLResponse.CommentNode) -> Comment {
        Comment(
            id: node.id,
            author: node.author?.login ?? ghost,
            authorIsBot: node.author?.typename == botTypename,
            body: node.body,
            url: node.url,
            createdAt: node.createdAt
        )
    }

    private static func ciStatus(_ rollup: GraphQLResponse.Rollup?) -> CIStatus {
        guard let rollup else { return .none }
        let total = rollup.contexts.totalCount
        let contexts = rollup.contexts.nodes

        let done = contexts.filter(isDone).count
        if done < contexts.count {
            return .pending(done: done, total: total)
        }

        let failed = contexts.compactMap(failedName)
        if !failed.isEmpty {
            return .failure(failedChecks: failed, total: total)
        }
        return .success(total: total)
    }

    private static func failedRunID(_ rollup: GraphQLResponse.Rollup?) -> Int? {
        guard let rollup, let failed = rollup.contexts.nodes.first(where: isFailedCheckRun),
              let details = failed.detailsUrl,
              let match = details.firstMatch(of: /\/actions\/runs\/(\d+)\//) else { return nil }
        return Int(match.1)
    }

    private static func isFailedCheckRun(_ context: GraphQLResponse.Context) -> Bool {
        context.typename == "CheckRun" && failedName(context) != nil
    }

    private static func isDone(_ context: GraphQLResponse.Context) -> Bool {
        if context.typename == "CheckRun" { return context.status == "COMPLETED" }
        return !waitingStates.contains(context.state ?? "")
    }

    private static func failedName(_ context: GraphQLResponse.Context) -> String? {
        if context.typename == "CheckRun" {
            guard let conclusion = context.conclusion, failingConclusions.contains(conclusion) else { return nil }
            return context.name
        }
        guard let state = context.state, failingStates.contains(state) else { return nil }
        return context.context
    }
}
