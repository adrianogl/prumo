import Foundation
import Testing
@testable import PRumoKit

@Suite struct MergeRequestMapperTests {
    private let host = "gitlab.empresa.com"
    private let full = GitLabCapabilities(hasReviewState: true, hasDetailedMergeStatus: true)

    private func snapshot() throws -> Snapshot {
        try MergeRequestMapper.snapshot(fixture("gitlab-snapshot"), host: host, capabilities: full, now: .fixed)
    }

    private func oldSnapshot() throws -> Snapshot {
        try MergeRequestMapper.snapshot(fixture("gitlab-snapshot-old"), host: host, capabilities: .minimal, now: .fixed)
    }

    private func mine(_ iid: Int, in snapshot: Snapshot) throws -> PullRequest {
        try #require(snapshot.mine.first { $0.number == iid })
    }

    private func date(_ raw: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = raw.contains(".") ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return formatter.date(from: raw)!
    }

    @Test func mapsAuthoredToMine() throws {
        let snapshot = try snapshot()
        #expect(snapshot.viewer == "adriano")
        #expect(snapshot.fetchedAt == .fixed)
        #expect(snapshot.mine.map(\.number) == [12, 13, 14, 15, 16, 17])

        let pr = try mine(12, in: snapshot)
        #expect(pr.title == "Corrige cálculo do frete")
        #expect(pr.url.absoluteString == "https://gitlab.empresa.com/vendas/api/-/merge_requests/12")
        #expect(pr.repository == "vendas/api")
        #expect(pr.author == "adriano")
        #expect(pr.isDraft == false)
        #expect(pr.createdAt == date("2026-11-04T10:00:00Z"))
        #expect(pr.updatedAt == date("2026-11-05T12:00:00.123Z"))
        #expect(pr.headSHA == "sha12")
        #expect(pr.headRefName == "feat/mr-12")
        #expect(pr.baseRefName == "main")
        #expect(pr.additions == 42)
        #expect(pr.deletions == 12)
        #expect(pr.provider == .gitlab)
        #expect(pr.reviewTarget == .you)
        #expect(pr.reviewDecision == nil)
        #expect(try mine(14, in: snapshot).isDraft)
    }

    @Test func mapsReviewRequestedToReview() throws {
        let snapshot = try snapshot()
        #expect(snapshot.toReview.map(\.number) == [40, 42])
        let pr = try #require(snapshot.toReview.first)
        #expect(pr.repository == "vendas/web")
        #expect(pr.author == "bruna")
        #expect(pr.reviewTarget == .you)
        #expect(pr.reviewRequestedAt == date("2026-11-05T11:00:00Z"))
        #expect(pr.provider == .gitlab)
    }

    @Test func reviewWithoutReviewStateUsesCommentAfterRequest() throws {
        #expect(try oldSnapshot().toReview.map(\.number) == [40, 42])
    }

    @Test func idIncludesHostAndProject() throws {
        let snapshot = try snapshot()
        #expect(try mine(12, in: snapshot).id == "gitlab:gitlab.empresa.com:77:12")
        #expect(snapshot.toReview.first?.id == "gitlab:gitlab.empresa.com:78:40")
    }

    @Test func pipelineSuccessIsCISuccess() throws {
        let pr = try mine(12, in: snapshot())
        #expect(pr.ci == .success(total: 7))
        #expect(pr.failedRunID == nil)
        #expect(pr.failedRunName == nil)
        #expect(pr.failedJobID == nil)
    }

    @Test func pipelineFailedNamesFirstFailedJob() throws {
        let pr = try mine(13, in: snapshot())
        #expect(pr.ci == .failure(failedChecks: ["testes"], total: 3))
        #expect(pr.failedRunID == 5002)
        #expect(pr.failedRunName == "testes")
        #expect(pr.failedJobID == 9102)
    }

    @Test func allowedFailureJobDoesNotFailCI() throws {
        let pr = try mine(17, in: snapshot())
        #expect(pr.ci == .success(total: 2))
        #expect(pr.failedJobID == nil)
    }

