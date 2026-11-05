import Foundation

public enum PullRequestMapper {
    private static let failingConclusions: Set<String> = ["FAILURE", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED", "STARTUP_FAILURE"]
    private static let failingStates: Set<String> = ["FAILURE", "ERROR"]
    private static let waitingStates: Set<String> = ["PENDING", "EXPECTED"]
    private static let ghost = "ghost"
    private static let botTypename = "Bot"
    private static let userTypename = "User"
    private static let teamTypename = "Team"

    public static func snapshot(mineJSON: Data, reviewJSON: Data, mergedJSON: Data?, now: Date) throws -> Snapshot {
        let mine = try decode(mineJSON)
        let review = try decode(reviewJSON)
        let viewer = mine.data.viewer.login
        return Snapshot(
            viewer: viewer,
            mine: mine.data.search.pullRequests.map { map($0, viewer: viewer) },
            toReview: review.data.search.pullRequests.compactMap { node in
                reviewTarget(node, viewer: viewer).map { map(node, viewer: viewer, target: $0) }
            },
            mergedToday: try mergedJSON.map(mapMerged) ?? [],
            fetchedAt: now
        )
    }

    private static func mapMerged(_ data: Data) throws -> [MergedPullRequest] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(MergedSearchResponse.self, from: data).data.search.pullRequests.map {
            MergedPullRequest(
                id: $0.id, number: $0.number, title: $0.title, url: $0.url,
                repository: $0.repository.nameWithOwner, mergedAt: $0.mergedAt
            )
        }
    }

    private static func decode(_ data: Data) throws -> GraphQLResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GraphQLResponse.self, from: data)
    }

    private static func reviewTarget(_ node: GraphQLResponse.PullRequestNode, viewer: String) -> ReviewRequestTarget? {
        let reviewers = (node.reviewRequests?.nodes ?? []).compactMap { $0.value?.requestedReviewer }
        if reviewers.contains(where: { $0.typename == userTypename && $0.login == viewer }) { return .you }
        return reviewers.first(where: { $0.typename == teamTypename }).flatMap(\.name).map { .team(name: $0) }
    }

    private static func requestedAt(_ node: GraphQLResponse.PullRequestNode, viewer: String, target: ReviewRequestTarget) -> Date? {
        node.timelineItems.nodes
            .filter { event in
                guard event.typename == "ReviewRequestedEvent" else { return false }
                switch target {
                case .you: return event.requestedReviewer?.login == viewer
                case .team(let name): return event.requestedReviewer?.name == name
                }
            }
            .compactMap(\.createdAt)
            .max()
    }

    private static func map(
        _ node: GraphQLResponse.PullRequestNode, viewer: String, target: ReviewRequestTarget = .you
    ) -> PullRequest {
        let commit = node.commits.nodes.first?.commit
        let failedRun = failedRun(commit?.statusCheckRollup)
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
            reviewRequestedAt: requestedAt(node, viewer: viewer, target: target),
            headRefName: node.headRefName ?? "",
            baseRefName: node.baseRefName ?? "",
            isCrossRepository: node.isCrossRepository ?? false,
            failedRunID: failedRun?.id,
            failedRunName: failedRun?.name,
            reviewTarget: target,
            reviewDecision: node.reviewDecision.flatMap(ReviewDecision.init(rawValue:))
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

    private static func failedRun(_ rollup: GraphQLResponse.Rollup?) -> (id: Int, name: String)? {
        guard let rollup, let failed = rollup.contexts.nodes.first(where: isFailedCheckRun),
              let name = failed.name,
              let details = failed.detailsUrl,
              let match = details.firstMatch(of: /\/actions\/runs\/(\d+)\//),
              let id = Int(match.1) else { return nil }
        return (id, name)
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
