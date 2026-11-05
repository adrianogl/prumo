import Foundation

enum MergeRequestMapper {
    private static let ghost = "ghost"
    private static let mergeableStatus = "MERGEABLE"
    private static let requestedChangesState = "REQUESTED_CHANGES"
    private static let successStatuses: Set<String> = ["SUCCESS", "MANUAL"]
    private static let failedStatuses: Set<String> = ["FAILED", "CANCELED"]
    private static let skippedStatus = "SKIPPED"
    private static let failedJobStatus = "FAILED"
    private static let terminalJobStatuses: Set<String> = ["SUCCESS", "FAILED", "CANCELED", "SKIPPED", "MANUAL"]
    private static let pipelineFallbackName = "pipeline"
    private static let jobFallbackName = "job"
    private static let approvalPrefix = "approval"
    private static let changesPrefix = "changes"

    private typealias Node = GitLabResponse.MergeRequestNode

    static func snapshot(_ data: Data, host: String, capabilities: GitLabCapabilities, now: Date) throws -> Snapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = GitLabDate.decodingStrategy
        let response = try decoder.decode(GitLabResponse.self, from: data)
        guard let user = response.data.currentUser else { throw ProviderError.unauthorized }
        let viewer = user.username
        let context = Context(host: host, viewer: viewer, capabilities: capabilities)
        return Snapshot(
            viewer: viewer,
            mine: user.authored.nodes.compactMap(\.value).compactMap { map($0, context: context, isReview: false) },
            toReview: user.review.nodes.compactMap(\.value)
                .filter { isPendingReview($0, context: context) }
                .compactMap { map($0, context: context, isReview: true) },
            mergedToday: (user.merged?.nodes ?? []).compactMap(\.value).compactMap { mapMerged($0, host: host) },
            fetchedAt: now
        )
    }

    private static func numericID(_ gid: String) -> Int? {
        gid.split(separator: "/").last.flatMap { Int($0) }
    }

    private struct Context {
        let host: String
        let viewer: String
        let capabilities: GitLabCapabilities

        func isViewer(_ username: String?) -> Bool {
            username?.caseInsensitiveCompare(viewer) == .orderedSame
        }
    }

    private static func notes(_ node: Node) -> [GitLabNote] {
        (node.notes?.nodes ?? []).compactMap(\.value)
    }

    private static func requestedAt(_ node: Node, context: Context) -> Date {
        ReviewRequestNote.requestedAt(notes: notes(node), username: context.viewer) ?? node.createdAt
    }

    private static func isPendingReview(_ node: Node, context: Context) -> Bool {
        if context.isViewer(node.author?.username) { return false }
        let reviewState = node.reviewers?.nodes.first { context.isViewer($0.username) }?.mergeRequestInteraction?.reviewState
        let approvedByMe = node.approvedBy?.nodes.contains { context.isViewer($0.username) } ?? false
        let myLastCommentAt = notes(node)
            .filter { !$0.system && context.isViewer($0.author?.username) }
            .map(\.createdAt)
            .max()
        return GitLabReviewRule.isPending(
            reviewState: reviewState, approvedByMe: approvedByMe, myLastCommentAt: myLastCommentAt,
            requestedAt: requestedAt(node, context: context), capabilities: context.capabilities
        )
    }

    private static func map(_ node: Node, context: Context, isReview: Bool) -> PullRequest? {
        guard let iid = Int(node.iid), let projectID = numericID(node.project.id) else { return nil }
        let ci = ciStatus(node.headPipeline)
        let failure = failedRun(node.headPipeline, ci: ci)
        let noteList = notes(node)
        return PullRequest(
            id: GitLabID.make(host: context.host, projectID: projectID, iid: iid),
            number: iid,
            title: node.title,
            url: node.webUrl,
            repository: node.project.fullPath,
            author: node.author?.username ?? ghost,
            isDraft: node.draft,
            createdAt: node.createdAt,
            updatedAt: node.updatedAt,
            headSHA: node.diffHeadSha ?? "",
            ci: ci,
            reviews: reviews(node, notes: noteList, context: context),
            comments: comments(node, notes: noteList),
            commentCount: node.userNotesCount ?? 0,
            additions: node.diffStatsSummary?.additions ?? 0,
            deletions: node.diffStatsSummary?.deletions ?? 0,
            mergeable: node.conflicts == true ? .conflicting : .mergeable,
            reviewRequestedAt: isReview
                ? requestedAt(node, context: context)
                : ReviewRequestNote.requestedAt(notes: noteList, username: context.viewer),
            headRefName: node.sourceBranch ?? "",
            baseRefName: node.targetBranch ?? "",
            isCrossRepository: node.sourceProjectId != node.targetProjectId,
            failedRunID: failure?.pipelineID,
            failedRunName: failure?.jobName,
            reviewTarget: .you,
            reviewDecision: nil,
            provider: .gitlab,
            mergeReady: context.capabilities.hasDetailedMergeStatus ? node.detailedMergeStatus.map { $0 == mergeableStatus } : nil,
            failedJobID: failure?.jobID
        )
    }

    private static func reviews(_ node: Node, notes: [GitLabNote], context: Context) -> [Review] {
        let approvals = (node.approvedBy?.nodes ?? [])
            .filter { !context.isViewer($0.username) }
            .map { approver in
                let noteDate = ReviewRequestNote.approvedAt(notes: notes, username: approver.username)
                return review(prefix: approvalPrefix, author: approver.username, state: .approved, noteDate: noteDate, fallback: node.updatedAt)
            }
        let changes = (node.reviewers?.nodes ?? [])
            .filter { $0.mergeRequestInteraction?.reviewState == requestedChangesState }
            .map { reviewer in
                let noteDate = ReviewRequestNote.changesRequestedAt(notes: notes, username: reviewer.username)
                return review(prefix: changesPrefix, author: reviewer.username, state: .changesRequested, noteDate: noteDate, fallback: node.updatedAt)
            }
        return approvals + changes
    }

    private static func review(prefix: String, author: String, state: ReviewState, noteDate: Date?, fallback: Date) -> Review {
        guard let noteDate else {
            return Review(id: "\(prefix):\(author)", author: author, state: state, submittedAt: fallback)
        }
        let stamp = ISO8601DateFormatter().string(from: noteDate)
        return Review(id: "\(prefix):\(author)@\(stamp)", author: author, state: state, submittedAt: noteDate)
    }

    private static func comments(_ node: Node, notes: [GitLabNote]) -> [Comment] {
        notes
            .filter { !$0.system && $0.author?.bot != true }
            .map {
                Comment(
                    id: $0.id, author: $0.author?.username ?? ghost, authorIsBot: false, body: $0.body,
                    url: $0.url ?? node.webUrl, createdAt: $0.createdAt
                )
            }
    }

    private static func ciStatus(_ pipeline: GitLabResponse.Pipeline?) -> CIStatus {
        guard let pipeline else { return .none }
        let jobs = pipeline.jobs?.nodes ?? []
        let total = pipeline.jobs?.count ?? jobs.count
        if successStatuses.contains(pipeline.status) { return .success(total: total) }
        if failedStatuses.contains(pipeline.status) {
            let names = blockingFailedJobs(jobs).map { $0.name ?? jobFallbackName }
            return .failure(failedChecks: names.isEmpty ? [pipelineFallbackName] : names, total: total)
        }
        if pipeline.status == skippedStatus { return .none }
        return .pending(done: jobs.filter { $0.status.map(terminalJobStatuses.contains) ?? false }.count, total: total)
    }

    private static func blockingFailedJobs(_ jobs: [GitLabResponse.Job]) -> [GitLabResponse.Job] {
        jobs.filter { $0.status == failedJobStatus && $0.allowFailure != true }
    }

    private static func failedRun(
        _ pipeline: GitLabResponse.Pipeline?, ci: CIStatus
    ) -> (pipelineID: Int?, jobName: String?, jobID: Int?)? {
        guard let pipeline, case .failure = ci else { return nil }
        let job = blockingFailedJobs(pipeline.jobs?.nodes ?? []).first
        return (numericID(pipeline.id), job.map { $0.name ?? jobFallbackName }, job.flatMap { numericID($0.id) })
    }

    private static func mapMerged(_ node: GitLabResponse.MergedNode, host: String) -> MergedPullRequest? {
        guard let iid = Int(node.iid), let projectID = numericID(node.project.id), let mergedAt = node.mergedAt else { return nil }
        return MergedPullRequest(
            id: GitLabID.make(host: host, projectID: projectID, iid: iid), number: iid, title: node.title,
            url: node.webUrl, repository: node.project.fullPath, mergedAt: mergedAt, provider: .gitlab
        )
    }
}