    @Test func pipelineRunningIsPending() throws {
        #expect(try mine(14, in: snapshot()).ci == .pending(done: 3, total: 7))
    }

    @Test func runningPipelineMapsPendingSinceAndRun() throws {
        let pr = try mine(14, in: snapshot())
        #expect(pr.ciPendingSince == date("2026-11-05T10:52:00.000Z"))
        #expect(pr.pendingRuns == [PendingRun(id: 5003, since: date("2026-11-05T10:52:00.000Z"))])
    }

    @Test func pendingPipelineWithoutStartUsesCreatedAt() throws {
        let data = try mutatedFixture(at: 2) { mr in
            var pipeline = mr["headPipeline"] as! [String: Any]
            pipeline["status"] = "PENDING"
            pipeline["startedAt"] = NSNull()
            mr["headPipeline"] = pipeline
        }
        let mapped = try MergeRequestMapper.snapshot(data, host: host, capabilities: full, now: .fixed)
        let pr = try #require(mapped.mine.first { $0.number == 14 })
        #expect(pr.ciPendingSince == date("2026-11-05T10:40:00Z"))
        #expect(pr.pendingRuns == [PendingRun(id: 5003, since: date("2026-11-05T10:40:00Z"))])
    }

    @Test func finishedPipelineHasNoPendingData() throws {
        let pr = try mine(12, in: snapshot())
        #expect(pr.ciPendingSince == nil)
        #expect(pr.pendingRuns == [])
    }

    @Test func oldFixtureWithoutPipelineDatesHasNoPendingSince() throws {
        let pending = try oldSnapshot().mine.filter { if case .pending = $0.ci { true } else { false } }
        #expect(!pending.isEmpty)
        #expect(pending.allSatisfy { $0.ciPendingSince == nil && $0.pendingRuns.isEmpty })
    }

    @Test func canceledPipelineIsFailure() throws {
        let pr = try mine(15, in: snapshot())
        #expect(pr.ci == .failure(failedChecks: ["pipeline"], total: 2))
        #expect(pr.failedRunID == 5004)
        #expect(pr.failedRunName == nil)
        #expect(pr.failedJobID == nil)
    }

    @Test func noPipelineIsNone() throws {
        #expect(try mine(16, in: snapshot()).ci == CIStatus.none)
    }

    @Test func approvedByBecomesApprovedReviewsExceptMe() throws {
        let approvals = try mine(12, in: snapshot()).reviews.filter { $0.state == .approved }
        #expect(approvals.count == 1)
        let approval = try #require(approvals.first)
        #expect(approval.author == "bruna")
        #expect(approval.submittedAt == date("2026-11-05T09:30:00.500Z"))
        #expect(approval.id == "approval:bruna")
    }

    @Test func approvalWithoutNoteUsesUpdatedAt() throws {
        let approval = try #require(try oldSnapshot().mine.first { $0.number == 12 }?.reviews.first { $0.state == .approved })
        #expect(approval.author == "bruna")
        #expect(approval.submittedAt == date("2026-11-05T09:30:00.500Z"))

        let data = try mutatedFixture { mr in
            mr["notes"] = ["nodes": []]
        }
        let mapped = try MergeRequestMapper.snapshot(data, host: host, capabilities: full, now: .fixed)
        let fallback = try #require(mapped.mine.first?.reviews.first { $0.state == .approved })
        #expect(fallback.submittedAt == date("2026-11-05T12:00:00.123Z"))
    }

    @Test func fallbackReviewIDIgnoresUpdatedAt() throws {
        func changes(updatedAt: String) throws -> (PullRequest, Review) {
            let data = try mutatedFixture { mr in
                mr["notes"] = ["nodes": []]
                mr["updatedAt"] = updatedAt
            }
            let pr = try #require(try MergeRequestMapper.snapshot(data, host: host, capabilities: full, now: .fixed).mine.first)
            return (pr, try #require(pr.reviews.first { $0.state == .changesRequested }))
        }
        let (firstPR, first) = try changes(updatedAt: "2026-11-05T12:00:00.123Z")
        let (secondPR, second) = try changes(updatedAt: "2026-11-05T12:30:00.000Z")
        #expect(first.id == "changes:carla")
        #expect(first.id == second.id)
        #expect(second.submittedAt == date("2026-11-05T12:30:00.000Z"))
        let approval = try #require(secondPR.reviews.first { $0.state == .approved })
        #expect(approval.id == "approval:bruna")

        let start = date("2026-11-05T11:00:00Z")
        let old = Snapshot(viewer: "adriano", mine: [firstPR], toReview: [], mergedToday: [], fetchedAt: start)
        let new = Snapshot(viewer: "adriano", mine: [secondPR], toReview: [], mergedToday: [], fetchedAt: start.addingTimeInterval(60))
        let events = TransitionEngine.events(from: old, to: new)
        #expect(!events.contains { $0.kind == .changesRequested || $0.kind == .approved })

        let bare = try mutatedFixture { mr in
            mr["approvedBy"] = ["nodes": []]
            mr["reviewers"] = ["nodes": []]
        }
        let baseline = try MergeRequestMapper.snapshot(bare, host: host, capabilities: full, now: start)
        #expect(baseline.mine.first?.reviews.isEmpty == true)
        #expect(TransitionEngine.events(from: baseline, to: new).contains { $0.kind == .changesRequested })
    }

    @Test func approvalIDIgnoresNoteVisibility() throws {
        let start = date("2026-11-05T11:00:00Z")
        let withNote = try MergeRequestMapper.snapshot(fixture("gitlab-snapshot"), host: host, capabilities: full, now: start)
        let withoutNoteData = try mutatedFixture { mr in
            mr["notes"] = ["nodes": []]
        }
        let withoutNote = try MergeRequestMapper.snapshot(withoutNoteData, host: host, capabilities: full, now: start.addingTimeInterval(60))
        let first = try #require(try mine(12, in: withNote).reviews.first { $0.state == .approved })
        let second = try #require(try mine(12, in: withoutNote).reviews.first { $0.state == .approved })
        #expect(first.id == second.id)
        #expect(first.submittedAt == date("2026-11-05T09:30:00.500Z"))
        #expect(second.submittedAt == date("2026-11-05T12:00:00.123Z"))
        #expect(!TransitionEngine.events(from: withNote, to: withoutNote).contains { $0.kind == .approved })
    }

    @Test(arguments: ["CHECKING", "UNCHECKED", "PREPARING", "APPROVALS_SYNCING"])
    func transientDetailedMergeStatusIsUnknown(status: String) throws {
        let data = try mutatedFixture { mr in
            mr["detailedMergeStatus"] = status
        }
        let pr = try #require(try MergeRequestMapper.snapshot(data, host: host, capabilities: full, now: .fixed).mine.first)
        #expect(pr.mergeReady == nil)
    }

    @Test func jobWithNullNameAndStatusKeepsMergeRequest() throws {
        let data = try mutatedFixture(at: 1) { mr in
            var pipeline = mr["headPipeline"] as! [String: Any]
            var jobs = pipeline["jobs"] as! [String: Any]
            var nodes = jobs["nodes"] as! [[String: Any]]
            nodes[1]["name"] = NSNull()
            nodes[2]["status"] = NSNull()
            jobs["nodes"] = nodes
            pipeline["jobs"] = jobs
            mr["headPipeline"] = pipeline
        }
        let mapped = try MergeRequestMapper.snapshot(data, host: host, capabilities: full, now: .fixed)
        let pr = try #require(mapped.mine.first { $0.number == 13 })
        #expect(pr.ci == .failure(failedChecks: ["job"], total: 3))
        #expect(pr.failedRunName == "job")
        #expect(pr.failedJobID == 9102)
    }

    @Test func jobWithNullStatusIsNotTerminal() throws {
        let data = try mutatedFixture(at: 2) { mr in
            var pipeline = mr["headPipeline"] as! [String: Any]
            var jobs = pipeline["jobs"] as! [String: Any]
            var nodes = jobs["nodes"] as! [[String: Any]]
            nodes[0]["status"] = NSNull()
            nodes[1]["name"] = NSNull()
            jobs["nodes"] = nodes
            pipeline["jobs"] = jobs
            mr["headPipeline"] = pipeline
        }
        let mapped = try MergeRequestMapper.snapshot(data, host: host, capabilities: full, now: .fixed)
        let pr = try #require(mapped.mine.first { $0.number == 14 })
        #expect(pr.ci == .pending(done: 2, total: 7))
    }

    @Test func requestedChangesFromReviewerState() throws {
        let changes = try mine(12, in: snapshot()).reviews.filter { $0.state == .changesRequested }
        #expect(changes.map(\.author) == ["carla"])
        #expect(changes.first?.submittedAt == date("2026-11-05T12:00:00.123Z"))
    }

    @Test func noRequestedChangesWithoutReviewState() throws {
        let reviews = try oldSnapshot().mine.flatMap(\.reviews)
        #expect(!reviews.contains { $0.state == .changesRequested })
    }

    @Test func commentsExcludeSystemAndBots() throws {
        let pr = try mine(12, in: snapshot())
        #expect(pr.comments.map(\.author) == ["carla"])
        let comment = try #require(pr.comments.first)
        #expect(comment.id == "gid://gitlab/Note/3")
        #expect(comment.body == "Faltou tratar o CEP vazio")
        #expect(comment.url.absoluteString == "https://gitlab.empresa.com/vendas/api/-/merge_requests/12#note_3")
        #expect(comment.createdAt == date("2026-11-05T09:40:00Z"))
        #expect(comment.authorIsBot == false)
        #expect(pr.commentCount == 2)
    }

    @Test func conflictsAndDetailedMergeStatus() throws {
        let snapshot = try snapshot()
        let ready = try mine(12, in: snapshot)
        #expect(ready.mergeable == .mergeable)
        #expect(ready.mergeReady == true)
        let blocked = try mine(13, in: snapshot)
        #expect(blocked.mergeable == .conflicting)
        #expect(blocked.mergeReady == false)
        let old = try #require(try oldSnapshot().mine.first { $0.number == 12 })
        #expect(old.mergeReady == nil)
        #expect(old.mergeable == .mergeable)
    }

    @Test func crossProjectIsCrossRepository() throws {
        let snapshot = try snapshot()
        #expect(try mine(13, in: snapshot).isCrossRepository)
        #expect(try !mine(12, in: snapshot).isCrossRepository)
    }

    @Test func requestedAtFallsBackToCreatedAt() throws {
        let pr = try #require(try snapshot().toReview.first { $0.number == 42 })
        #expect(pr.reviewRequestedAt == date("2026-11-03T15:00:00Z"))
    }

    @Test func mergedTodayMapped() throws {
        let merged = try snapshot().mergedToday
        #expect(merged.count == 1)
        let pr = try #require(merged.first)
        #expect(pr.id == "gitlab:gitlab.empresa.com:77:9")
        #expect(pr.number == 9)
        #expect(pr.title == "Corrige arredondamento")
        #expect(pr.repository == "vendas/api")
        #expect(pr.mergedAt == date("2026-11-05T10:15:00Z"))
        #expect(pr.provider == .gitlab)
    }

    @Test func badNodeIsSkipped() throws {
        let data = try mutatedFixture { mr in
            mr["iid"] = "x"
        }
        let mapped = try MergeRequestMapper.snapshot(data, host: host, capabilities: full, now: .fixed)
        #expect(mapped.mine.map(\.number) == [13, 14, 15, 16, 17])
    }

    private func mutatedFixture(at index: Int = 0, _ change: (inout [String: Any]) -> Void) throws -> Data {
        var root = try #require(try JSONSerialization.jsonObject(with: fixture("gitlab-snapshot")) as? [String: Any])
        var data = try #require(root["data"] as? [String: Any])
        var user = try #require(data["currentUser"] as? [String: Any])
        var authored = try #require(user["authored"] as? [String: Any])
        var nodes = try #require(authored["nodes"] as? [[String: Any]])
        change(&nodes[index])
        authored["nodes"] = nodes
        user["authored"] = authored
        data["currentUser"] = user
        root["data"] = data
        return try JSONSerialization.data(withJSONObject: root)
    }
}
